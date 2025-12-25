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

  test('columnConfig overrides type and size', () async {
    final result = await runner.query(
      'SELECT data FROM BINARY_TABLE WHERE id = ?',
      params: [1],
      columnConfig: {
        'data': ColumnType(
          type: SQL_VARBINARY,
          size: 100,
        ),
      },
    );

    expect(result, isNotEmpty);
    expect(result.first['data'], isA<List<int>>());
  });
}
