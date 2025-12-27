part 'cursor_result.dart';

/// Represents a cursor that can pull items one at a time.
///
/// Usage example:
/// ```dart
/// try {
///   while (true) {
///     final CursorResult result = await cursor.next();
///       if (result.isDone) {
///         break;
///     }
///     final Map<String, dynamic> row = result.value!;
///     // Process row
///   }
/// } finally {
///   await cursor.close();
/// }
/// ```
abstract interface class OdbcCursor {
  /// Pulls the next item.
  ///
  /// - Returns `CursorResult.item(value)` when data is available
  /// - Returns `CursorResult.done()` when exhausted
  /// - Throws on fatal errors
  Future<CursorResult> next();

  /// Cancels the cursor and releases resources.
  ///
  /// Idempotent: safe to call multiple times.
  Future<void> close();
}
