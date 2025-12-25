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

  test('parameterized query works', () async {
    final result = await runner.query(
      'SELECT NAME FROM USERS WHERE UID = ?',
      params: [1],
    );

    expect(result.length, 1);
    expect(result.first['NAME'], isA<String>());
  });
}
