import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';

import '../test_runner.dart';

void main() {
  late DotEnv env;
  late TestRunner runner;

  setUpAll(() {
    env = DotEnv()..load(['.env']);
    runner = TestRunner(
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
