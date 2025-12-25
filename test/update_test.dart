import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('update modifies an existing row', () async {
    const uid = 1002;

    // Ensure row exists
    await helper.query(
      'DELETE FROM USERS WHERE UID = ?',
      params: [uid],
    );

    await helper.query(
      'INSERT INTO USERS (UID, NAME, DESCRIPTION) VALUES (?, ?, ?)',
      params: [uid, 'Dana', 'Before update'],
    );

    await helper.query(
      'UPDATE USERS SET DESCRIPTION = ? WHERE UID = ?',
      params: ['After update', uid],
    );

    final result = await helper.query(
      'SELECT DESCRIPTION FROM USERS WHERE UID = ?',
      params: [uid],
    );

    expect(result.length, 1);
    expect(result.first['DESCRIPTION'], 'After update');
  });
}
