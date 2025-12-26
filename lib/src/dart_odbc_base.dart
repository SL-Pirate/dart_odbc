//
// ignore_for_file: lines_longer_than_80_chars

import 'dart:ffi';
import 'dart:typed_data';
import 'package:dart_odbc/dart_odbc.dart';
import 'package:ffi/ffi.dart';

/// DartOdbc class
/// This is the base class that will be used to interact with the ODBC driver.
class DartOdbc {
  /// DartOdbc constructor
  /// This constructor will initialize the ODBC environment and connection.
  /// The [pathToDriver] parameter is the path to the ODBC driver (optional).
  /// if [pathToDriver] is not provided, the driver will be auto-detected from the ODBC.ini file.
  /// The [dsn] parameter is the name of the DSN to connect to.
  /// If [dsn] is not provided, only [connectWithConnectionString] can be used.
  /// Definitions for these values can be found in the [LibOdbc] class.
  /// Please note that some drivers may not work with some drivers.
  DartOdbc({String? dsn, String? pathToDriver})
      : __sql = discoverDriver(pathToDriver),
        _dsn = dsn {
    _initialize();
  }

  final LibOdbc? __sql;
  final String? _dsn;
  SQLHANDLE _hEnv = nullptr;
  SQLHDBC _hConn = nullptr;

  void _initialize() {
    final sqlNullHandle = calloc.allocate<Int>(sizeOf<Int>());
    final pHEnv = calloc.allocate<SQLHANDLE>(sizeOf<SQLHANDLE>());
    tryOdbc(
      _sql.SQLAllocEnv(pHEnv),
      operationType: SQL_HANDLE_ENV,
      handle: pHEnv.value,
      onException: HandleException(),
    );
    _hEnv = pHEnv.value;

    calloc
      ..free(pHEnv)
      ..free(sqlNullHandle);
  }

  LibOdbc get _sql {
    if (__sql != null) {
      return __sql!;
    }

    throw ODBCException('ODBC driver not found');
  }

