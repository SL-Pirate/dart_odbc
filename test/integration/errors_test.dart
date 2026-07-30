import 'package:test/test.dart';

import '../support/test_database.dart';
import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('invalid SQL throws', () async {
    expect(
      () => helper.run(Sql.selectFromMissingTable),
      throwsA(isA<Exception>()),
    );
  });
}
