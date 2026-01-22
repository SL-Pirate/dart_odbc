part of 'base.dart';

extension on DartOdbcBlockingClient {
  int _tryOdbc(
    int status, {
    SQLHANDLE? handle,
    int operationType = SQL_HANDLE_STMT,
    ODBCException? onException,
    void Function()? beforeThrow,
  }) {
    if (status >= 0) {
      return status;
    }

    onException ??= ODBCException('ODBC error');
    onException.code = status;

    if (handle == null || handle == nullptr) {
      beforeThrow?.call();
      throw onException;
    }

    final pSqlState = calloc<Uint16>(6);
    final pNativeErr = calloc<Int>();
    final pMesg = calloc<Uint16>(1024);
    final pMsgLen = calloc<Short>();

    try {
      final diagStatus = _sql.SQLGetDiagRecW(
        operationType,
        handle,
        1,
        pSqlState.cast(),
        pNativeErr,
        pMesg.cast(),
        1024,
        pMsgLen,
      );

      if (diagStatus >= 0) {
        final sqlState = pSqlState.cast<Utf16>().toDartString();
        final nativeErr = pNativeErr.value;
        final message = pMesg.cast<Utf16>().toDartString(length: pMsgLen.value);

        // #region agent log
        try {
          File(r'd:\Developer\Flutter\dart_odbc\.cursor\debug.log')
              .writeAsStringSync(
            '${jsonEncode({
                  'sessionId': 'debug-session',
                  'runId': 'run1',
                  'hypothesisId': 'A,B,C,D,E',
                  'location': 'handler.dart:_tryOdbc',
                  'message': 'ODBC error detected',
                  'data': {
                    'status': status,
                    'sqlState': sqlState,
                    'nativeError': nativeErr,
                    'errorMessage': message,
                    'operationType': operationType,
                    'isHY104': sqlState == 'HY104',
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                  },
                })}\n',
            mode: FileMode.append,
          );
        } on Exception {
          // Ignore logging errors
        }
        // #endregion

        onException
          ..sqlState = sqlState
          ..code = nativeErr
          ..message = message;
      }
    } on Exception {
      _log.warning('Failed to retrieve ODBC diagnostics.');
    } finally {
      calloc
        ..free(pSqlState)
        ..free(pNativeErr)
        ..free(pMesg)
        ..free(pMsgLen);
    }

    beforeThrow?.call();
    throw onException;
  }

  void _freeSqlStmtHandle(SQLHSTMT hStmt) {
    final resetStatus = _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);

    if (![SQL_SUCCESS, SQL_SUCCESS_WITH_INFO].contains(resetStatus)) {
      _log.warning(
        'Failed to cleanup statement handle. '
        'Status code: $resetStatus',
      );
    }
  }
}
