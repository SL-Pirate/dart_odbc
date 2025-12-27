part of 'cursor.dart';

/// Represents the result of pulling the next item from a [OdbcCursor].
sealed class CursorResult {
  const CursorResult();
  factory CursorResult.item(Map<String, dynamic> value) = CursorItem;
  factory CursorResult.done() = CursorDone;

  factory CursorResult.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    switch (type) {
      case 'item':
        final value = Map<String, dynamic>.from(map['value'] as Map);
        return CursorItem(value);
      case 'done':
        return const CursorDone();
      default:
        throw ArgumentError('Unknown CursorResult type: $type');
    }
  }

  /// Converts the [CursorResult] to a map for inter-isolate communication.
  Map<String, dynamic> toMap();
}

/// Represents an item retrieved from the cursor.
final class CursorItem extends CursorResult {
  /// Creates a [CursorItem] with the given [value].
  const CursorItem(this.value);

  /// The retrieved item.
  final Map<String, dynamic> value;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'item',
        'value': value,
      };
}

/// Indicates that the cursor has been exhausted.
final class CursorDone extends CursorResult {
  /// Creates a [CursorDone] instance.
  const CursorDone();

  @override
  Map<String, dynamic> toMap() => {'type': 'done'};
}
