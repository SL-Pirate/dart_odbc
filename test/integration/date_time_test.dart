import 'package:test/test.dart';

import '../support/test_database.dart';
import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('date time support test', () async {
    final results = await helper.run(
      Sql.selectUsersByBirthday,
      // Routed through the dialect: drivers differ on whether a date column
      // accepts a bound DateTime directly.
      params: [helper.dialect.dateParam(DateTime(1999, 5, 12))],
    );

    expect(results.length, 1);

    final row = results.first;

    expect(DateTime.parse(row['BIRTHDAY'].toString()), DateTime(1999, 5, 12));
  });
}
