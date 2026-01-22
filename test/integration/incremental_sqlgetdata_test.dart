import 'package:test/test.dart';

import '../test_helper.dart';

void main() {
  setupTestLogging();

  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('read long NVARCHAR via incremental SQLGetData (no garbage)', () async {
    final rows = await helper.exec('SELECT @@VERSION AS version;');

    expect(rows, isNotEmpty);

    final version = rows[0]['version'] as String;
    expect(version, isNotNull);
    testLog.info(version);
  });
}
