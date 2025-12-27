import 'package:dart_odbc/dart_odbc.dart';
import 'package:dart_odbc/src/non_blocking/worker.dart';
import 'package:dart_odbc/src/worker/client.dart';
import 'package:dart_odbc/src/worker/message.dart';
import 'package:logging/logging.dart';

///
class DartOdbcNonBlocking implements IDartOdbc {
  ///
  DartOdbcNonBlocking({this.dsn, this.pathToDriver});

  ///
  final String? dsn;

  ///
  final String? pathToDriver;

  final Logger _log = Logger('DartOdbcNonBlocking');

  IsolateClient? _isolateClient;

  @override
  Future<void> connect({
    required String username,
    required String password,
  }) async {
    if (_isolateClient != null) {
      await _isolateClient!.close();
    }

    _isolateClient = OdbcIsolateClient(
      dsn: dsn,
      pathToDriver: pathToDriver,
    );

    final result = await _isolateClient!.request(
      RequestPayload(
        OdbcCommand.connect.name,
        {
          'username': username,
          'password': password,
        },
      ),
    );

    if (result is ErrorPayload) {
      _logStackTrace(result.stackTrace);
      throw ODBCException('Error connecting: ${result.data}');
    }
  }

  @override
  Future<String> connectWithConnectionString(String connectionString) async {
    if (_isolateClient != null) {
      await _isolateClient!.close();
    }

    _isolateClient = OdbcIsolateClient(
      dsn: dsn,
      pathToDriver: pathToDriver,
    );

    final response = await _isolateClient!.request(
      RequestPayload(
        OdbcCommand.connectWithConnectionString.name,
        {'connectionString': connectionString},
      ),
    );

    if (response is ErrorPayload) {
      _logStackTrace(response.stackTrace);
      throw ODBCException(
        'Error connecting with connection string: ${response.data}',
      );
    }

    return (response as ResponsePayload).data as String;
  }

  @override
  Future<void> disconnect() async {
    if (_isolateClient == null) return;

    final response = await _isolateClient!.request(
      RequestPayload(
        OdbcCommand.disconnect.name,
      ),
    );

    if (response is ErrorPayload) {
      _logStackTrace(response.stackTrace);
      throw ODBCException('Error disconnecting: ${response.data}');
    }

    await _isolateClient!.close();
    _isolateClient = null;
  }

  @override
  Future<List<Map<String, dynamic>>> execute(
    String query, {
    List<dynamic>? params,
  }) async {
    if (_isolateClient == null) {
      throw ODBCException('Not connected to any database.');
    }

    final response = await _isolateClient!.request(
      RequestPayload(
        OdbcCommand.execute.name,
        {
          'query': query,
          'params': params,
        },
      ),
    );

    if (response is ErrorPayload) {
      _logStackTrace(response.stackTrace);
      throw ODBCException('Error executing query: ${response.data}');
    }

    return _getQueryDataFromResponse(response);
  }

  @override
  Future<OdbcCursor> executeCursor(String query, {List<dynamic>? params}) {
    throw UnsupportedError('Cursors are not supported in non-blocking mode.');
  }

  @override
  Future<List<Map<String, dynamic>>> getTables({
    String? tableName,
    String? catalog,
    String? schema,
    String? tableType,
  }) async {
    if (_isolateClient == null) {
      throw ODBCException('Not connected to any database.');
    }

    final response = await _isolateClient!.request(
      RequestPayload(
        OdbcCommand.getTables.name,
        {
          'tableName': tableName,
          'catalog': catalog,
          'schema': schema,
          'tableType': tableType,
        },
      ),
    );

    if (response is ErrorPayload) {
      _logStackTrace(response.stackTrace);
      throw ODBCException('Error fetching tables: ${response.data}');
    }

    return _getQueryDataFromResponse(response);
  }

  @override
  int tryOdbc(
    int status, {
    SQLHANDLE? handle,
    int operationType = SQL_HANDLE_STMT,
    void Function()? beforeThrow,
    ODBCException? onException,
  }) {
    throw UnsupportedError('tryOdbc is not supported in non-blocking mode.');
  }

  void _logStackTrace(StackTrace? stackTrace) {
    if (stackTrace != null) {
      _log.severe(null, null, stackTrace);
    }
  }

  List<Map<String, dynamic>> _getQueryDataFromResponse(
    WorkerMessagePayload response,
  ) {
    if (response is! ResponsePayload) {
      throw ODBCException('Invalid response payload type.');
    }

    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
