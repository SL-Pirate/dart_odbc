import 'package:test/test.dart';

import '../test_helper.dart';

void main() {
  setupTestLogging();

  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  group('SQL Injection Prevention', () {
    test('string parameter with single quote is properly escaped', () async {
      // Create a test table if it doesn't exist
      try {
        await helper.exec('DROP TABLE IF EXISTS test_security');
      } on Object {
        // Ignore if table doesn't exist
      }

      await helper.exec(
        'CREATE TABLE test_security (id INT, name NVARCHAR(100))',
      );

      // Insert test data with single quote in string parameter
      await helper.exec(
        'INSERT INTO test_security (id, name) VALUES (?, ?)',
        params: [1, "O'Brien"],
      );

      // Query should work correctly and not cause SQL injection
      final result = await helper.exec(
        'SELECT name FROM test_security WHERE id = ?',
        params: [1],
      );

      expect(result.length, 1);
      expect(result.first['name'], equals("O'Brien"));

      // Cleanup
      await helper.exec('DROP TABLE test_security');
    });

    test('string parameter with multiple single quotes is properly escaped',
        () async {
      try {
        await helper.exec('DROP TABLE IF EXISTS test_security');
      } on Object {
        // Ignore
      }

      await helper.exec(
        'CREATE TABLE test_security (id INT, name NVARCHAR(100))',
      );

      // Insert with multiple single quotes
      await helper.exec(
        'INSERT INTO test_security (id, name) VALUES (?, ?)',
        params: [2, "It's a test's value"],
      );

      final result = await helper.exec(
        'SELECT name FROM test_security WHERE id = ?',
        params: [2],
      );

      expect(result.length, 1);
      expect(result.first['name'], equals("It's a test's value"));

      await helper.exec('DROP TABLE test_security');
    });

    test('mixed string and non-string parameters work correctly', () async {
      try {
        await helper.exec('DROP TABLE IF EXISTS test_security');
      } on Object {
        // Ignore
      }

      await helper.exec(
        'CREATE TABLE test_security (id INT, name NVARCHAR(100), age INT)',
      );

      // Insert with string and int parameters
      await helper.exec(
        'INSERT INTO test_security (id, name, age) VALUES (?, ?, ?)',
        params: [3, 'Test User', 25],
      );

      final result = await helper.exec(
        'SELECT * FROM test_security WHERE id = ?',
        params: [3],
      );

      expect(result.length, 1);
      expect(result.first['name'], equals('Test User'));
      // ODBC returns numeric values as strings
      expect(result.first['age'], isA<String>());
      expect(int.parse(result.first['age'] as String), equals(25));

      await helper.exec('DROP TABLE test_security');
    });

    test('unsupported parameter type throws exception with descriptive message',
        () async {
      expect(
        () => helper.exec(
          'SELECT * FROM test_security WHERE id = ?',
          params: [
            <String>['invalid'],
          ],
        ),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('Unsupported parameter type') &&
                e.toString().contains('List<String>'),
          ),
        ),
      );
    });
  });
}
