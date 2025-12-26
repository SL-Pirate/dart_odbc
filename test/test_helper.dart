// False positive because this is only a helper for testing
// ignore_for_file: unreachable_from_main

import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';

class TestHelper {
  TestHelper([DartOdbc? odbc]) {
    if (odbc != null) this.odbc = odbc;
  }

  late DartOdbc odbc;
  late final DotEnv env;

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

  Future<void> connectWithConnectionString(String connectionString) async {
    await odbc.connectWithConnectionString(connectionString);
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic> params = const [],
    Map<String, ColumnType>? columnConfig,
  }) {
    return odbc.execute(
      sql,
      params: params,
      columnConfig: columnConfig ?? {},
    );
  }

  Future<void> disconnect() => odbc.disconnect();
}

void main() {}
