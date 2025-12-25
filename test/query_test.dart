import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('simple select returns rows', () async {
    final result = await helper.query('SELECT * FROM USERS');

    expect(result, isA<List<Map<String, dynamic>>>());
    expect(result.isNotEmpty, true);
    expect(result.first.containsKey('UID'), true);
    expect(result.first.containsKey('NAME'), true);
  });
}
