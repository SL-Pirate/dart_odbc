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

  test('insert creates a new user row', () async {
    const uid = 1001;

    // Ensure clean state (idempotent)
    await runner.query(
      'DELETE FROM USERS WHERE UID = ?',
      params: [uid],
    );

    await runner.query(
      'INSERT INTO USERS (UID, NAME, DESCRIPTION) VALUES (?, ?, ?)',
      params: [uid, 'Charlie', 'Inserted from test'],
    );

    final result = await runner.query(
      'SELECT NAME, DESCRIPTION FROM USERS WHERE UID = ?',
      params: [uid],
    );

    expect(result.length, 1);
    expect(result.first['NAME'], 'Charlie');
    expect(result.first['DESCRIPTION'], 'Inserted from test');
  });
}
