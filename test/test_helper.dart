// False positive because this is only a helper for testing
// ignore_for_file: unreachable_from_main

import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';

/// Logger for test output
/// This logger is public so it can be used in test files
final testLog = Logger('Test');

/// Setup logging for tests - configures Logger to print to console
void setupTestLogging() {
  Logger.root.level = Level.ALL; // Show all levels including WARNING and SEVERE

  Logger.root.onRecord.listen((record) {
    // This print is necessary - it's the mechanism by which the logging
    // package outputs to console. Without it, testLog.info() would not
    // produce visible output.
    // ignore: avoid_print
    print(
      '[${record.level.name}] '
      '${record.loggerName}: '
      '${record.message}',
    );
    if (record.error != null) {
      // print is necessary for test output visibility
      // ignore: avoid_print
      print('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      // print is necessary for test output visibility
      // ignore: avoid_print
      print('  StackTrace: ${record.stackTrace}');
    }
  });
}

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

  /// Processes a large table with many columns by grouping columns.
  ///
  /// This is the recommended approach for tables with 200+ columns to avoid
  /// driver memory allocation failures (HY001).
  ///
  /// [tableName] - Name of the table to query
  /// [columnsPerGroup] - Number of columns to process per group (default: 50)
  /// [primaryKeyColumn] - Column name to use for joining results (optional)
  /// [whereClause] - Optional WHERE clause to filter rows
  /// [orderByClause] - Optional ORDER BY clause
  ///
  /// Returns a list of maps where each map represents a row with all columns.
  /// Results from different column groups are merged by primary key.
  ///
  /// Example:
  /// ```dart
  /// final helper = TestHelper();
  /// await helper.initialize();
  /// final results = await helper.execLargeTable(
  ///   'Produto',
  ///   columnsPerGroup: 50,
  ///   primaryKeyColumn: 'CodProduto',
  /// );
  /// ```
  Future<List<Map<String, dynamic>>> execLargeTable(
    String tableName, {
    int columnsPerGroup = 50,
    String? primaryKeyColumn,
    String? whereClause,
    String? orderByClause,
  }) async {
    testLog.info(
      'Processing large table "$tableName" with column grouping '
      '($columnsPerGroup columns per group)',
    );

    // Get all column names
    final columnsResult = await exec(
      '''
      SELECT COLUMN_NAME
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_NAME = '$tableName'
      ORDER BY ORDINAL_POSITION
      ''',
    );

    if (columnsResult.isEmpty) {
      testLog.warning('Table "$tableName" has no columns or does not exist');
      return [];
    }

    final allColumnNames = columnsResult
        .map((c) => c['COLUMN_NAME'] as String)
        .toList();
    testLog.info('Table "$tableName" has ${allColumnNames.length} columns');

    // Determine primary key if not provided
    var pkColumn = primaryKeyColumn;
    if (pkColumn == null) {
      try {
        final pkResult = await exec(
          '''
          SELECT COLUMN_NAME
          FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
          WHERE TABLE_NAME = '$tableName'
          AND CONSTRAINT_NAME LIKE 'PK_%'
          ORDER BY ORDINAL_POSITION
          ''',
        );
        if (pkResult.isNotEmpty) {
          pkColumn = pkResult.first['COLUMN_NAME'] as String;
          testLog.info('Auto-detected primary key: $pkColumn');
        }
      } on Object catch (e) {
        testLog.warning(
          'Could not auto-detect primary key: $e. '
          'Results will not be merged by key.',
        );
      }
    }

    // Build base query parts
    final wherePart = whereClause != null ? ' WHERE $whereClause' : '';
    final orderByPart = orderByClause != null ? ' ORDER BY $orderByClause' : '';

    // Process columns in groups
    final allResults = <Map<String, dynamic>>[];
    final groupResults = <List<Map<String, dynamic>>>[];

    for (var i = 0; i < allColumnNames.length; i += columnsPerGroup) {
      final groupNumber = (i ~/ columnsPerGroup) + 1;
      final groupColumns = allColumnNames.skip(i).take(columnsPerGroup).toList();
      final selectedColumns = groupColumns.join(', ');

      testLog.info(
        'Processing group $groupNumber: columns ${i + 1} to '
        '${i + groupColumns.length} (${groupColumns.length} columns)',
      );

      var groupSucceeded = false;

      try {
        final query =
            'SELECT $selectedColumns FROM $tableName$wherePart$orderByPart';
        final groupResult = await exec(query);

        if (groupResult.isEmpty) {
          testLog.info('Group $groupNumber returned 0 rows');
          continue;
        }

        groupResults.add(groupResult);
        testLog.info(
          'Group $groupNumber: ${groupResult.length} rows processed',
        );
        groupSucceeded = true;
      } on ODBCException catch (e) {
        if (e.sqlState == 'HY001' ||
            e.message.contains('Memory allocation')) {
          testLog.warning(
            'Memory allocation failure in group $groupNumber with '
            '${groupColumns.length} columns. '
            'This may indicate some columns are very large (BINARY/IMAGE).',
          );

          // Try with row pagination as fallback
          testLog
            ..info(
              'Attempting fallback: processing group $groupNumber '
              'with row pagination...',
            );

          try {
            final paginatedResult = await _execWithPagination(
              tableName,
              groupColumns,
              whereClause: whereClause,
              orderByClause: orderByClause,
            );

            if (paginatedResult.isNotEmpty) {
              groupResults.add(paginatedResult);
              testLog.info(
                'Group $groupNumber (with pagination): '
                '${paginatedResult.length} rows processed',
              );
              groupSucceeded = true;
            } else {
              testLog.warning(
                'Group $groupNumber failed even with pagination. '
                'Skipping this column group.',
              );
            }
          } on Object catch (e2) {
            testLog.warning(
              'Group $groupNumber failed even with pagination: $e2. '
              'Skipping this column group.',
            );
            // Continue with other groups instead of failing completely
          }
        } else {
          // For non-HY001 errors, log and skip this group
          testLog.warning(
            'Error in group $groupNumber: $e. '
            'Skipping this column group.',
          );
        }
      } on Object catch (e) {
        // Catch any other unexpected errors
        testLog.warning(
          'Unexpected error in group $groupNumber: $e. '
          'Skipping this column group.',
        );
      }

      if (!groupSucceeded) {
        testLog.info(
          'Group $groupNumber was skipped. Processing will continue with '
          'remaining groups.',
        );
      }
    }

    if (groupResults.isEmpty) {
      testLog.warning('No data returned from any column group');
      return [];
    }

    final totalGroups = (allColumnNames.length / columnsPerGroup).ceil();
    testLog.info(
      'Successfully processed ${groupResults.length} out of '
      '$totalGroups column groups',
    );

    // Merge results by primary key if available
    if (pkColumn != null && groupResults.length > 1) {
      testLog.info(
        'Merging ${groupResults.length} column groups by primary key: '
        '$pkColumn',
      );

      // Use first group as base
      final merged = <String, Map<String, dynamic>>{};
      for (final row in groupResults.first) {
        final key = row[pkColumn]?.toString() ?? '';
        merged[key] = Map<String, dynamic>.from(row);
      }

      // Merge remaining groups
      for (var groupIndex = 1; groupIndex < groupResults.length; groupIndex++) {
        for (final row in groupResults[groupIndex]) {
          final key = row[pkColumn]?.toString() ?? '';
          if (merged.containsKey(key)) {
            merged[key]!.addAll(row);
          } else {
            testLog.warning(
              'Row with key "$key" found in group ${groupIndex + 1} '
              'but not in first group. This may indicate data inconsistency.',
            );
            merged[key] = Map<String, dynamic>.from(row);
          }
        }
      }

      allResults.addAll(merged.values);
      testLog.info(
        'Merged ${groupResults.length} groups into ${allResults.length} rows',
      );
    } else {
      // No primary key or single group - return first group as-is
      allResults.addAll(groupResults.first);
      if (groupResults.length > 1) {
        testLog.warning(
          'Multiple column groups but no primary key specified. '
          'Returning only first group. '
          'Specify primaryKeyColumn to merge results.',
        );
      }
    }

    return allResults;
  }

  /// Helper method to execute query with row pagination as fallback.
  Future<List<Map<String, dynamic>>> _execWithPagination(
    String tableName,
    List<String> columns, {
    String? whereClause,
    String? orderByClause,
  }) async {
    var batchSize = 1000;
    final selectedColumns = columns.join(', ');
    final wherePart = whereClause != null ? ' WHERE $whereClause' : '';
    final orderByPart = orderByClause != null
        ? ' ORDER BY $orderByClause'
        : ' ORDER BY (SELECT NULL)';

    // Get total row count
    final countQuery = 'SELECT COUNT(*) as total FROM $tableName$wherePart';
    final countResult = await exec(countQuery);
    final totalRows = countResult.first['total'] is int
        ? countResult.first['total'] as int
        : int.tryParse(countResult.first['total'].toString()) ?? 0;

    if (totalRows == 0) {
      return [];
    }

    final allRows = <Map<String, dynamic>>[];
    var offset = 0;

    while (offset < totalRows) {
      final query =
          'SELECT $selectedColumns FROM $tableName$wherePart$orderByPart '
          'OFFSET $offset ROWS FETCH NEXT $batchSize ROWS ONLY';

      try {
        final batch = await exec(query);
        if (batch.isEmpty) {
          break;
        }
        allRows.addAll(batch);
        offset += batchSize;

        if (batch.length < batchSize) {
          break;
        }
      } on ODBCException catch (e) {
        if (e.sqlState == 'HY001' ||
            e.message.contains('Memory allocation')) {
          // Even pagination failed - reduce batch size
          if (batchSize > 100) {
            final newBatchSize = (batchSize / 2).round();
            testLog.info(
              'Reducing batch size to $newBatchSize and retrying...',
            );
            batchSize = newBatchSize;
            continue;
          } else {
            testLog.warning(
              'Pagination failed even with batch size $batchSize. '
              'Some columns may be too large.',
            );
            break;
          }
        }
        rethrow;
      }
    }

    return allRows;
  }
}

void main() {}
