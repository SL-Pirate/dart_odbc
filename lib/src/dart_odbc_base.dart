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
    final pHEnv = calloc<SQLHANDLE>();
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_ENV, nullptr, pHEnv),
      operationType: SQL_HANDLE_ENV,
      handle: pHEnv.value,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHEnv);
      },
    );
    _hEnv = pHEnv.value;

    final pVer = calloc<SQLINTEGER>()..value = SQL_OV_ODBC3;

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
      beforeThrow: () {
        calloc
          ..free(pHEnv)
          ..free(pVer);
      },
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
    final pHConn = calloc<SQLHDBC>();
    tryOdbc(
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

  @override
  Future<String> connectWithConnectionString(String connectionString) async {
    final pHConn = calloc<SQLHDBC>();
    tryOdbc(
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

    tryOdbc(
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

    final pHStmt = calloc<SQLHSTMT>();
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHStmt);
      },
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
      beforeThrow: () {
        calloc
          ..free(pHStmt)
          ..free(cCatalog)
          ..free(cSchema)
          ..free(cTableName)
          ..free(cTableType);
      },
    );

    final result = _getResult(hStmt, {});

    // Clean up
    _freeSqlStmtHandle(hStmt);

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
    final pHStmt = calloc<SQLHSTMT>();
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
      beforeThrow: () {
        calloc.free(pHStmt);
      },
    );
    final hStmt = pHStmt.value;
    final cQuery = query.toNativeUtf16();

    // binding sanitized params
    if (params != null) {
      tryOdbc(
        _sql.SQLPrepareW(hStmt, cQuery.cast(), SQL_NTS),
        handle: hStmt,
        onException: QueryException(),
        beforeThrow: () {
          calloc
            ..free(cQuery)
            ..free(pHStmt);
          _freeSqlStmtHandle(hStmt);
        },
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
          beforeThrow: () {
            calloc
              ..free(cQuery)
              ..free(pHStmt);
            cParam.free();
            _freeSqlStmtHandle(hStmt);

            for (final p in pointers) {
              p.free();
            }
          },
        );
        pointers.add(cParam);
      }
    }

    if (params == null) {
      tryOdbc(
        _sql.SQLExecDirectW(hStmt, cQuery.cast(), query.length),
        handle: hStmt,
        beforeThrow: () {
          calloc
            ..free(cQuery)
            ..free(pHStmt);
          _freeSqlStmtHandle(hStmt);
        },
      );
    } else {
      tryOdbc(
        _sql.SQLExecute(hStmt),
        handle: hStmt,
        beforeThrow: () {
          calloc
            ..free(cQuery)
            ..free(pHStmt);
          _freeSqlStmtHandle(hStmt);
        },
      );
    }

    final result = _getResult(hStmt, columnConfig);

    _freeSqlStmtHandle(hStmt);

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

  List<Map<String, dynamic>> _getResult(
    SQLHSTMT hStmt,
    Map<String, ColumnType> columnConfig,
  ) {
    final pColumnCount = calloc<SQLSMALLINT>();
    tryOdbc(
      _sql.SQLNumResultCols(hStmt, pColumnCount),
      handle: hStmt,
      onException: FetchException(),
      beforeThrow: () {
        calloc.free(pColumnCount);
      },
    );

    final columnNameCharSize = defaultBufferSize ~/ sizeOf<Uint16>();
    // allocating memory for column names
    // outside the loop to reduce overhead in memory allocation
    final pColumnNameLength = calloc<SQLSMALLINT>();
    final pColumnName = calloc<Uint16>(columnNameCharSize);
    final columnNames = <String>[];

    for (var i = 1; i <= pColumnCount.value; i++) {
      tryOdbc(
        _sql.SQLDescribeColW(
          hStmt,
          i,
          pColumnName.cast(),
          columnNameCharSize,
          pColumnNameLength,
          nullptr,
          nullptr,
          nullptr,
          nullptr,
        ),
        handle: hStmt,
        onException: FetchException(),
        beforeThrow: () {
          calloc
            ..free(pColumnName)
            ..free(pColumnNameLength)
            ..free(pColumnCount);
        },
      );
      final columnName = pColumnName
          .cast<Utf16>()
          .toDartString(length: pColumnNameLength.value);
      columnNames.add(columnName);
    }

    // free memory
    calloc
      ..free(pColumnName)
      ..free(pColumnNameLength);

    final rows = <Map<String, dynamic>>[];

    // keeping outside the loop to reduce overhead in memory allocation
    final pColumnValueLength = calloc<SQLLEN>();
    final buf = calloc.allocate(defaultBufferSize);

    while (true) {
      final rc = _sql.SQLFetch(hStmt);
      if (rc < 0 || rc == SQL_NO_DATA) break;

      final row = <String, dynamic>{};
      for (var i = 1; i <= pColumnCount.value; i++) {
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
                pColumnValueLength,
              ),
              handle: hStmt,
              onException: FetchException(),
              beforeThrow: () {
                calloc
                  ..free(buf)
                  ..free(pColumnValueLength)
                  ..free(pColumnCount);
              },
            );

            if (pColumnValueLength.value == SQL_NULL_DATA) {
              // null column
              break;
            }

            final returnedBytes = pColumnValueLength.value;
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
                pColumnValueLength,
              ),
              handle: hStmt,
              onException: FetchException(),
              beforeThrow: () {
                calloc
                  ..free(buf)
                  ..free(pColumnValueLength)
                  ..free(pColumnCount);
              },
            );

            if (pColumnValueLength.value == SQL_NULL_DATA) {
              // null column
              break;
            }

            final returnedBytes = pColumnValueLength.value;
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
      ..free(pColumnCount)
      ..free(pColumnValueLength);

    return rows;
  }

  void _freeSqlStmtHandle(SQLHSTMT hStmt) {
    final resetStatus = _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);

    if (![SQL_SUCCESS, SQL_SUCCESS_WITH_INFO].contains(resetStatus)) {
      _log.warning(
        'Failed to reset parameters after fetching tables. '
        'Status code: $resetStatus',
      );
    }
  }
}
