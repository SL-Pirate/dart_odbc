import 'dart:ffi';
import 'dart:typed_data';
import 'package:dart_odbc/dart_odbc.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

/// DartOdbc class
/// This is the base class that will be used to interact with the ODBC driver.
class DartOdbc implements IDartOdbc {
  /// DartOdbc constructor
  /// This constructor will initialize the ODBC environment and connection.
  /// The [pathToDriver] parameter is the path to the ODBC driver (optional).
  /// if [pathToDriver] is not provided,
  /// the driver will be auto-detected from the ODBC.ini file.
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
  final Logger _log = Logger('DartOdbc');
  SQLHANDLE _hEnv = nullptr;
  SQLHDBC _hConn = nullptr;

  void _initialize() {
    final pHEnv = calloc.allocate<SQLHANDLE>(sizeOf<SQLHANDLE>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_ENV, nullptr, pHEnv),
      operationType: SQL_HANDLE_ENV,
      handle: pHEnv.value,
      onException: HandleException(),
    );
    _hEnv = pHEnv.value;

    final pVer = calloc.allocate<SQLINTEGER>(sizeOf<SQLINTEGER>())
      ..value = SQL_OV_ODBC3;

    tryOdbc(
      _sql.SQLSetEnvAttr(
        _hEnv,
        SQL_ATTR_ODBC_VERSION,
        Pointer.fromAddress(SQL_OV_ODBC3),
        0,
      ),
      handle: _hEnv,
      operationType: SQL_HANDLE_ENV,
      onException: HandleException(),
    );

    calloc
      ..free(pHEnv)
      ..free(pVer);
  }

  LibOdbc get _sql {
    if (__sql != null) {
      return __sql!;
    }

    throw ODBCException('ODBC driver not found');
  }

  @override
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
        SQL_NTS,
        cUsername,
        SQL_NTS,
        cPassword,
        SQL_NTS,
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

  @override
  Future<String> connectWithConnectionString(String connectionString) async {
    final pHConn = calloc.allocate<SQLHDBC>(sizeOf<SQLHDBC>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_DBC, _hEnv, pHConn),
      handle: _hEnv,
      operationType: SQL_HANDLE_DBC,
      onException: HandleException(),
    );
    _hConn = pHConn.value;

    final cConnectionString = connectionString.toNativeUtf16();
    const outChars = 1024;
    final outConnectionString = calloc<Uint16>(outChars);
    final outConnectionStringLen = calloc<Short>();

    _sql.SQLDriverConnectW(
      _hConn,
      nullptr,
      cConnectionString.cast(),
      SQL_NTS,
      outConnectionString.cast(),
      outChars,
      outConnectionStringLen,
      SQL_DRIVER_NOPROMPT,
    );

    final completedConnectionString = outConnectionString
        .cast<Utf16>()
        .toDartString(length: outConnectionStringLen.value);

    calloc
      ..free(pHConn)
      ..free(cConnectionString)
      ..free(outConnectionString)
      ..free(outConnectionStringLen);

    return completedConnectionString;
  }

  @override
  Future<List<Map<String, dynamic>>> getTables({
    String? tableName,
    String? catalog,
    String? schema,
    String? tableType,
  }) async {
    if (_hEnv == nullptr || _hConn == nullptr) {
      throw ODBCException('Not connected to the database');
    }

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
    final resetStatus = _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);

    if (![SQL_SUCCESS, SQL_SUCCESS_WITH_INFO].contains(resetStatus)) {
      _log.warning(
        'Failed to reset parameters after fetching tables. '
        'Status code: $resetStatus',
      );
    }

    calloc
      ..free(pHStmt)
      ..free(cCatalog)
      ..free(cSchema)
      ..free(cTableName)
      ..free(cTableType);

    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> execute(
    String query, {
    List<dynamic>? params,
    Map<String, ColumnType> columnConfig = const {},
  }) async {
    if (_hEnv == nullptr || _hConn == nullptr) {
      throw ODBCException('Not connected to the database');
    }

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

    final resetStatus = _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
    if (![SQL_SUCCESS, SQL_SUCCESS_WITH_INFO].contains(resetStatus)) {
      _log.warning(
        'Failed to reset parameters after query execution. '
        'Status code: $resetStatus',
      );
    }

    // free memory
    for (final ptr in pointers) {
      ptr.free();
    }
    calloc
      ..free(cQuery)
      ..free(pHStmt);

    return result;
  }

  @override
  Future<void> disconnect() async {
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

  @override
  int tryOdbc(
    int status, {
    SQLHANDLE? handle,
    int operationType = SQL_HANDLE_STMT,
    ODBCException? onException,
  }) {
    if (status >= 0) {
      return status;
    }

    onException ??= ODBCException('ODBC error');
    onException.code = status;

    if (handle == null || handle == nullptr) {
      throw onException;
    }

    final sqlState = calloc<Uint16>(6);
    final nativeErr = calloc<Int>();
    final msg = calloc<Uint16>(1024);
    final msgLen = calloc<Short>();

    try {
      final diagStatus = _sql.SQLGetDiagRecW(
        operationType,
        handle,
        1,
        sqlState.cast(),
        nativeErr,
        msg.cast(),
        1024,
        msgLen,
      );

      if (diagStatus >= 0) {
        onException
          ..sqlState = sqlState.cast<Utf16>().toDartString()
          ..code = nativeErr.value
          ..message = msg.cast<Utf16>().toDartString(length: msgLen.value);
      }
    } on Exception {
      _log.warning('Failed to retrieve ODBC diagnostics.');
    } finally {
      calloc
        ..free(sqlState)
        ..free(nativeErr)
        ..free(msg)
        ..free(msgLen);
    }

    throw onException;
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
    calloc
      ..free(buf)
      ..free(columnCount)
      ..free(columnValueLength);

    return rows;
  }
}
