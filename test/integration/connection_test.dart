import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';

import '../test_helper.dart';

void main() {
  setupTestLogging();

  late DotEnv env;
  late TestHelper helper;
  late TestHelper connStrHelper;

  setUpAll(() {
    env = DotEnv()..load(['.env']);
    helper = TestHelper(DartOdbc(dsn: env['DSN']));
    connStrHelper = TestHelper(DartOdbc());
  });

  tearDownAll(() async {
    await helper.disconnect();
    await connStrHelper.disconnect();
  });

  test('connects and disconnects successfully using DSN', () async {
    await helper.connect(
      username: env['USERNAME']!,
      password: env['PASSWORD']!,
      database: env['DATABASE'],
    );

    expect(true, isTrue);
  });

  test('connects successfully using connection string', () async {
    final connectionString = [
      'DSN=${env['DSN']}',
      'UID=${env['USERNAME']}',
      'PWD=${env['PASSWORD']}',
      if (env['DATABASE'] != null) 'DATABASE=${env['DATABASE']}',
    ].join(';');

    final result =
        await connStrHelper.connectWithConnectionString(connectionString);
    testLog.info(result);

    // If connect fails, test throws before this line
    expect(true, isTrue);

    await connStrHelper.disconnect();
  });
}
