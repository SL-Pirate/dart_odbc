// ignore_for_file: unnecessary_statements

/// Dart ODBC
library dart_odbc;

import 'dart:ffi';
import 'package:dart_odbc/ffi/libodbc.dart';
import 'package:ffi/ffi.dart';

/// DartOdbc class
/// This is the base class that will be used to interact with the ODBC driver.
class DartOdbc {
  /// DartOdbc constructor
  /// This constructor will initialize the ODBC environment and connection.
  /// The [pathToDriver] parameter is the path to the ODBC driver.
  /// The [version] parameter is the Open Database Connectivity standard version
  /// to be used. The default value is [SQL_OV_ODBC3_80] which is the latest
  /// Definitions for these values can be found in the [LibODBC] class.
  DartOdbc(String pathToDriver, {int version = SQL_OV_ODBC3_80})
      : _sql = LibODBC(DynamicLibrary.open(pathToDriver)) {
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
    _hEnv = pHEnv.value;
    _sql.SQLSetEnvAttr(
              _hEnv,
              SQL_ATTR_ODBC_VERSION,
              Pointer.fromAddress(sqlOvOdbc.address),
              0,
            ) ==
            SQL_ERROR
        ? throw Exception('Failed to set environment attribute')
        : null;
    calloc
      ..free(sqlOvOdbc)
      ..free(pHEnv)
      ..free(sqlNullHandle);
  }

  final LibODBC _sql;
  SQLHANDLE _hEnv = nullptr;
  SQLHDBC _hConn = nullptr;

  /// Connect to a database
  /// The [dsn] parameter is the Data Source Name.
  /// This is the name you gave when setting up the ODBC manager.
  /// The [username] parameter is the username to connect to the database.
  /// The [password] parameter is the password to connect to the database.
  void connect({
    required String dsn,
    required String username,
    required String password,
  }) {
    final pHConn = calloc.allocate<SQLHDBC>(sizeOf<SQLHDBC>());
    _sql.SQLAllocHandle(SQL_HANDLE_DBC, _hEnv, pHConn) == SQL_ERROR
        ? throw Exception('Failed to allocate connection handle')
        : null;
    _hConn = pHConn.value;
    _sql.SQLConnectW(
              _hConn,
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
    calloc.free(pHConn);
  }

  /// Execute a query
  /// The [query] parameter is the SQL query to execute.
  /// This function will return a list of maps where each map represents a row
  /// in the result set. The keys in the map are the column names and the values
  /// are the column values.
  List<Map<String, dynamic>> execute(String query) {
    final pHStmt = calloc.allocate<SQLHSTMT>(sizeOf<SQLHSTMT>());
    _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt) == SQL_ERROR
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
      columnNames.add(
        String.fromCharCodes(
          columnName.asTypedList(columnNameLength.value * 2),
        ),
      );

      // free memory
      calloc
        ..free(columnName)
        ..free(columnNameLength);
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

        // free memory
        calloc
          ..free(columnValue)
          ..free(columnValueLength);
      }

      rows.add(row);
    }

    // free memory
    _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
    calloc.free(columnCount);

    return rows;
  }
}
