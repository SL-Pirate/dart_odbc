import 'dart:async';
import 'dart:isolate';

import 'package:dart_odbc/src/worker/message.dart';

/// Client for communicating with a worker isolate.
abstract class IsolateClient {
  /// Creates a new [IsolateClient].
  IsolateClient() {
    _ready = _init();
  }

  late final Future<void> _ready;
  late final Isolate _isolate;
  late final SendPort _sendPort;
  late final ReceivePort _receivePort;
  bool _isClosed = false;

  int _nextId = 0;
  final Map<int, Completer<WorkerMessagePayload>> _pending = {};

  /// Sends a request to the worker isolate and returns the response.
  Future<WorkerMessagePayload> request(
    RequestPayload payload,
  ) async {
    if (_isClosed) {
      throw StateError('IsolateClient is closed.');
    }

    await _ready;

    final id = _nextId++;
    final completer = Completer<WorkerMessagePayload>();
    _pending[id] = completer;

    _sendPort.send(
      WorkerMessage(
        id: id,
        type: WorkerMessageType.request,
        payload: payload,
      ).toMap(),
    );

    return completer.future;
  }

  /// Handles incoming messages from the worker isolate.
  FutureOr<ResponsePayload> handleeMessage(RequestPayload message);

  /// Whether the client is open.
  bool get isOpen => !_isClosed;

  /// Closes the worker isolate.
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    await _ready;

    for (final completer in _pending.values) {
      completer.completeError(
        Exception('IsolateClient closed before response was received.'),
      );
    }
    _pending.clear();

    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  Future<void> _init() async {
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (dynamic initialMessage) {
      final commandPort = initialMessage as SendPort;
      connection.complete(
        (
          ReceivePort.fromRawReceivePort(initPort),
          commandPort,
        ),
      );
    };
    // Spawn the isolate.
    try {
      _isolate = await Isolate.spawn(_workerMain, initPort.sendPort);
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;
    _receivePort = receivePort;
    _sendPort = sendPort;

    _receivePort.listen(_handleMessage);
  }

  void _handleMessage(dynamic msg) {
    final message = WorkerMessage.fromMap(Map.from(msg as Map));

    final completer = _pending.remove(message.id);
    if (completer == null) return;

    if (message.type == WorkerMessageType.response) {
      completer.complete(message.payload);
    } else if (message.type == WorkerMessageType.error) {
      final errMsg = message.payload as ErrorPayload;

      completer.completeError(
        Exception(errMsg.data),
        errMsg.stackTrace,
      );
    }
  }

  Future<void> _workerMain(SendPort mainSendPort) async {
    final port = ReceivePort();
    mainSendPort.send(port.sendPort);

    await for (final message in port) {
      final msg = WorkerMessage.fromMap(Map.from(message as Map));

      try {
        final result = await handleeMessage(msg.payload as RequestPayload);

        mainSendPort.send(
          WorkerMessage(
            id: msg.id,
            type: WorkerMessageType.response,
            payload: result,
          ).toMap(),
        );
      } on Object catch (e, st) {
        mainSendPort.send(
          WorkerMessage(
            id: msg.id,
            type: WorkerMessageType.error,
            payload: ErrorPayload(e.toString(), st),
          ).toMap(),
        );
      }
    }
  }
}