  /// Connect to a database
  /// This is the name you gave when setting up the ODBC manager.
  /// The [username] parameter is the username to connect to the database.
  /// The [password] parameter is the password to connect to the database.
  Future<void> connect({
    required String username,
    required String password,
  }) async {
    if (_dsn == null) {
      throw ODBCException('DSN not provided');
    }
    final dsnLocal = _dsn!;
    final pHConn = calloc.allocate<SQLHDBC>(sizeOf<SQLHDBC>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_DBC, _hEnv, pHConn),
      handle: _hEnv,
      operationType: SQL_HANDLE_DBC,
      onException: HandleException(),
    );
    _hConn = pHConn.value;
    final cDsn = dsnLocal.toNativeUtf16().cast<UnsignedShort>();
    final cUsername = username.toNativeUtf16().cast<UnsignedShort>();
    final cPassword = password.toNativeUtf16().cast<UnsignedShort>();
    tryOdbc(
      _sql.SQLConnectW(
        _hConn,
        cDsn,
        dsnLocal.length,
        cUsername,
        username.length,
        cPassword,
        password.length,
      ),
      handle: _hConn,
      operationType: SQL_HANDLE_DBC,
      onException: ConnectionException(),
    );
    calloc
      ..free(pHConn)
      ..free(cDsn)
      ..free(cUsername)
      ..free(cPassword);
  }

  /// Connects to the database using a connection string instead of a DSN.
  ///
  /// [connectionString] is the full connection string that provides all necessary
  /// connection details like driver, server, database, etc.
  ///
  /// This method is useful for connecting to data sources like Excel files or text files
  /// without having to define a DSN.
  ///
  /// Throws a [ConnectionException] if the connection fails.
  Future<void> connectWithConnectionString(String connectionString) async {
    final pHConn = calloc.allocate<SQLHDBC>(sizeOf<SQLHDBC>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_DBC, _hEnv, pHConn),
      handle: _hEnv,
      operationType: SQL_HANDLE_DBC,
      onException: HandleException(),
    );
    _hConn = pHConn.value;

    final cConnectionString =
        connectionString.toNativeUtf16().cast<UnsignedShort>();

    final outConnectionString =
        calloc.allocate<UnsignedShort>(defaultBufferSize);
    final outConnectionStringLen = calloc.allocate<Short>(sizeOf<Short>());

    tryOdbc(
      _sql.SQLDriverConnectW(
        _hConn,
        nullptr,
        cConnectionString,
        SQL_NTS,
        outConnectionString,
        defaultBufferSize,
        outConnectionStringLen,
        SQL_DRIVER_NOPROMPT,
      ),
      handle: _hConn,
      operationType: SQL_HANDLE_DBC,
      onException: ConnectionException(),
    );
    calloc
      ..free(pHConn)
      ..free(cConnectionString)
      ..free(outConnectionString)
      ..free(outConnectionStringLen);
  }

  /// Retrieves a list of tables from the connected database.
  ///
  /// Optionally, you can filter the results by specifying [tableName], [catalog],
  /// [schema], or [tableType]. If these are omitted, all tables will be returned.
  ///
  /// Returns a list of maps, where each map represents a table with its name,
  /// catalog, schema, and type.
  ///
  /// Throws a [FetchException] if fetching tables fails.
  Future<List<Map<String, dynamic>>> getTables({
    String? tableName,
    String? catalog,
    String? schema,
    String? tableType,
  }) async {
    final pHStmt = calloc.allocate<SQLHSTMT>(sizeOf<SQLHSTMT>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
    );
    final hStmt = pHStmt.value;

    final cCatalog = catalog?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cSchema = schema?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cTableName =
        tableName?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;
    final cTableType =
        tableType?.toNativeUtf16().cast<UnsignedShort>() ?? nullptr;

    tryOdbc(
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
    );

    final result = _getResult(hStmt, {});

    // Clean up
    _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
    calloc
      ..free(pHStmt)
      ..free(cCatalog)
      ..free(cSchema)
      ..free(cTableName)
      ..free(cTableType);

    return result;
  }

  /// Execute a query
  /// The [query] parameter is the SQL query to execute.
  /// This function will return a list of maps where each map represents a row
  /// in the result set. The keys in the map are the column names and the values
  /// are the column values.
  /// The [params] parameter is a list of parameters to bind to the query.
  /// Example query:
  /// ```dart
  /// final List<Map<String, dynamic>> result = odbc.execute(
  ///   'SELECT * FROM USERS WHERE UID = ?',
  ///   params: [1],
  /// );
  /// ```
  Future<List<Map<String, dynamic>>> execute(
    String query, {
    List<dynamic>? params,
    Map<String, ColumnType> columnConfig = const {},
  }) async {
    final pointers = <OdbcPointer<dynamic>>[];
    final pHStmt = calloc.allocate<SQLHSTMT>(sizeOf<SQLHSTMT>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
    );
    final hStmt = pHStmt.value;
    final cQuery = query.toNativeUtf16();

    // binding sanitized params
    if (params != null) {
      tryOdbc(
        _sql.SQLPrepareW(hStmt, cQuery.cast(), cQuery.length),
        handle: hStmt,
        onException: QueryException(),
      );

      for (var i = 0; i < params.length; i++) {
        final param = params[i];
        final cParam = OdbcConversions.toPointer(param);
        tryOdbc(
          _sql.SQLBindParameter(
            hStmt,
            i + 1,
            SQL_PARAM_INPUT,
            OdbcConversions.getCtypeFromType(param.runtimeType),
            OdbcConversions.getSqlTypeFromType(param.runtimeType),
            0,
            0,
            cParam.ptr,
            cParam.length,
            nullptr,
          ),
          handle: hStmt,
        );
        pointers.add(cParam);
      }
    }

    if (params == null) {
      tryOdbc(
        _sql.SQLExecDirectW(hStmt, cQuery.cast(), query.length),
        handle: hStmt,
      );
    } else {
      tryOdbc(_sql.SQLExecute(hStmt), handle: hStmt);
    }

    final result = _getResult(hStmt, columnConfig);

    // free memory
    for (final ptr in pointers) {
      ptr.free();
    }
    calloc
      ..free(cQuery)
      ..free(pHStmt);

    return result;
  }

  /// Function to disconnect from the database
  Future<void> disconnect() async {
    _sql
      ..SQLDisconnect(_hConn)
      ..SQLFreeHandle(SQL_HANDLE_DBC, _hConn)
      ..SQLFreeHandle(SQL_HANDLE_ENV, _hEnv);
    _hConn = nullptr;
    _hEnv = nullptr;
  }

  /// Function to handle ODBC errors
  /// The [status] parameter is the status code returned by the ODBC function.
  /// The [onException] parameter is the exception to throw if the status code
  /// is an error.
  /// The [handle] parameter is the handle to the ODBC object that caused the
  /// error.
  /// The [operationType] parameter is the type of operation that caused the
  /// error.
  /// If [handle] is not provided, the error message will not be descriptive.
  int tryOdbc(
    int status, {
    SQLHANDLE? handle,
    int operationType = SQL_HANDLE_STMT,
    ODBCException? onException,
  }) {
    if (status < 0) {
      onException ??= ODBCException('ODBC error');
      onException.code = status;
      if (handle != null) {
        final nativeErr = calloc.allocate<Int>(sizeOf<Int>())..value = status;
        final message = '1' * 10000;
        final msg = message.toNativeUtf16();
        final pStatus = calloc.allocate<UnsignedShort>(sizeOf<UnsignedShort>())
          ..value = status;
        try {
          _sql.SQLGetDiagRecW(
            operationType,
            handle,
            1,
            pStatus,
            nativeErr,
            msg.cast(),
            message.length,
            nullptr,
          );
        } on Exception {
          // ignore
        }

        onException.message = msg.toDartString();

        // free memory
        calloc
          ..free(nativeErr)
          ..free(msg)
          ..free(pStatus);
      }

      throw onException;
    } else {
      return status;
    }
  }

  List<Map<String, dynamic>> _getResult(
    SQLHSTMT hStmt,
    Map<String, ColumnType> columnConfig,
  ) {
    final columnCount = calloc.allocate<SQLSMALLINT>(sizeOf<SQLSMALLINT>());
    tryOdbc(
      _sql.SQLNumResultCols(hStmt, columnCount),
      handle: hStmt,
      onException: FetchException(),
    );

    // allocating memory for column names
    // outside the loop to reduce overhead in memory allocation
    final columnNameLength =
        calloc.allocate<SQLSMALLINT>(sizeOf<SQLSMALLINT>());
    final columnName =
        calloc.allocate<Uint16>(defaultBufferSize ~/ sizeOf<Uint16>());
    final columnNames = <String>[];

    for (var i = 1; i <= columnCount.value; i++) {
      tryOdbc(
        _sql.SQLDescribeColW(
          hStmt,
          i,
          columnName.cast(),
          defaultBufferSize,
          columnNameLength,
          nullptr,
          nullptr,
          nullptr,
          nullptr,
        ),
        handle: hStmt,
        onException: FetchException(),
      );
      final charCodes = columnName.asTypedList(columnNameLength.value).toList()
        ..removeWhere((e) => e == 0);
      columnNames.add(
        String.fromCharCodes(charCodes),
      );
    }

    // free memory
    calloc
      ..free(columnName)
      ..free(columnNameLength);

    final rows = <Map<String, dynamic>>[];

    // keeping outside the loop to reduce overhead in memory allocation
    final columnValueLength = calloc.allocate<SQLLEN>(sizeOf<SQLLEN>());
    final buf = calloc.allocate(defaultBufferSize);

    while (true) {
      final rc = _sql.SQLFetch(hStmt);
      if (rc < 0 || rc == SQL_NO_DATA) break;

      final row = <String, dynamic>{};
      for (var i = 1; i <= columnCount.value; i++) {
        final columnType = columnConfig[columnNames[i - 1]];

        if (columnType != null && columnType.isBinary()) {
          // incremental read for binary data
          final collected = <int>[];

          while (true) {
            final status = tryOdbc(
              _sql.SQLGetData(
                hStmt,
                i,
                SQL_C_BINARY,
                buf.cast(),
                defaultBufferSize,
                columnValueLength,
              ),
              handle: hStmt,
              onException: FetchException(),
            );

            if (columnValueLength.value == SQL_NULL_DATA) {
              // null column
              break;
            }

            final returnedBytes = columnValueLength.value;
            final unitsReturned = returnedBytes == SQL_NO_TOTAL
                ? defaultBufferSize
                : (returnedBytes ~/ sizeOf<Uint8>())
                    .clamp(0, defaultBufferSize);

            if (unitsReturned > 0) {
              collected.addAll(buf.cast<Uint8>().asTypedList(unitsReturned));
            }

            if (status == SQL_SUCCESS) {
              break;
            }
          }

          if (collected.isEmpty) {
            row[columnNames[i - 1]] = null;
          } else {
            row[columnNames[i - 1]] = Uint8List.fromList(collected);
          }
        } else {
          final collectedUnits = <int>[];

          // incremental read for wide char (UTF-16) data
          final unitBuf = defaultBufferSize ~/ sizeOf<Uint16>();
          final bufBytes = unitBuf * sizeOf<Uint16>();

          while (true) {
            final status = tryOdbc(
              _sql.SQLGetData(
                hStmt,
                i,
                SQL_WCHAR,
                buf.cast(),
                bufBytes,
                columnValueLength,
              ),
              handle: hStmt,
              onException: FetchException(),
            );

            if (columnValueLength.value == SQL_NULL_DATA) {
              // null column
              break;
            }

            final returnedBytes = columnValueLength.value;
            final maxUnitsInBuffer = unitBuf;

            final unitsReturned = returnedBytes == SQL_NO_TOTAL
                ? maxUnitsInBuffer
                : (returnedBytes ~/ sizeOf<Uint16>())
                    .clamp(0, maxUnitsInBuffer);

            if (unitsReturned > 0) {
              collectedUnits
                  .addAll(buf.cast<Uint16>().asTypedList(unitsReturned));
            }

            if (status == SQL_SUCCESS) {
              break;
            }
          }

          if (collectedUnits.isEmpty) {
            row[columnNames[i - 1]] = null;
          } else {
            collectedUnits.removeWhere((e) => e == 0);
            row[columnNames[i - 1]] = String.fromCharCodes(collectedUnits);
          }
        }
      }

      rows.add(row);
    }

    // free memory
    _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
    calloc
      ..free(buf)
      ..free(columnCount)
      ..free(columnValueLength);

    return rows;
  }
}
