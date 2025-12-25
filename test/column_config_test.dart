import 'package:dart_odbc/dart_odbc.dart';
import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('columnConfig overrides type and size', () async {
    final result = await helper.query(
      'SELECT data FROM BINARY_TABLE WHERE id = ?',
      params: [1],
      columnConfig: {
        'data': ColumnType(
          type: SQL_VARBINARY,
          // size: 100,
        ),
      },
    );

    expect(result, isNotEmpty);
    expect(result.first['data'], isA<List<int>>());
  });
}
