part of '../base.dart';

extension on DartOdbcBlockingClient {
  Future<List<Map<String, dynamic>>> _getTables({
    String? tableName,
    String? catalog,
    String? schema,
    String? tableType,
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

    // hstatement will be freed by the cursor
    final hStmt = pHStmt.value;

    final cCatalog = catalog?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cSchema = schema?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cTableName =
        tableName?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cTableType =
        tableType?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;

    _tryOdbc(
      _sql.SQLTablesW(
        hStmt,
        cCatalog,
        SQL_NTS,
        cSchema,
        SQL_NTS,
        cTableName,
        SQL_NTS,
        cTableType,
        SQL_NTS,
      ),
      handle: hStmt,
      onException: FetchException(),
      beforeThrow: () {
        calloc
          ..free(pHStmt)
          ..free(cCatalog)
          ..free(cSchema)
          ..free(cTableName)
          ..free(cTableType);
      },
    );

    calloc
      ..free(pHStmt)
      ..free(cCatalog)
      ..free(cSchema)
      ..free(cTableName)
      ..free(cTableType);

    return _getResultBulk(hStmt);
  }
}
