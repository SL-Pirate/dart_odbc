part of 'cursor.dart';

/// Represents the result of pulling the next item from a [OdbcCursor].
sealed class CursorResult {
  const CursorResult();
  factory CursorResult.item(Map<String, dynamic> value) = CursorItem;
  factory CursorResult.done() = CursorDone;
}

/// Represents an item retrieved from the cursor.
final class CursorItem extends CursorResult {
  /// Creates a [CursorItem] with the given [value].
  const CursorItem(this.value);

  /// The retrieved item.
  final Map<String, dynamic> value;
}

/// Indicates that the cursor has been exhausted.
final class CursorDone extends CursorResult {
  /// Creates a [CursorDone] instance.
  const CursorDone();
}
