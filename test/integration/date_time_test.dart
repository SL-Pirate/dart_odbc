import 'package:test/test.dart';

import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('date time support test', () async {
    final results = await helper.query(
      '''
        SELECT * FROM USERS
        WHERE BIRTHDAY = ?
      ''',
      params: [
        DateTime(1999, 5, 12),
      ],
    );

    expect(results.length, 1);

    final row = results.first;

    expect(DateTime.parse(row['BIRTHDAY'].toString()), DateTime(1999, 5, 12));
  });
}
