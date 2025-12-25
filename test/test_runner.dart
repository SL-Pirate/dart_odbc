import 'package:dart_odbc/dart_odbc.dart';

class TestRunner {
  TestRunner(this.odbc);

  final DartOdbc odbc;

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
