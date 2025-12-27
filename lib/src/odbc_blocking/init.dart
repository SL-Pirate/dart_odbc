part of 'base.dart';

extension on DartOdbcBlockingClient {
  void _initialize() {
    final pHEnv = calloc<SQLHANDLE>();
    _tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_ENV, nullptr, pHEnv),
      operationType: SQL_HANDLE_ENV,
      handle: pHEnv.value,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHEnv);
      },
    );
    _hEnv = pHEnv.value;

    _tryOdbc(
      _sql.SQLSetEnvAttr(
        _hEnv,
        SQL_ATTR_ODBC_VERSION,
        Pointer.fromAddress(SQL_OV_ODBC3),
        0,
      ),
      handle: _hEnv,
      operationType: SQL_HANDLE_ENV,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHEnv);
      },
    );

    calloc.free(pHEnv);
  }
}
