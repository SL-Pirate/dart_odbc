import 'dart:ffi';
import 'package:dart_odbc/src/conversions.dart';
import 'package:dart_odbc/src/exceptions.dart';
import 'package:dart_odbc/src/ffi_libodbc.dart';
import 'package:ffi/ffi.dart';

/// DartOdbc class
/// This is the base class that will be used to interact with the ODBC driver.
class DartOdbc {
  /// DartOdbc constructor
  /// This constructor will initialize the ODBC environment and connection.
  /// The [pathToDriver] parameter is the path to the ODBC driver.
  /// Optionally the ODBC version can be specified using the [version] parameter
  /// Definitions for these values can be found in the [LibODBC] class.
  /// Please note that some drivers may not work with some drivers.
  DartOdbc(String pathToDriver, {int? version})
      : _sql = LibODBC(DynamicLibrary.open(pathToDriver)) {
    final sqlOvOdbc = calloc.allocate<SQLULEN>(sizeOf<SQLULEN>())
      ..value = version ?? 0;
    final sqlNullHandle = calloc.allocate<Int>(sizeOf<Int>())
      ..value = SQL_NULL_HANDLE;
    final pHEnv = calloc.allocate<SQLHANDLE>(sizeOf<SQLHANDLE>());
    tryOdbc(
      _sql.SQLAllocHandle(
        SQL_HANDLE_ENV,
        Pointer.fromAddress(sqlNullHandle.address),
        pHEnv,
      ),
      operationType: SQL_HANDLE_ENV,
      handle: pHEnv.value,
      onException: HandleException(),
    );
    _hEnv = pHEnv.value;

    if (version != null) {
      tryOdbc(
        _sql.SQLSetEnvAttr(
          _hEnv,
          SQL_ATTR_ODBC_VERSION,
          Pointer.fromAddress(sqlOvOdbc.address),
          0,
        ),
        handle: _hEnv,
        operationType: SQL_HANDLE_ENV,
        onException: EnvironmentAllocationException(),
      );
    }
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
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_DBC, _hEnv, pHConn),
      handle: _hEnv,
      operationType: SQL_HANDLE_DBC,
      onException: HandleException(),
    );
    _hConn = pHConn.value;
    final cDsn = dsn.toNativeUtf16().cast<UnsignedShort>();
    final cUsername = username.toNativeUtf16().cast<UnsignedShort>();
    final cPassword = password.toNativeUtf16().cast<UnsignedShort>();
    tryOdbc(
      _sql.SQLConnectW(
        _hConn,
        cDsn,
        dsn.length,
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
  List<Map<String, dynamic>> execute(
    String query, {
    List<dynamic>? params,
  }) {
    final pHStmt = calloc.allocate<SQLHSTMT>(sizeOf<SQLHSTMT>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
    );
    final hStmt = pHStmt.value;
    final pointers = <ToPointerDto<dynamic>>[];
    final cQuery = query.toNativeUtf16();

    // binding sanitized params
    if (params != null) {
      tryOdbc(
        _sql.SQLPrepareW(hStmt, cQuery.cast(), cQuery.length),
        handle: hStmt,
        onException: QueryException(),
      );

      /// These should be freed at the end of the query

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

    final result = _getResult(hStmt, cQuery.cast());

    // free memory
    for (final ptr in pointers) {
      ptr.free();
    }
    calloc.free(cQuery);

    return result;
  }

  /// Function to disconnect from the database
  void disconnect() {
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
  void tryOdbc(
    int status, {
    SQLHANDLE? handle,
    int operationType = SQL_HANDLE_STMT,
    ODBCException? onException,
  }) {
    onException ??= ODBCException('EDBOC error');
    onException.code = status;
    if (status == SQL_ERROR) {
      if (handle != null) {
        final nativeErr = calloc.allocate<Int>(sizeOf<Int>())..value = status;
        final message = '1' * 10000;
        final msg = message.toNativeUtf16();
        final pStatus = calloc.allocate<UnsignedShort>(sizeOf<UnsignedShort>())
          ..value = status;
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

        onException.message = msg.toDartString();

        // free memory
        calloc
          ..free(nativeErr)
          ..free(msg)
          ..free(pStatus);
      }

      throw onException;
    }
  }

  List<Map<String, dynamic>> _getResult(
    SQLHSTMT hStmt,
    Pointer<Uint16> cQuery,
  ) {
    final columnCount = calloc.allocate<SQLSMALLINT>(sizeOf<SQLSMALLINT>());
    tryOdbc(
      _sql.SQLNumResultCols(hStmt, columnCount),
      handle: hStmt,
      onException: FetchException(),
    );

    final columnNames = <String>[];
    for (var i = 1; i <= columnCount.value; i++) {
      final columnNameLength =
          calloc.allocate<SQLSMALLINT>(sizeOf<SQLSMALLINT>());
      final columnName = calloc.allocate<Uint16>(sizeOf<Uint16>() * 256);
      tryOdbc(
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
        ),
        handle: hStmt,
        onException: FetchException(),
      );
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
        tryOdbc(
          _sql.SQLGetData(
            hStmt,
            i,
            SQL_C_WCHAR,
            columnValue.cast(),
            256,
            columnValueLength,
          ),
          handle: hStmt,
          onException: FetchException(),
        );
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

    // return _removeEhitespaceUnicodes(rows);
    return rows;
  }

  static final _unicodeWhitespaceRegExp = RegExp(
    r'[\u0000\u0020\u00A0\u180E\u200A\u200B\u202F\u205F\u3000\uFEFF\u2800\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u2400]',
  );

  static String _removeUnicodeWhitespaces(String input) {
    return input.replaceAll(_unicodeWhitespaceRegExp, '');
  }

  /// On some platforms with some drivers, the ODBC driver may return
  /// whitespace characters as unicode characters. This function will remove
  /// these unicode whitespace characters from the result set.
  static List<Map<String, dynamic>> removeWhitespaceUnicodes(
    List<Map<String, dynamic>> result,
  ) {
    return result.map((record) {
      final sanitizedDict = <String, String>{};
      record.forEach((key, value) {
        // Trim all whitespace from keys and values using a regular expression
        final sanitizedKey = key.replaceAll(RegExp(r'\s+'), '');
        final cleanedKey = _removeUnicodeWhitespaces(sanitizedKey);
        final sanitizedValue =
            value.toString().replaceAll(RegExp(r'[\s\u00A0]+'), '');
        final cleanedValue = _removeUnicodeWhitespaces(sanitizedValue);

        sanitizedDict[cleanedKey] = cleanedValue;
      });
      return sanitizedDict;
    }).toList();
  }
}
