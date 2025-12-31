// False positive because this is only a helper for testing
// ignore_for_file: unreachable_from_main

import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';

class TestHelper {
  TestHelper([IDartOdbc? odbc]) {
    if (odbc != null) {
      this.odbc = odbc;
    }
  }

  late IDartOdbc odbc;
  late final DotEnv env;

  String? get dsn => env['DSN'];

  String get username => env['USERNAME']!;

  String get password => env['PASSWORD']!;

  Future<void> initialize() async {
    env = DotEnv()..load(['.env']);
    odbc = DartOdbc(dsn: env['DSN']);
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
    await odbc.connect(username: username, password: password);

    if (database != null) {
      await odbc.execute('USE $database');
    }
  }

  Future<String> connectWithConnectionString(String connectionString) {
    return odbc.connectWithConnectionString(connectionString);
  }

  Future<List<Map<String, dynamic>>> exec(
    String sql, {
    List<dynamic> params = const [],
  }) {
    return odbc.execute(sql, params: params);
  }

  Future<OdbcCursor> cursor(
    String sql, {
    List<dynamic> params = const [],
  }) async {
    return odbc.executeCursor(
      sql,
      params: params,
    );
  }

  Future<void> disconnect() async {
    await odbc.disconnect();
  }

  IDartOdbc getOdbc() {
    return odbc;
  }
}

void main() {}
