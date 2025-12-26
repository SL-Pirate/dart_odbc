part of './base.dart';

extension on DartOdbc {
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
        onException
          ..sqlState = pSqlState.cast<Utf16>().toDartString()
          ..code = pNativeErr.value
          ..message = pMesg.cast<Utf16>().toDartString(length: pMsgLen.value);
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
