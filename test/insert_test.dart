import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('insert creates a new user row', () async {
    const uid = 1001;

    // Ensure clean state (idempotent)
    await helper.query(
      'DELETE FROM USERS WHERE UID = ?',
      params: [uid],
    );

    await helper.query(
      'INSERT INTO USERS (UID, NAME, DESCRIPTION) VALUES (?, ?, ?)',
      params: [uid, 'Charlie', 'Inserted from test'],
    );

    final result = await helper.query(
      'SELECT NAME, DESCRIPTION FROM USERS WHERE UID = ?',
      params: [uid],
    );

    expect(result.length, 1);
    expect(result.first['NAME'], 'Charlie');
    expect(result.first['DESCRIPTION'], 'Inserted from test');
  });
}
