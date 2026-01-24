import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';

/// Example: Processing large tables with 200+ columns
///
/// Some ODBC drivers (notably SQL Server Native Client 11.0) have limitations
/// when processing tables with 200+ columns. You may encounter HY001
/// (Memory allocation failure) errors when using SELECT * on very wide tables.
///
/// This example demonstrates how to process such tables by grouping columns.
void main() async {
  try {
    await run();
  } on ConnectionException catch (e) {
    // ignore: avoid_print
    print('Connection error: $e');
  } on ODBCException catch (e) {
    // ignore: avoid_print
    print('ODBC error: ${e.message} (SQLState: ${e.sqlState})');
  } catch (e) {
    // ignore: avoid_print
    print('Unexpected error: $e');
  }
}

Future<void> run() async {
  final DotEnv env = DotEnv()..load(['.env']);

  final odbc = DartOdbc(dsn: env['DSN']);
  await odbc.connect(
    username: env['USERNAME']!,
    password: env['PASSWORD']!,
  );

  if (env['DATABASE'] != null) {
    await odbc.execute('USE ${env['DATABASE']}');
  }

  // Example: Processing a table with 200+ columns
  const tableName = 'Produto'; // Replace with your table name
  const columnsPerGroup = 50; // Process 50 columns at a time

  // Step 1: Get all column names
  final columns = await odbc.getColumns(tableName: tableName);
  final columnNames = columns
      .map((c) => c['COLUMN_NAME'] as String)
      .toList();

  // ignore: avoid_print
  print('Table "$tableName" has ${columnNames.length} columns');

  // Step 2: Process columns in groups
  final allResults = <Map<String, dynamic>>[];
  final groupResults = <List<Map<String, dynamic>>>[];

  for (var i = 0; i < columnNames.length; i += columnsPerGroup) {
    final groupNumber = (i ~/ columnsPerGroup) + 1;
    final groupColumns = columnNames.skip(i).take(columnsPerGroup).toList();
    final selectedColumns = groupColumns.join(', ');

    // ignore: avoid_print
    print(
      'Processing group $groupNumber: columns ${i + 1} to '
      '${i + groupColumns.length}',
    );

    try {
      final query = 'SELECT $selectedColumns FROM $tableName';
      final groupResult = await odbc.execute(query);

      if (groupResult.isEmpty) {
        // ignore: avoid_print
        print('Group $groupNumber returned 0 rows');
        continue;
      }

      groupResults.add(groupResult);
      // ignore: avoid_print
      print('Group $groupNumber: ${groupResult.length} rows processed');
    } on ODBCException catch (e) {
      if (e.sqlState == 'HY001' ||
          e.message.contains('Memory allocation')) {
        // ignore: avoid_print
        print(
          'Memory allocation failure in group $groupNumber. '
          'Try reducing columnsPerGroup (current: $columnsPerGroup)',
        );
        // In production, you might want to:
        // 1. Reduce columnsPerGroup and retry
        // 2. Skip problematic columns
        // 3. Process with row pagination
        continue;
      }
      rethrow;
    }
  }

  // Step 3: Merge results by primary key (if you have one)
  // For this example, we'll just combine all groups
  // In production, you should merge by primary key to ensure data consistency

  if (groupResults.isNotEmpty) {
    // Simple merge: use first group as base
    allResults.addAll(groupResults.first);

    // ignore: avoid_print
    print(
      'Processed ${groupResults.length} column groups, '
      '${allResults.length} total rows',
    );

    // Example: Print first row (with available columns from first group)
    if (allResults.isNotEmpty) {
      // ignore: avoid_print
      print('First row sample:');
      final firstRow = allResults.first;
      final sampleKeys = firstRow.keys.take(5).toList();
      for (final key in sampleKeys) {
        // ignore: avoid_print
        print('  $key: ${firstRow[key]}');
      }
    }
  } else {
    // ignore: avoid_print
    print('No data returned from any column group');
  }

  await odbc.disconnect();
}
