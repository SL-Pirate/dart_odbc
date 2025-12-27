part of '../base.dart';

extension on DartOdbc {
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
    final pointers = <OdbcPointer<dynamic>>[];
    final strLenPointers = <Pointer<Long>>[];
    final pHStmt = calloc<SQLHSTMT>();
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHStmt);
      },
    );

    // hstatement will be freed by the cursor
    final hStmt = pHStmt.value;

    final cQuery = query.toNativeUtf16();

    // binding sanitized params
    if (params != null) {
      tryOdbc(
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

      for (var i = 0; i < params.length; i++) {
        final param = params[i];
        final cParam = OdbcConversions.toPointer(param);

        // if the param is a string or binary data, set the length pointer
        final pStrLen = cParam.actualSize != null
            ? (calloc<SQLLEN>()..value = cParam.actualSize!)
            : nullptr;
        strLenPointers.add(pStrLen);

        tryOdbc(
          _sql.SQLBindParameter(
            hStmt,
            i + 1,
            SQL_PARAM_INPUT,
            OdbcConversions.getCtypeFromType(param.runtimeType),
            OdbcConversions.getSqlTypeFromType(param.runtimeType),
            0,
            OdbcConversions.getDecimalDigitsFromType(
              param.runtimeType,
            ),
            cParam.ptr,
            cParam.length,
            pStrLen,
          ),
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

    if (params == null) {
      tryOdbc(
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
      tryOdbc(
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
}
