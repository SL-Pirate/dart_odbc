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

  test('invalid SQL throws', () async {
    expect(
      () => runner.query('SELECT * FROM DOES_NOT_EXIST'),
      throwsA(isA<Exception>()),
    );
  });
}
