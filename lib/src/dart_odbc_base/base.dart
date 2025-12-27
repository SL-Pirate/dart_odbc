import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:dart_odbc/dart_odbc.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

part 'init.dart';
part 'result.dart';
part 'handler.dart';
part 'connection.dart';
part 'execute/execute.dart';
part 'execute/get_tables.dart';

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
    await _connect(
      username: username,
      password: password,
    );
  }

  @override
  Future<String> connectWithConnectionString(String connectionString) {
    return _connectWithConnectionString(connectionString);
  }

  @override
  Future<List<Map<String, dynamic>>> getTables({
    String? tableName,
    String? catalog,
    String? schema,
    String? tableType,
  }) async {
    return _getTables(
      tableName: tableName,
      catalog: catalog,
      schema: schema,
      tableType: tableType,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> execute(
    String query, {
    List<dynamic>? params,
  }) async {
    return _execute(
      query,
      params: params,
    );
  }

  @override
  Future<void> disconnect() async {
    await _disconnect();
  }

  @override
  int tryOdbc(
    int status, {
    SQLHANDLE? handle,
    int operationType = SQL_HANDLE_STMT,
    ODBCException? onException,
    void Function()? beforeThrow,
  }) {
    return _tryOdbc(
      status,
      handle: handle,
      operationType: operationType,
      onException: onException,
      beforeThrow: beforeThrow,
    );
  }

  @override
  Future<OdbcCursor> executeCursor(String query, {List<dynamic>? params}) {
    return _executeCursor(
      query,
      params: params,
    );
  }
}
