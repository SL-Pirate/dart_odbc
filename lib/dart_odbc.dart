library dart_odbc;

import 'dart:ffi';

import 'package:dart_odbc/generated/sql.dart';
import 'package:ffi/ffi.dart';

class DartOdbc {
  final SQL _sql;
  SQLHANDLE hEnv;
  SQLHDBC hConn;

  DartOdbc(String pathToDriver, {int version = SQL_OV_ODBC3_80})
      : _sql = SQL(DynamicLibrary.open(pathToDriver)),
        hEnv = calloc.allocate(sizeOf<SQLHENV>()),
        hConn = calloc.allocate(sizeOf<SQLHDBC>()) {
    final sqlOvOdbc = calloc.allocate<SQLULEN>(sizeOf<SQLULEN>())
      ..value = version;
    final sqlNullHandle = calloc.allocate<Int>(sizeOf<Int>())
      ..value = SQL_NULL_HANDLE;
    final pHEnv = calloc.allocate<SQLHANDLE>(sizeOf<SQLHANDLE>());
    (_sql.SQLAllocHandle(
              SQL_HANDLE_ENV,
              Pointer.fromAddress(sqlNullHandle.address),
              pHEnv,
            ) ==
            SQL_ERROR)
        ? throw Exception('Failed to allocate environment handle')
        : null;
    hEnv = pHEnv.value;
    _sql.SQLSetEnvAttr(
              hEnv,
              SQL_ATTR_ODBC_VERSION,
              Pointer.fromAddress(sqlOvOdbc.address),
              0,
            ) ==
            SQL_ERROR
        ? throw Exception('Failed to set environment attribute')
        : null;
  }

  void connect({
    required String dsn,
    required String username,
    required String password,
  }) {
    final pHConn = calloc.allocate<SQLHDBC>(sizeOf<SQLHDBC>());
    _sql.SQLAllocHandle(SQL_HANDLE_DBC, hEnv, pHConn) == SQL_ERROR
        ? throw Exception('Failed to allocate connection handle')
        : null;
    hConn = pHConn.value;
    _sql.SQLConnectW(
              hConn,
              dsn.toNativeUtf16().cast(),
              dsn.length,
              username.toNativeUtf16().cast(),
              username.length,
              password.toNativeUtf16().cast(),
              password.length,
            ) ==
            SQL_ERROR
        ? throw Exception('Failed to connect to database')
        : null;
  }

  execute(String query) {
    final pHStmt = calloc.allocate<SQLHSTMT>(sizeOf<SQLHSTMT>());
    _sql.SQLAllocHandle(SQL_HANDLE_STMT, hConn, pHStmt) == SQL_ERROR
        ? throw Exception('Failed to allocate statement handle')
        : null;
    final hStmt = pHStmt.value;
    _sql.SQLExecDirectW(
              hStmt,
              query.toNativeUtf16().cast(),
              query.length,
            ) ==
            SQL_ERROR
        ? throw Exception('Failed to execute query')
        : null;

    final columnCount = calloc.allocate<SQLSMALLINT>(sizeOf<SQLSMALLINT>());
    _sql.SQLNumResultCols(hStmt, columnCount) == SQL_ERROR
        ? throw Exception('Failed to get number of columns')
        : null;

    final columnNames = <String>[];
    for (var i = 1; i <= columnCount.value; i++) {
      final columnNameLength =
          calloc.allocate<SQLSMALLINT>(sizeOf<SQLSMALLINT>());
      final columnName = calloc.allocate<Uint16>(sizeOf<Uint16>() * 256);
      _sql.SQLDescribeColW(
                hStmt,
                i,
                columnName.cast(),
                256,
                columnNameLength,
                nullptr,
                nullptr,
                nullptr,
                nullptr,
              ) ==
              SQL_ERROR
          ? throw Exception('Failed to get column name')
          : null;
      columnNames.add(String.fromCharCodes(
          columnName.asTypedList(columnNameLength.value * 2)));
    }

    final rows = <Map<String, dynamic>>[];

    while (_sql.SQLFetch(hStmt) == SQL_SUCCESS) {
      final row = <String, dynamic>{};
      for (var i = 1; i <= columnCount.value; i++) {
        final columnValueLength = calloc.allocate<SQLLEN>(sizeOf<SQLLEN>());
        final columnValue = calloc.allocate<Uint16>(sizeOf<Uint16>() * 256);
        _sql.SQLGetData(
                  hStmt,
                  i,
                  SQL_C_WCHAR,
                  columnValue.cast(),
                  256,
                  columnValueLength,
                ) ==
                SQL_ERROR
            ? throw Exception('Failed to get column value')
            : null;
        if (columnValueLength.value == SQL_NULL_DATA) {
          row[columnNames[i - 1]] = null;
          continue;
        }
        row[columnNames[i - 1]] = String.fromCharCodes(
          columnValue.asTypedList(columnValueLength.value * 2),
        );
      }
      rows.add(row);
    }

    _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
    return rows;
  }
}
