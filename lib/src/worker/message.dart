/// Defines messages exchanged between the main isolate and worker isolates.
class WorkerMessage {
  /// Creates a new [WorkerMessage].
  WorkerMessage({required this.id, required this.type, required this.payload});

  /// Creates a new [WorkerMessage] from a map.
  factory WorkerMessage.fromMap(Map<String, dynamic> map, {int? id}) {
    final messageType = WorkerMessageType.values.byName(map['type'] as String);
    return WorkerMessage(
      id: id ?? map['id'] as int? ?? 0,
      type: messageType,
      payload: WorkerMessagePayload.fromMap(
        messageType,
        Map<String, dynamic>.from(map['payload'] as Map),
      ),
    );
  }

  /// The ID of the message.
  final int id;

  /// Defines the type of the message.
  final WorkerMessageType type;

  /// Defines the payload of the message.
  final WorkerMessagePayload payload;

  /// Converts the [WorkerMessage] to a map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'payload': payload.toMap(),
    };
  }
}

/// Defines the payload of a [WorkerMessage].
// ignore: one_member_abstracts
abstract class WorkerMessagePayload {
  /// Creates a new [WorkerMessagePayload].
  WorkerMessagePayload();

  /// Creates a [WorkerMessagePayload] from a map.
  factory WorkerMessagePayload.fromMap(
    WorkerMessageType type,
    Map<String, dynamic> map,
  ) {
    switch (type) {
      case WorkerMessageType.request:
        return RequestPayload.fromMap(map);
      case WorkerMessageType.response:
        return ResponsePayload(map['data']);
      case WorkerMessageType.error:
        return ErrorPayload(
          map['data'],
          map['stackTrace'] != null
              ? StackTrace.fromString(map['stackTrace'] as String)
              : null,
        );
    }
  }

  /// Converts the [WorkerMessagePayload] to a map.
  Map<String, dynamic> toMap();
}

/// Defines a standard message payload.
class RequestPayload extends WorkerMessagePayload {
  /// Creates a new [RequestPayload].
  RequestPayload(this.command, [this.arguments = const {}]);

  /// Creates a [RequestPayload] from a map.
  RequestPayload.fromMap(Map<String, dynamic> map)
      : command = map['command'] as String,
        arguments = map['arguments'] != null
            ? Map<String, dynamic>.from(map['arguments'] as Map)
            : const {};

  /// The command to execute.
  final String command;

  /// The arguments for the command.
  final Map<String, dynamic> arguments;

  @override
  Map<String, dynamic> toMap() {
    return {
      'command': command,
      'arguments': arguments,
    };
  }
}

/// Defines a response message payload.
class ResponsePayload extends WorkerMessagePayload {
  /// Creates a new [ResponsePayload].
  ResponsePayload([this.data]);

  /// The data of the response.
  final dynamic data;

  @override
  Map<String, dynamic> toMap() {
    return {
      'data': data,
    };
  }
}

/// Defines an error message payload.
class ErrorPayload extends WorkerMessagePayload {
  /// Creates a new [ErrorPayload].
  ErrorPayload(this.data, this.stackTrace);

  /// The data of the error.
  final dynamic data;

  /// The stack trace of the error.
  final StackTrace? stackTrace;

  @override
  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'stackTrace': stackTrace?.toString(),
    };
  }
}

/// Defines the type of a [WorkerMessage].
enum WorkerMessageType {
  /// A standard request message
  request,

  /// A standard response message
  response,

  /// An error message
  error,
}
