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

  test('simple select returns rows', () async {
    final result = await runner.query(
      'SELECT UID, NAME FROM USERS',
    );

    expect(result, isA<List<Map<String, dynamic>>>());
    expect(result.isNotEmpty, true);
    expect(result.first.containsKey('UID'), true);
    expect(result.first.containsKey('NAME'), true);
  });
}
