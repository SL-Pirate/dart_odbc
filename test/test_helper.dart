// False positive because this is only a helper for testing
// ignore_for_file: unreachable_from_main

import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';

class TestHelper {
  TestHelper([(IDartOdbc blocking, IDartOdbc nonBlocking)? drivers]) {
    if (drivers != null) {
      final (item1, item2) = drivers;

      blockingOdbc = item1;
      nonBlockingOdbc = item2;
    }
  }

  late IDartOdbc blockingOdbc;
  late IDartOdbc nonBlockingOdbc;
  late final DotEnv env;

  Future<void> initialize() async {
    env = DotEnv()..load(['.env']);
    blockingOdbc = DartOdbc.blocking(dsn: env['DSN']);
    nonBlockingOdbc = DartOdbc.nonBlocking(dsn: env['DSN']);
    await connect(
      username: env['USERNAME']!,
      password: env['PASSWORD']!,
      database: env['DATABASE'],
    );
  }

  Future<void> connect({
    required String username,
    required String password,
    String? database,
  }) async {
    await nonBlockingOdbc.connect(username: username, password: password);
    await blockingOdbc.connect(username: username, password: password);

    if (database != null) {
      await nonBlockingOdbc.execute('USE $database');
      await blockingOdbc.execute('USE $database');
    }
  }

  Future<String> connectWithConnectionString(String connectionString) {
    return nonBlockingOdbc.connectWithConnectionString(connectionString);
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic> params = const [],
  }) {
    return nonBlockingOdbc.execute(sql, params: params);
  }

  Future<OdbcCursor> cursor(
    String sql, {
    List<dynamic> params = const [],
  }) async {
    return blockingOdbc.executeCursor(
      sql,
      params: params,
    );
  }

  Future<void> disconnect() async {
    await nonBlockingOdbc.disconnect();
    await blockingOdbc.disconnect();
  }

  IDartOdbc getOdbc() {
    return nonBlockingOdbc;
  }
}

void main() {}
