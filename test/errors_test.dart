import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('invalid SQL throws', () async {
    expect(
      () => helper.query('SELECT * FROM DOES_NOT_EXIST'),
      throwsA(isA<Exception>()),
    );
  });
}
