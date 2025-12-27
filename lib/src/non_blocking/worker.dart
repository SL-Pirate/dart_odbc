import 'dart:async';

import 'package:dart_odbc/dart_odbc.dart';
import 'package:dart_odbc/src/worker/client.dart';
import 'package:dart_odbc/src/worker/message.dart';
import 'package:logging/logging.dart';

/// RPC style ODBC Isolate Client used for non-blocking ODBC operations.
/// Note that each instance of this class 
/// manages its own isolate and ODBC connection.
class OdbcIsolateClient extends IsolateClient {
  /// Constructor for [OdbcIsolateClient].
  OdbcIsolateClient({this.dsn, this.pathToDriver});

  /// Shared. But strings are copiable and immutable
  final String? dsn;

  /// Shared. But strings are copiable and immutable
  final String? pathToDriver;

  /// THIS IS THE ONLY SHARED STATE INSIDE THE ISOLATE
  /// DO NOT ACCESS THIS FROM OUTSIDE THE ISOLATE
  IDartOdbc? __odbc;

  /// Logger for logging errors and information
  /// Created per memory space
  /// So this is safe to be used
  /// As long as it's accessed using [_log]
  Logger? __log;

  /// Cursors managed inside the isolate
  // content will only be available inside the isolate
  final Map<int, OdbcCursor> _cursors = {};

  /// Next cursor ID
  int _nextCursorId = 0;

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
          await _clearCursors();
          await __odbc!.disconnect();
        }
        final dsn = message.arguments['dsn'] as String?;
        final pathToDriver = message.arguments['pathToDriver'] as String?;
        __odbc = DartOdbc.blocking(dsn: dsn, pathToDriver: pathToDriver);
        return ResponsePayload();
      case OdbcCommand.connect:
        await _odbc.connect(
          username: message.arguments['username'] as String,
          password: message.arguments['password'] as String,
        );
        return ResponsePayload();
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
        return _executeCursor(
          message.arguments['query'] as String,
          message.arguments['params'] as List<dynamic>?,
        );
      case OdbcCommand.cursorNext:
        final cursorId = message.arguments['cursorId'] as int;
        final cursor = _cursors[cursorId];
        if (cursor == null) {
          throw StateError('Cursor with ID $cursorId not found.');
        }
        final result = await cursor.next();
        return ResponsePayload(result.toMap());
      case OdbcCommand.cursorClose:
        final cursorId = message.arguments['cursorId'] as int;
        final cursor = _cursors.remove(cursorId);
        if (cursor == null) {
          _log.warning('Cursor with ID $cursorId not found for closing.');
        } else {
          await cursor.close();
        }
        return ResponsePayload();
      case OdbcCommand.disconnect:
        if (__odbc != null) {
          await _clearCursors();
          await __odbc!.disconnect();
        }
        return ResponsePayload();
    }
  }

  @override
  Future<void> close() async {
    if (!isOpen) return;

    await request(RequestPayload(OdbcCommand.disconnect.name));
    await super.close();
  }

  /// To be only used inside the isolate
  Future<ResponsePayload> _executeCursor(
    String query,
    List<dynamic>? params,
  ) async {
    final cursor = await _odbc.executeCursor(query, params: params);
    final cursorId = _nextCursorId++;
    _cursors[cursorId] = cursor;

    return ResponsePayload(cursorId);
  }

  /// To be only used inside the isolate
  Future<void> _clearCursors() async {
    for (final cursor in _cursors.values) {
      await cursor.close();
    }
    _cursors.clear();
    _nextCursorId = 0;
  }

  /// To be only used inside the isolate
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

  /// Next command for cursor
  cursorNext,

  /// Close command for cursor
  cursorClose,

  /// Connect command
  connect,

  /// Connect with connection string command
  connectWithConnectionString,

  /// Get tables command
  getTables,

  /// Execute query command
  execute,

  /// Execute query with cursor command
  executeCursor,

  /// Disconnect command
  disconnect,
}
