import 'package:test/test.dart';

import '../support/test_database.dart';
import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('insert creates a new user row', () async {
    const uid = 1001;

    // Ensure clean state (idempotent)
    await helper.run(Sql.deleteUserById, params: [uid]);

    await helper.run(
      Sql.insertUser,
      params: [uid, 'Charlie', 'Inserted from test'],
    );

    final result = await helper.run(
      Sql.selectUserNameAndDescriptionById,
      params: [uid],
    );

    expect(result.length, 1);
    expect(result.first['NAME'], 'Charlie');
    expect(result.first['DESCRIPTION'], 'Inserted from test');
  });
}
