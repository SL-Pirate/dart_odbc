import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import '../test_helper.dart';

void main() {
  // enable logging
  Logger.root.level = Level.FINE;

  Logger.root.onRecord.listen((record) {
    // This is intentional for logging purposes
    // ignore: avoid_print
    print(
      '[${record.level.name}] '
      '${record.loggerName}: '
      '${record.message}',
    );
  });

  late DotEnv env;
  late TestHelper helper;
  late TestHelper connStrHelper;

  setUpAll(() {
    env = DotEnv()..load(['.env']);
    helper = TestHelper(DartOdbc.nonBlocking(dsn: env['DSN']));
    connStrHelper = TestHelper(DartOdbc.nonBlocking());
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

    // This is intentional for logging purposes
    // ignore: avoid_print
    print(await connStrHelper.connectWithConnectionString(connectionString));

    // If connect fails, test throws before this line
    expect(true, isTrue);

    await connStrHelper.disconnect();
  });
}
