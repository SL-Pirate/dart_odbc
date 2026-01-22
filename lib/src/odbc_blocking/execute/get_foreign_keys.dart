part of '../base.dart';

extension on DartOdbcBlockingClient {
  Future<List<Map<String, dynamic>>> _getForeignKeys({
    String? pkTableName,
    String? fkTableName,
    String? pkCatalog,
    String? pkSchema,
    String? fkCatalog,
    String? fkSchema,
  }) async {
    if (_hEnv == nullptr || _hConn == nullptr) {
      throw ODBCException('Not connected to the database');
    }

    final pHStmt = calloc<SQLHSTMT>();
    _tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHStmt);
      },
    );

    final hStmt = pHStmt.value;

    final cPkCatalog = pkCatalog?.toNativeUtf16().cast<UnsignedShort>() ??
        nullptr;
    final cPkSchema =
        pkSchema?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cPkTableName =
        pkTableName?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cFkCatalog =
        fkCatalog?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cFkSchema =
        fkSchema?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cFkTableName =
        fkTableName?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;

    _tryOdbc(
      _sql.SQLForeignKeysW(
        hStmt,
        cPkCatalog,
        SQL_NTS,
        cPkSchema,
        SQL_NTS,
        cPkTableName,
        SQL_NTS,
        cFkCatalog,
        SQL_NTS,
        cFkSchema,
        SQL_NTS,
        cFkTableName,
        SQL_NTS,
      ),
      handle: hStmt,
      onException: FetchException(),
      beforeThrow: () {
        calloc
          ..free(pHStmt)
          ..free(cPkCatalog)
          ..free(cPkSchema)
          ..free(cPkTableName)
          ..free(cFkCatalog)
          ..free(cFkSchema)
          ..free(cFkTableName);
      },
    );

    calloc
      ..free(pHStmt)
      ..free(cPkCatalog)
      ..free(cPkSchema)
      ..free(cPkTableName)
      ..free(cFkCatalog)
      ..free(cFkSchema)
      ..free(cFkTableName);

    return _getResultBulk(hStmt);
  }
}
