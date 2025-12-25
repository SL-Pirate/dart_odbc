import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';

import '../test_runner.dart';

void main() {
  late TestRunner runner;
  late DotEnv env;

  setUpAll(() async {
    env = DotEnv()..load(['.env']);
    runner = TestRunner(DartOdbc(dsn: env['DSN']));
    await runner.connect(
      username: env['USERNAME']!,
      password: env['PASSWORD']!,
      database: env['DATABASE'],
    );
  });

  tearDownAll(() async {
    await runner.disconnect();
  });

  test('update modifies an existing row', () async {
    const uid = 1002;

    // Ensure row exists
    await runner.query(
      'DELETE FROM USERS WHERE UID = ?',
      params: [uid],
    );

    await runner.query(
      'INSERT INTO USERS (UID, NAME, DESCRIPTION) VALUES (?, ?, ?)',
      params: [uid, 'Dana', 'Before update'],
    );

    await runner.query(
      'UPDATE USERS SET DESCRIPTION = ? WHERE UID = ?',
      params: ['After update', uid],
    );

    final result = await runner.query(
      'SELECT DESCRIPTION FROM USERS WHERE UID = ?',
      params: [uid],
    );

    expect(result.length, 1);
    expect(result.first['DESCRIPTION'], 'After update');
  });
}
