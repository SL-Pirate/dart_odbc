part of './base.dart';

extension on DartOdbc {
  Future<void> _connect({
    required String username,
    required String password,
  }) async {
    if (_dsn == null) {
      throw ODBCException('DSN not provided');
    }
    final dsnLocal = _dsn!;
    final pHConn = calloc<SQLHDBC>();
    _tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_DBC, _hEnv, pHConn),
      handle: _hEnv,
      operationType: SQL_HANDLE_DBC,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHConn);
      },
    );
    _hConn = pHConn.value;
    final cDsn = dsnLocal.toNativeUtf16().cast<UnsignedShort>();
    final cUsername = username.toNativeUtf16().cast<UnsignedShort>();
    final cPassword = password.toNativeUtf16().cast<UnsignedShort>();
    _tryOdbc(
      _sql.SQLConnectW(
        _hConn,
        cDsn,
        SQL_NTS,
        cUsername,
        SQL_NTS,
        cPassword,
        SQL_NTS,
      ),
      handle: _hConn,
      operationType: SQL_HANDLE_DBC,
      onException: ConnectionException(),
      beforeThrow: () {
        calloc
          ..free(pHConn)
          ..free(cDsn)
          ..free(cUsername)
          ..free(cPassword);
      },
    );
    calloc
      ..free(pHConn)
      ..free(cDsn)
      ..free(cUsername)
      ..free(cPassword);
  }

  Future<String> _connectWithConnectionString(String connectionString) async {
    final pHConn = calloc<SQLHDBC>();
    _tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_DBC, _hEnv, pHConn),
      handle: _hEnv,
      operationType: SQL_HANDLE_DBC,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHConn);
      },
    );
    _hConn = pHConn.value;

    final cConnectionString = connectionString.toNativeUtf16();
    final outChars = defaultBufferSize ~/ sizeOf<Uint16>();
    final pOutConnectionString = calloc<Uint16>(outChars);
    final pOutConnectionStringLen = calloc<Short>();

    _tryOdbc(
      _sql.SQLDriverConnectW(
        _hConn,
        nullptr,
        cConnectionString.cast(),
        SQL_NTS,
        pOutConnectionString.cast(),
        outChars,
        pOutConnectionStringLen,
        SQL_DRIVER_NOPROMPT,
      ),
      handle: _hConn,
      operationType: SQL_HANDLE_DBC,
      onException: ConnectionException(),
      beforeThrow: () {
        calloc
          ..free(pHConn)
          ..free(cConnectionString)
          ..free(pOutConnectionString)
          ..free(pOutConnectionStringLen);
      },
    );

    final completedConnectionString = pOutConnectionString
        .cast<Utf16>()
        .toDartString(length: pOutConnectionStringLen.value);

    calloc
      ..free(pHConn)
      ..free(cConnectionString)
      ..free(pOutConnectionString)
      ..free(pOutConnectionStringLen);

    return completedConnectionString;
  }

  Future<void> _disconnect() async {
    if (_hConn != nullptr) {
      final disconnectStatus = _sql.SQLDisconnect(_hConn);

      if (![SQL_SUCCESS, SQL_SUCCESS_WITH_INFO, SQL_INVALID_HANDLE]
          .contains(disconnectStatus)) {
        _log.warning(
          'Failed to disconnect from the database. '
          'Status code: $disconnectStatus',
        );
      }

      final freeConnStatus = _sql.SQLFreeHandle(SQL_HANDLE_DBC, _hConn);

      if (![SQL_SUCCESS, SQL_SUCCESS_WITH_INFO, SQL_INVALID_HANDLE]
          .contains(freeConnStatus)) {
        _log.warning(
          'Failed to free connection handle. Status code: $freeConnStatus',
        );
      }
    }

    if (_hEnv != nullptr) {
      final freeEnvStatus = _sql.SQLFreeHandle(SQL_HANDLE_ENV, _hEnv);

      if (![SQL_SUCCESS, SQL_SUCCESS_WITH_INFO, SQL_INVALID_HANDLE]
          .contains(freeEnvStatus)) {
        _log.warning(
          'Failed to free environment handle. Status code: $freeEnvStatus',
        );
      }
    }

    _hConn = nullptr;
    _hEnv = nullptr;
  }
}
