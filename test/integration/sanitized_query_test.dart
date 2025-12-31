import 'package:test/test.dart';

import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('parameterized query works', () async {
    final result = await helper.exec(
      'SELECT NAME FROM USERS WHERE UID = ?',
      params: [1],
    );

    expect(result.length, 1);
    expect(result.first['NAME'], isA<String>());
  });
}
