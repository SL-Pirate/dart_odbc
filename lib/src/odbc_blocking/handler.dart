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

    final pSqlState = calloc<Uint16>(sqlStateLength);
    final pNativeErr = calloc<Int>();
    final pMesg = calloc<Uint16>(maxErrorMessageLength);
    final pMsgLen = calloc<Short>();

    try {
      final diagStatus = _sql.SQLGetDiagRecW(
        operationType,
        handle,
        1,
        pSqlState.cast(),
        pNativeErr,
        pMesg.cast(),
        maxErrorMessageLength,
        pMsgLen,
      );

      if (diagStatus >= 0) {
        final sqlState = pSqlState.cast<Utf16>().toDartString();
        final nativeErr = pNativeErr.value;
        final message = pMesg.cast<Utf16>().toDartString(length: pMsgLen.value);

        onException
          ..sqlState = sqlState
          ..code = nativeErr
          ..message = message;
      }
    } on Exception catch (e, st) {
      _log.warning(
        'Failed to retrieve ODBC diagnostics.',
        e,
        st,
      );
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
