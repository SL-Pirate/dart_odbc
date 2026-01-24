part of '../base.dart';

extension on DartOdbcBlockingClient {
  Future<List<Map<String, dynamic>>> _execute(
    String query, {
    List<dynamic>? params,
  }) async {
    if (_hEnv == nullptr || _hConn == nullptr) {
      throw ODBCException('Not connected to the database');
    }

    final hStmt = _execStatement(query, params);

    return _getResultBulk(hStmt);
  }

  Future<OdbcCursor> _executeCursor(
    String query, {
    List<dynamic>? params,
  }) async {
    if (_hEnv == nullptr || _hConn == nullptr) {
      throw ODBCException('Not connected to the database');
    }

    final hStmt = _execStatement(query, params);

    return _getResult(hStmt);
  }

  Pointer<Void> _execStatement(String query, List<dynamic>? params) {
    if (params != null) {
      _validateParams(params);
    }


    final pointers = <OdbcPointer<dynamic>>[];
    final strLenPointers = <Pointer<Long>>[];
    final pHStmt = calloc<SQLHSTMT>();
    _tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHStmt);
      },
    );

    // hstatement will be freed by the cursor
    final hStmt = pHStmt.value;

    // WORKAROUND for ODBC Driver 18 HY104 issue with SQL_WVARCHAR
    // parameter binding
    //
    // Issue: ODBC Driver 18.x for SQL Server returns HY104
    // (Invalid parameter value) when binding string parameters using
    // SQLBindParameter with SQL_WVARCHAR.
    //
    // Solution: Substitute string parameters directly into the query using
    // SQL-standard escaping (single quotes doubled), while keeping non-string
    // parameters bound securely via SQLBindParameter.
    //
    // Security: String escaping prevents SQL injection but is less secure than
    // true parameter binding. Non-string parameters remain fully secure.
    //
    // Performance: Substituted queries cannot use cached query plans, slightly
    // reducing performance for repeated queries with different string values.
    //
    // Alternative solutions tested:
    // - SQL_WLONGVARCHAR: Still causes HY104 on Driver 18.x
    // - SQL_LONGVARCHAR: Loses Unicode support (unacceptable)
    // - SQL_VARCHAR: Loses Unicode support (unacceptable)
    //
    // Status: This workaround is necessary until ODBC Driver 18.x is fixed
    // or a better binding method is discovered. Monitor driver updates.
    //
    // TODO(odbc): Test with ODBC Driver 18.3+ which may have HY104 fixes
    final hasStringParams = params != null && params.any((p) => p is String);

    String finalQuery;
    List<dynamic>? remainingParams;

    if (hasStringParams) {
      // Replace string parameters directly in query with escaped values
      // Keep non-string parameters for binding
      final (substitutedQuery, nonStringParams) = _substituteStringParams(
        query,
        // hasStringParams guarantees params != null, but analyzer can't see it
        // ignore: unnecessary_non_null_assertion
        params!,
      );
      finalQuery = substitutedQuery;
      remainingParams = nonStringParams.isEmpty ? null : nonStringParams;
    } else {
      // No string parameters, use normal prepared statement flow
      finalQuery = query;
      remainingParams = params;
    }

    final cQuery = finalQuery.toNativeUtf16();

    // binding sanitized params (only non-string params if workaround was used)
    if (remainingParams != null) {
      _tryOdbc(
        _sql.SQLPrepareW(hStmt, cQuery.cast(), SQL_NTS),
        handle: hStmt,
        onException: QueryException(),
        beforeThrow: () {
          calloc
            ..free(cQuery)
            ..free(pHStmt);
          _freeSqlStmtHandle(hStmt);
        },
      );

      for (var i = 0; i < remainingParams.length; i++) {
        final param = remainingParams[i];

        // Standard parameter binding for non-string types
        // String parameters were already substituted in the query
        final columnSize = OdbcConversions.getColumnSizeFromValue(
          param,
          param.runtimeType,
        );

        final cParam = OdbcConversions.toPointer(param);

        // For strings, use SQL_NTS since buffer is null-terminated
        // For other types, use actualSize or nullptr
        final pStrLen = param is String
            ? (calloc<SQLLEN>()..value = SQL_NTS)
            : (cParam.actualSize != null
                ? (calloc<SQLLEN>()..value = cParam.actualSize!)
                : nullptr);
        strLenPointers.add(pStrLen);

        // BufferLength is the size of the allocated buffer in bytes
        // For strings with SQL_NTS, BufferLength should NOT include the null
        // terminator toNativeUtf16() includes null terminator, so subtract it
        final bufferLength = param is String
            ? cParam.length - sizeOf<Uint16>()
            : cParam.length;

        final cType = OdbcConversions.getCtypeFromType(param.runtimeType);
        final sqlType = OdbcConversions.getSqlTypeFromType(param.runtimeType);
        final decimalDigits = OdbcConversions.getDecimalDigitsFromType(
          param.runtimeType,
        );

        final bindResult = _sql.SQLBindParameter(
          hStmt,
          i + 1,
          SQL_PARAM_INPUT,
          cType,
          sqlType,
          columnSize,
          decimalDigits,
          cParam.ptr,
          bufferLength,
          pStrLen,
        );

        _tryOdbc(
          bindResult,
          handle: hStmt,
          beforeThrow: () {
            calloc
              ..free(cQuery)
              ..free(pStrLen)
              ..free(pHStmt);
            cParam.free();
            _freeSqlStmtHandle(hStmt);

            for (final p in pointers) {
              p.free();
            }
          },
        );

        pointers.add(cParam);
      }
    }

    // If workaround was used (hasStringParams), use SQLExecDirectW directly
    // Otherwise, use prepared statement flow
    if (hasStringParams || remainingParams == null) {
      _tryOdbc(
        _sql.SQLExecDirectW(hStmt, cQuery.cast(), SQL_NTS),
        handle: hStmt,
        beforeThrow: () {
          calloc
            ..free(cQuery)
            ..free(pHStmt);
          _freeSqlStmtHandle(hStmt);
        },
      );
    } else {
      _tryOdbc(
        _sql.SQLExecute(hStmt),
        handle: hStmt,
        beforeThrow: () {
          calloc
            ..free(cQuery)
            ..free(pHStmt);
          _freeSqlStmtHandle(hStmt);
        },
      );
    }

    // free memory
    for (final ptr in pointers) {
      ptr.free();
    }
    for (final p in strLenPointers) {
      if (p != nullptr) {
        calloc.free(p);
      }
    }
    calloc
      ..free(cQuery)
      ..free(pHStmt);

    return hStmt;
  }

  /// Substitute string parameters directly into query with escaped values.
  ///
  /// Returns: (substituted query, remaining non-string parameters)
  ///
  /// This function processes parameter placeholders (?) in the query:
  /// - String parameters: Replaced with escaped and quoted values
  /// - Non-string parameters: Left as ? for SQLBindParameter
  ///
  /// Example:
  /// ```dart
  /// query: "SELECT * FROM users WHERE name = ? AND age = ?"
  /// params: ["O'Brien", 30]
  /// result: ("SELECT * FROM users WHERE name = 'O''Brien' AND age = ?", [30])
  /// ```
  ///
  /// Security: String escaping uses SQL standard (doubled quotes) which is
  /// secure against SQL injection. However, parameter binding is still
  /// preferred for maximum security.
  ///
  /// This is a workaround for ODBC Driver 18 HY104 issue. See [_execStatement]
  /// documentation for details.
  (String query, List<dynamic> params) _substituteStringParams(
    String query,
    List<dynamic> params,
  ) {
    if (params.isEmpty) {
      return (query, []);
    }

    final remainingParams = <dynamic>[];
    final buffer = StringBuffer();
    var paramIndex = 0;
    var queryIndex = 0;

    while (queryIndex < query.length) {
      if (query[queryIndex] == '?' && paramIndex < params.length) {
        final param = params[paramIndex];
        if (param is String) {
          // Substitute string parameter with escaped value
          final escapedValue = _escapeSqlString(param);
          buffer.write("'$escapedValue'");
        } else {
          // Keep non-string parameters as placeholders for binding
          buffer.write('?');
          remainingParams.add(param);
        }
        paramIndex++;
        queryIndex++;
      } else {
        buffer.write(query[queryIndex]);
        queryIndex++;
      }
    }

    final substituted = buffer.toString();

    return (substituted, remainingParams);
  }

  /// Escape SQL string to prevent SQL injection.
  ///
  /// Uses SQL-standard escaping: single quotes are doubled.
  /// This is the ANSI SQL standard method for escaping string literals.
  ///
  /// Examples:
  /// - "John" -> "John"
  /// - "O'Brien" -> "O''Brien"
  /// - "It's a test" -> "It''s a test"
  ///
  /// Note: This method is secure against SQL injection when the escaped
  /// string is wrapped in single quotes: WHERE name = 'escaped_value'
  ///
  /// Security: This is less secure than parameter binding (SQLBindParameter)
  /// but is necessary as a workaround for ODBC Driver 18 HY104 issue.
  String _escapeSqlString(String value) {
    // SQL standard: double any single quotes
    // This is the ANSI SQL way to escape quotes in string literals
    return value.replaceAll("'", "''");
  }


  /// Validates that all parameters are of supported types.
  ///
  /// Supported types: int, double, String, bool, DateTime, Uint8List, null.
  /// Throws [QueryException] if any parameter has an unsupported type.
  void _validateParams(List<dynamic> params) {
    for (var i = 0; i < params.length; i++) {
      final param = params[i];
      final type = param.runtimeType;

      final isSupported = param == null ||
          param is int ||
          param is double ||
          param is String ||
          param is bool ||
          param is DateTime ||
          param is Uint8List;

      if (!isSupported) {
        throw QueryException()
          ..message =
              'Unsupported parameter type at index $i: $type. '
              'Supported types are: int, double, String, bool, DateTime, '
              'Uint8List, or null.';
      }
    }
  }
}
