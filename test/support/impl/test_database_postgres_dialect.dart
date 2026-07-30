part of '../test_database.dart';

/// PostgresSQL via the psqlODBC driver. This is the dialect CI verifies.
///
/// Identifiers are double-quoted so PostgresSQL preserves their upper case;
/// unquoted identifiers get folded to lower case, which would change every
/// returned column key from `UID` to `uid`.
class PostgresDialect extends TestDatabase {
  const PostgresDialect();

  @override
  String get name => 'postgres';

  @override
  String id(String raw) => '"$raw"';

  // PostgresSQL selects the database at connect time (via the DSN), so there is
  // no equivalent of T-SQL's `USE <db>`.
  @override
  String? useDatabase(String database) => null;

  @override
  Object? dateParam(DateTime value) => value;

  @override
  String sql(Sql key) => switch (key) {
        Sql.selectAllUsers => 'SELECT * FROM "USERS"',
        Sql.selectAllUsersTerminated => 'SELECT * FROM "USERS";',
        Sql.selectUserNameById => 'SELECT "NAME" FROM "USERS" WHERE "UID" = ?',
        Sql.selectUserNameAndDescriptionById =>
          'SELECT "NAME", "DESCRIPTION" FROM "USERS" WHERE "UID" = ?',
        Sql.selectUserDescriptionById =>
          'SELECT "DESCRIPTION" FROM "USERS" WHERE "UID" = ?',
        Sql.selectUsersByBirthday =>
          'SELECT * FROM "USERS" WHERE "BIRTHDAY" = ?',
        Sql.deleteUserById => 'DELETE FROM "USERS" WHERE "UID" = ?',
        Sql.insertUser =>
          'INSERT INTO "USERS" ("UID", "NAME", "DESCRIPTION") VALUES (?, ?, ?)',
        Sql.updateUserDescriptionById =>
          'UPDATE "USERS" SET "DESCRIPTION" = ? WHERE "UID" = ?',
        Sql.selectBinaryDataById =>
          'SELECT "DATA" FROM "BINARY_TABLE" WHERE "ID" = ?',
        // version() alone is ~88 chars, which fits one 4096 byte read, so the
        // test would pass without exercising the incremental path it exists
        // to cover. Repeating it yields ~17,800 characters.
        Sql.selectLongText => "SELECT repeat(version() || ' ', 200) AS version",
        Sql.echoParameter => 'SELECT ? AS index_value',
        Sql.selectFromMissingTable => 'SELECT * FROM "DOES_NOT_EXIST"',
      };
}
