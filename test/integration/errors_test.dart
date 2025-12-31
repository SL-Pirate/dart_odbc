import 'package:test/test.dart';

import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('invalid SQL throws', () async {
    // try {
    //   final result = await helper.query('SELECT * FROM DOES_NOT_EXIST');
    //   print(result);
    // } catch (e) {
    //   print('Caught exception: $e');
    // }

    expect(
      () => helper.exec('SELECT * FROM DOES_NOT_EXIST'),
      throwsA(isA<Exception>()),
    );
  });
}
