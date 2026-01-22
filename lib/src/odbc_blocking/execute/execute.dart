part of '../base.dart';

extension on DartOdbcBlockingClient {
  Future<List<Map<String, dynamic>>> _execute(
    String query, {
    List<dynamic>? params,
  }) async {
    if (_hEnv == nullptr || _hConn == nullptr) {
      throw ODBCException('Not connected to the database');
    }

    // Transform SELECT * queries before execution
    final transformedQuery = await _transformSelectStarQueryAsync(query);

    final hStmt = _execStatement(transformedQuery, params);

    return _getResultBulk(hStmt);
  }

  Future<OdbcCursor> _executeCursor(
    String query, {
    List<dynamic>? params,
  }) async {
    if (_hEnv == nullptr || _hConn == nullptr) {
      throw ODBCException('Not connected to the database');
    }

    // Transform SELECT * queries before execution
    final transformedQuery = await _transformSelectStarQueryAsync(query);

    final hStmt = _execStatement(transformedQuery, params);

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

    // WORKAROUND for ODBC Driver 18 HY104 issue
    // ODBC Driver 18 for SQL Server returns HY104 (Invalid parameter value)
    // when binding string parameters using SQLBindParameter with SQL_WVARCHAR.
    // This workaround substitutes string parameters directly into the query
    // using SQLExecDirectW, while non-string parameters continue to use
    // prepared statements for security.
    //
    // Security considerations:
    // - String parameters are escaped using SQL standard (single quotes
    //   doubled)
    // - This prevents SQL injection but is less secure than parameter binding
    // - Non-string parameters still use prepared statements (secure)
    //
    // Limitations:
    // - String parameters cannot be null (use empty string instead)
    // - Performance may be slightly worse due to lack of query plan caching
    //
    // TODO(odbc): Investigate root cause and remove workaround when ODBC Driver
    //             18 issue is resolved or alternative binding method is found.
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

  /// Substitute string parameters directly in query with escaped values.
  ///
  /// Returns the substituted query and list of remaining non-string parameters.
  ///
  /// This is a workaround for ODBC Driver 18 HY104 issue with string parameter
  /// binding. String parameters are escaped using SQL standard (single quotes
  /// doubled) to prevent SQL injection, but this is less secure than parameter
  /// binding used for non-string types.
  ///
  /// See [_execStatement] documentation for more details on the workaround.
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

  /// Escape SQL string to prevent SQL injection
  /// Replaces single quotes with two single quotes (SQL standard)
  String _escapeSqlString(String value) {
    return value.replaceAll("'", "''");
  }

  /// Transform SELECT * queries to use CAST AS NVARCHAR(MAX) for all columns.
  ///
  /// This prevents buffer/memory errors (HY090/HY001) when querying tables
  /// with many columns or large data types. The transformation:
  /// - Detects SELECT * FROM table patterns
  /// - Obtains column names from INFORMATION_SCHEMA or sys.columns
  /// - Replaces SELECT * with explicit column list using CAST AS NVARCHAR(MAX)
  ///
  /// Returns the original query if no transformation is needed.
  Future<String> _transformSelectStarQueryAsync(String query) async {
    // Simple regex to detect SELECT * FROM table pattern
    // Match: SELECT [TOP n] [DISTINCT] * FROM table (with optional schema/alias)
    final selectStarPattern = RegExp(
      r'SELECT\s+((?:TOP\s+\d+\s+)?(?:DISTINCT\s+)?)\*\s+FROM\s+(\[?(\w+)\]?\.)?(\[?(\w+)\]?)',
      caseSensitive: false,
    );

    final match = selectStarPattern.firstMatch(query);
    if (match == null) {
      // No SELECT * found, return original query
      return query;
    }

    // Extract modifiers (TOP, DISTINCT), table name and schema
    final modifiers = match.group(1) ?? '';
    final schema = match.group(3);
    final tableName = match.group(5);
    if (tableName == null) {
      return query;
    }

    // Log transformation attempt
    _log.fine(
      'Transforming SELECT * query: table=$tableName, schema=$schema',
    );

    // Get column names from sys.columns (more reliable than INFORMATION_SCHEMA)
    // Try with schema first, then without schema, then with 'dbo' as default
    final columnQuery = schema != null
        ? 'SELECT c.name FROM sys.columns c '
            'INNER JOIN sys.tables t ON c.object_id = t.object_id '
            'INNER JOIN sys.schemas s ON t.schema_id = s.schema_id '
            "WHERE s.name = '$schema' AND t.name = '$tableName' "
            'ORDER BY c.column_id'
        : 'SELECT c.name FROM sys.columns c '
            'INNER JOIN sys.tables t ON c.object_id = t.object_id '
            'INNER JOIN sys.schemas s ON t.schema_id = s.schema_id '
            "WHERE (s.name = 'dbo' OR s.name = SCHEMA_NAME()) "
            "AND t.name = '$tableName' "
            'ORDER BY c.column_id';

    // Execute query to get column names
    // Note: This requires a separate statement handle
    // We'll use a simpler approach: execute the metadata query first
    final tempHStmt = calloc<SQLHSTMT>();
    try {
      _tryOdbc(
        _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, tempHStmt),
        handle: _hConn,
        onException: HandleException(),
      );

      final cColumnQuery = columnQuery.toNativeUtf16();
      try {
        _tryOdbc(
          _sql.SQLExecDirectW(tempHStmt.value, cColumnQuery.cast(), SQL_NTS),
          handle: tempHStmt.value,
          onException: QueryException(),
        );

        final columns = <String>[];
        final pColumnValueLength = calloc<SQLLEN>();
        final buf = calloc.allocate(_bufferSize);
        try {
          while (true) {
            final rc = _sql.SQLFetch(tempHStmt.value);
            if (rc < 0 || rc == SQL_NO_DATA) {
              break;
            }

            // Incremental read for wide char (UTF-16) data
            final unitBuf = _bufferSize ~/ sizeOf<Uint16>();
            final bufBytes = unitBuf * sizeOf<Uint16>();
            final collectedUnits = <int>[];

            while (true) {
              final status = _tryOdbc(
                _sql.SQLGetData(
                  tempHStmt.value,
                  1,
                  SQL_WCHAR,
                  buf.cast(),
                  bufBytes,
                  pColumnValueLength,
                ),
                handle: tempHStmt.value,
                onException: FetchException(),
              );

              if (pColumnValueLength.value == SQL_NULL_DATA) {
                break;
              }

              final returnedBytes = pColumnValueLength.value;
              final maxUnitsInBuffer = unitBuf;

              final unitsReturned = returnedBytes == SQL_NO_TOTAL
                  ? maxUnitsInBuffer
                  : (returnedBytes ~/ sizeOf<Uint16>())
                      .clamp(0, maxUnitsInBuffer);

              if (unitsReturned > 0) {
                collectedUnits
                    .addAll(buf.cast<Uint16>().asTypedList(unitsReturned));
              }

              if (status == SQL_SUCCESS) {
                break;
              }
            }

            if (collectedUnits.isNotEmpty) {
              collectedUnits.removeWhere((e) => e == 0);
              final columnName = String.fromCharCodes(collectedUnits);
              columns.add(columnName);
            }
          }
        } finally {
          calloc
            ..free(buf)
            ..free(pColumnValueLength);
        }

        calloc.free(cColumnQuery);
        _freeSqlStmtHandle(tempHStmt.value);
        calloc.free(tempHStmt);

        if (columns.isEmpty) {
          // No columns found, return original query
          return query;
        }

        // Build transformed query with CAST AS NVARCHAR(MAX)
        final tableRef = schema != null
            ? '[$schema].[$tableName]'
            : '[$tableName]';
        final castColumns = columns
            .map((col) => 'CAST([$col] AS NVARCHAR(MAX)) AS [$col]')
            .join(', ');

        // Replace SELECT * FROM table with transformed version
        // Preserve TOP and DISTINCT modifiers if present
        final transformed = query.replaceFirst(
          selectStarPattern,
          'SELECT $modifiers$castColumns FROM $tableRef',
        );

        _log.fine(
          'SELECT * transformed successfully: ${columns.length} columns',
        );
        return transformed;
      } on Object catch (e) {
        _log.warning(
          'Failed to transform SELECT * query (metadata query failed): $e',
        );
        calloc.free(cColumnQuery);
        _freeSqlStmtHandle(tempHStmt.value);
        calloc.free(tempHStmt);
        // If metadata query fails, return original query
        return query;
      }
    } on Object catch (e) {
      _log.warning(
        'Failed to transform SELECT * query (allocation failed): $e',
      );
      calloc.free(tempHStmt);
      // If allocation fails, return original query
      return query;
    }
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
