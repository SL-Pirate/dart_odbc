import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  late DotEnv env;
  late TestHelper runner;

  setUpAll(() {
    env = DotEnv()..load(['.env']);
    runner = TestHelper(
      DartOdbc(dsn: env['DSN']),
    );
  });

  tearDownAll(() async {
    await runner.disconnect();
  });

  test('connects and disconnects successfully', () async {
    await runner.connect(
      username: env['USERNAME']!,
      password: env['PASSWORD']!,
      database: env['DATABASE'],
    );

    // If connect fails, test throws before this line
    expect(true, isTrue);
  });
}
