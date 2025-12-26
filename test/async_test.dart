import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('parallel async query test', () async {
    final futures = List.generate(10, (index) {
      return helper.query(
        'SELECT ? AS index_value;',
        params: [index],
      );
    });

    final results = await Future.wait(futures);

    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      expect(result.length, 1);
      expect(result[0]['index_value'], i.toString());
    }
  });
}
