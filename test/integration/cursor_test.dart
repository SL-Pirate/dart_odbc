import 'package:dart_odbc/dart_odbc.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';
import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('simple cursor test', () async {
    final result = await helper.runCursor(Sql.selectAllUsers);

    var count = 0;

    while (true) {
      final row = await result.next();
      if (row is CursorDone) {
        expect(count, greaterThan(0));
        break;
      }

      final data = (row as CursorItem).value;
      expect(data.containsKey('UID'), isTrue);
      expect(data.containsKey('NAME'), isTrue);
      count++;
    }
  });

  test('sequential cursors do not leak state', () async {
    for (var i = 0; i < 5; i++) {
      final cursor = await helper.runCursor(Sql.selectAllUsers);

      var count = 0;
      while (true) {
        final row = await cursor.next();
        if (row is CursorDone) break;
        count++;
      }

      expect(count, greaterThan(0));
    }
  });

  test('multiple non-blocking clients can run cursors concurrently', () async {
    final clients = List.generate(
      3,
      (_) => DartOdbc(dsn: helper.dsn),
    );

    try {
      await Future.wait(
        clients.map(
          (c) async {
            await c.connect(
              username: helper.username,
              password: helper.password,
            );

            // Engines that select the database at connect time (PostgreSQL via
            // the DSN) return null here and need no switch statement.
            final useStatement = helper.dialect.useDatabase(
              helper.database ?? '',
            );
            if (useStatement != null) {
              await c.execute(useStatement);
            }
          },
        ),
      );

      final cursors = await Future.wait(
        clients.map(
          (c) => c.executeCursor(helper.sql(Sql.selectAllUsersTerminated)),
        ),
      );

      final results = await Future.wait(
        cursors.map((cursor) async {
          var count = 0;
          while (true) {
            final row = await cursor.next();
            if (row is CursorDone) break;
            count++;
          }
          return count;
        }),
      );

      for (final count in results) {
        expect(count, greaterThan(0));
      }
    } finally {
      await Future.wait(clients.map((c) => c.disconnect()));
    }
  });
}
