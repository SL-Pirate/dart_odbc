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
part 'execute/get_columns.dart';
part 'execute/get_primary_keys.dart';
part 'execute/get_foreign_keys.dart';

/// DartOdbc class
/// This is the base class that will be used to interact with the ODBC driver.
class DartOdbcBlockingClient implements IDartOdbc {
  /// DartOdbc constructor
  /// This constructor will initialize the ODBC environment and connection.
  /// The [pathToDriver] parameter is the path to the ODBC driver (optional).
  /// if [pathToDriver] is not provided,
  /// the driver will be auto-detected from the ODBC.ini file.
  /// The [dsn] parameter is the name of the DSN to connect to.
  /// If [dsn] is not provided, only [connectWithConnectionString] can be used.
  /// Definitions for these values can be found in the [LibOdbc] class.
  /// Please note that some drivers may not work with some drivers.
  DartOdbcBlockingClient({String? dsn, String? pathToDriver})
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
    bool encrypt = true,
  }) async {
    if (!encrypt && _dsn != null) {
      // When encryption is disabled, use connection string with Encrypt=no
      final connectionString = [
        'DSN=$_dsn',
        'UID=$username',
        'PWD=$password',
        'Encrypt=no',
        'TrustServerCertificate=yes',
      ].join(';');
      await _connectWithConnectionString(connectionString);
    } else {
      await _connect(
        username: username,
        password: password,
      );
    }
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
  Future<List<Map<String, dynamic>>> getColumns({
    required String tableName,
    String? catalog,
    String? schema,
    String? columnName,
  }) async {
    return _getColumns(
      tableName: tableName,
      catalog: catalog,
      schema: schema,
      columnName: columnName,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPrimaryKeys({
    required String tableName,
    String? catalog,
    String? schema,
  }) async {
    return _getPrimaryKeys(
      tableName: tableName,
      catalog: catalog,
      schema: schema,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getForeignKeys({
    String? pkTableName,
    String? fkTableName,
    String? pkCatalog,
    String? pkSchema,
    String? fkCatalog,
    String? fkSchema,
  }) async {
    return _getForeignKeys(
      pkTableName: pkTableName,
      fkTableName: fkTableName,
      pkCatalog: pkCatalog,
      pkSchema: pkSchema,
      fkCatalog: fkCatalog,
      fkSchema: fkSchema,
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

  @Deprecated(
    'tryOdbc exposes low-level synchronous ODBC semantics and will be removed '
    'in a future release. It is not supported in non-blocking mode.',
  )
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
