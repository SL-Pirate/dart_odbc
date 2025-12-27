import 'package:test/test.dart';

import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('list all tables', () async {
    final tables = await helper.odbc.getTables();
    expect(tables, isNotEmpty);
  });
}
