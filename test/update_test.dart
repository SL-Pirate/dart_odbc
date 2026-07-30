import 'package:test/test.dart';

import 'support/test_database.dart';
import 'test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('update modifies an existing row', () async {
    const uid = 1002;

    // Ensure row exists
    await helper.run(Sql.deleteUserById, params: [uid]);

    await helper.run(
      Sql.insertUser,
      params: [uid, 'Dana', 'Before update'],
    );

    await helper.run(
      Sql.updateUserDescriptionById,
      params: ['After update', uid],
    );

    final result = await helper.run(
      Sql.selectUserDescriptionById,
      params: [uid],
    );

    expect(result.length, 1);
    expect(result.first['DESCRIPTION'], 'After update');
  });
}
