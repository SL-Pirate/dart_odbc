// Dialect translation map for the integration suite.
//
// The tests exercise the ODBC/FFI layer, not any one vendor's SQL. So they never
// contain SQL directly: they ask for a statement by NAME and the dialect
// translates it, the same way a localization map turns a message key into text
// for a locale.
//
//     helper.sql(Sql.selectAllUsers)
//       -> 'SELECT * FROM "USERS"'   (postgres)
//       -> 'SELECT * FROM [USERS]'   (sqlserver)
//
// Adding an engine means adding one subclass with a complete statement map,
// plus a schema file in test/schema/. No test file changes.

import 'dart:io';

part 'impl/test_database_mariadb_dialect.dart';
part 'impl/test_database_postgres_dialect.dart';

/// Keys for every statement the integration suite needs.
///
/// A dialect must provide a translation for each one. Because these are enum
/// values, a dialect missing a case fails to compile rather than failing at
/// runtime on whichever test happens to run first.
enum Sql {
  /// All columns and rows of the users table.
  selectAllUsers,

  /// Same as [selectAllUsers] but with a statement terminator, used by the
  /// concurrent-cursor test.
  selectAllUsersTerminated,

  /// Name column for one user, by id. One parameter: uid.
  selectUserNameById,

  /// Name and description for one user, by id. One parameter: uid.
  selectUserNameAndDescriptionById,

  /// Description for one user, by id. One parameter: uid.
  selectUserDescriptionById,

  /// All columns for users with a given birthday. One parameter: birthday.
  selectUsersByBirthday,

  /// Remove one user by id. One parameter: uid.
  deleteUserById,

  /// Add a user. Three parameters: uid, name, description.
  insertUser,

  /// Change one user's description. Two parameters: description, uid.
  updateUserDescriptionById,

  /// Binary column for one row, by id. Used to check that binary columns come
  /// back as a byte list rather than text.
  selectBinaryDataById,

  /// A single text value longer than `defaultBufferSize` (4096), aliased to
  /// `version`, to force the incremental SQLGetData path.
  selectLongText,

  /// Echo one bound parameter back, aliased to `index_value`.
  echoParameter,

  /// A query against a table that does not exist, to check error propagation.
  selectFromMissingTable,
}

/// Per-engine translations of [Sql] plus the few non-SQL differences.
abstract class TestDatabase {
  const TestDatabase();

  /// Value of `TEST_DB` that selects this dialect.
  String get name;

  /// The statement for [key] in this dialect.
  String sql(Sql key);

  /// Quotes an identifier so the engine preserves its case. Exposed because a
  /// few assertions need to name a column the same way the schema does.
  String id(String raw);

  /// Statement that switches the active database, or `null` when the engine
  /// selects the database at connect time instead.
  String? useDatabase(String database);

  /// Path to this engine's schema file, relative to the repository root. The
  /// container harness mounts it so the database seeds itself on first boot.
  String get schemaPath => 'test/schema/$name.sql';

  /// Binds a `DateTime` in the form this engine's driver expects for a date
  /// column. Most drivers take the `DateTime`; some need a string.
  Object? dateParam(DateTime value) => value;

  /// The dialect selected by `TEST_DB`, defaulting to PostgreSQL.
  static TestDatabase resolve() {
    final requested = Platform.environment['TEST_DB'] ?? 'postgres';

    return switch (requested) {
      'postgres' => const PostgresDialect(),
      'mariadb' => const MariaDbDialect(),
      _ => throw UnsupportedError(
          'Unknown TEST_DB "$requested". Implement TestDatabase, add a case '
          'here, and provide a matching schema file.',
        ),
    };
  }
}
