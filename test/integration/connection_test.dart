import 'package:dart_odbc/dart_odbc.dart';
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

  // Configuration comes from TestHelper, which resolves it once in its
  // constructor. Previously this file loaded its own DotEnv.
  late TestHelper config;
  late TestHelper helper;
  late TestHelper connStrHelper;

  setUpAll(() {
    config = TestHelper();
    helper = TestHelper(DartOdbc(dsn: config.dsn));
    connStrHelper = TestHelper(DartOdbc());
  });

  tearDownAll(() async {
    await helper.disconnect();
    await connStrHelper.disconnect();
  });

  // Exercises SQLConnectW, which accepts only a DSN name registered in
  // odbc.ini -- never a host/port pair.
  test('connects and disconnects successfully using DSN', () async {
    await helper.connect(
      username: config.username,
      password: config.password,
      database: config.database,
    );

    expect(true, isTrue);
  });

  // Exercises SQLDriverConnectW, which accepts a full connection string.
  test('connects successfully using connection string', () async {
    final connectionString = [
      'DSN=${config.dsn}',
      'UID=${config.username}',
      'PWD=${config.password}',
    ].join(';');

    // This is intentional for logging purposes
    // ignore: avoid_print
    print(await connStrHelper.connectWithConnectionString(connectionString));

    // If connect fails, test throws before this line
    expect(true, isTrue);

    await connStrHelper.disconnect();
  });
}
