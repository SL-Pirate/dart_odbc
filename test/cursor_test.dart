import 'package:dart_odbc/dart_odbc.dart';
import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('columnConfig overrides type and size', () async {
    final result = await helper.cursor(
      'SELECT * FROM USERS',
    );

    var count = 0;

    while (true) {
      final row = await result.next();
      if (row is CursorDone) {
        expect(count, greaterThan(0));
        break;
      }

      final data = (row as CursorItem).value;
      expect(data.containsKey('UID'), isTrue);
      expect(data.containsKey('NAME'), isTrue);
      count++;
    }
  });
}
