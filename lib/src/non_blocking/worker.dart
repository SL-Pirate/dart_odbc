import 'dart:async';

import 'package:dart_odbc/dart_odbc.dart';
import 'package:dart_odbc/src/worker/client.dart';
import 'package:dart_odbc/src/worker/message.dart';
import 'package:logging/logging.dart';

///
class OdbcIsolateClient extends IsolateClient {
  ///
  OdbcIsolateClient({this.dsn, this.pathToDriver});

  ///
  final String? dsn;

  ///
  final String? pathToDriver;

  /// THIS IS THE ONLY SHARED STATE INSIDE THE ISOLATE
  /// DO NOT ACCESS THIS FROM OUTSIDE THE ISOLATE
  IDartOdbc? __odbc;

  /// Logger for logging errors and information
  /// Created per memory space
  /// So this is safe to be used
  /// As long as it's accessed using [_log]
  Logger? __log;

  @override
  Future<void> initialize() async {
    await super.initialize();

    final result = await bootstrapRequest(
      RequestPayload(
        OdbcCommand._create.name,
        {
          'dsn': dsn,
          'pathToDriver': pathToDriver,
        },
      ),
    );

    if (result is ErrorPayload) {
      _log.severe(
        'Error initializing ODBC isolate: ${result.data}',
        ODBCException(result.data.toString()),
        result.stackTrace,
      );
      throw ODBCException('Error initializing ODBC isolate: ${result.data}');
    }
  }

  @override
  Future<ResponsePayload> handleMessage(RequestPayload message) async {
    // THIS IS INSIDE THE ISOLATE
    // MUST NOT ACCESS ANY SHARED STATE HERE UNLESS YOU EXPLICITLY
    // CREATE IT INSIDE THE ISOLATE

    final command = OdbcCommand.values.byName(message.command);

    switch (command) {
      case OdbcCommand._create:
        if (__odbc != null) {
          await __odbc!.disconnect();
        }
        final dsn = message.arguments['dsn'] as String?;
        final pathToDriver = message.arguments['pathToDriver'] as String?;
        __odbc = DartOdbc.blocking(dsn: dsn, pathToDriver: pathToDriver);
        return ResponsePayload(null);
      case OdbcCommand.connect:
        await _odbc.connect(
          username: message.arguments['username'] as String,
          password: message.arguments['password'] as String,
        );
        return ResponsePayload(null);
      case OdbcCommand.connectWithConnectionString:
        final connectionString =
            message.arguments['connectionString'] as String;
        final result = await _odbc.connectWithConnectionString(
          connectionString,
        );
        return ResponsePayload(result);
      case OdbcCommand.getTables:
        final result = await _odbc.getTables(
          tableName: message.arguments['tableName'] as String?,
          catalog: message.arguments['catalog'] as String?,
          schema: message.arguments['schema'] as String?,
          tableType: message.arguments['tableType'] as String?,
        );
        return ResponsePayload(result);
      case OdbcCommand.execute:
        final result = await _odbc.execute(
          message.arguments['query'] as String,
          params: message.arguments['params'] as List<dynamic>?,
        );
        return ResponsePayload(result);
      case OdbcCommand.executeCursor:
        throw UnsupportedError(
          'Cursors are not supported in non-blocking mode.',
        );
      case OdbcCommand.disconnect:
        if (__odbc != null) {
          await __odbc!.disconnect();
        }
        return ResponsePayload(null);
    }
  }

  @override
  Future<void> close() async {
    if (!isOpen) return;

    await request(RequestPayload(OdbcCommand.disconnect.name));
    await super.close();
  }

  IDartOdbc get _odbc {
    if (__odbc == null) {
      throw StateError('ODBC instance is not initialized.');
    }

    return __odbc!;
  }

  Logger get _log {
    return __log ??= Logger('OdbcIsolateClient');
  }
}

///
enum OdbcCommand {
  /// To be used internally to create the ODBC instance inside the isolate
  _create,

  ///
  connect,

  ///
  connectWithConnectionString,

  ///
  getTables,

  ///
  execute,

  ///
  executeCursor,

  ///
  disconnect,
}
