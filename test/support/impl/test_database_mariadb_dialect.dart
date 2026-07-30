part of '../test_database.dart';

/// MariaDB via the MariaDB Connector/ODBC driver.
///
/// Identifiers are backtick-quoted. On Linux MariaDB defaults to
/// `lower_case_table_names=0`, so upper-case table and column names are
/// preserved and the same assertions used for PostgreSQL apply unchanged.
class MariaDbDialect extends TestDatabase {
  const MariaDbDialect();

  @override
  String get name => 'mariadb';

  // MariaDB quotes with backticks rather than double quotes. (It accepts double
  // quotes only when the ANSI_QUOTES SQL mode is enabled, which is not the
  // default, so backticks are the portable choice here.)
  @override
  String id(String raw) => '`$raw`';

  // MariaDB supports switching databases after connecting. The DSN already
  // selects one, so this is only exercised by the concurrent-cursor test.
  @override
  String? useDatabase(String database) => 'USE ${id(database)}';

  @override
  Object? dateParam(DateTime value) => value;

  @override
  String sql(Sql key) => switch (key) {
        Sql.selectAllUsers => 'SELECT * FROM `USERS`',
        Sql.selectAllUsersTerminated => 'SELECT * FROM `USERS`;',
        Sql.selectUserNameById => 'SELECT `NAME` FROM `USERS` WHERE `UID` = ?',
        Sql.selectUserNameAndDescriptionById =>
          'SELECT `NAME`, `DESCRIPTION` FROM `USERS` WHERE `UID` = ?',
        Sql.selectUserDescriptionById =>
          'SELECT `DESCRIPTION` FROM `USERS` WHERE `UID` = ?',
        Sql.selectUsersByBirthday =>
          'SELECT * FROM `USERS` WHERE `BIRTHDAY` = ?',
        Sql.deleteUserById => 'DELETE FROM `USERS` WHERE `UID` = ?',
        Sql.insertUser =>
          'INSERT INTO `USERS` (`UID`, `NAME`, `DESCRIPTION`) VALUES (?, ?, ?)',
        Sql.updateUserDescriptionById =>
          'UPDATE `USERS` SET `DESCRIPTION` = ? WHERE `UID` = ?',
        Sql.selectBinaryDataById =>
          'SELECT `DATA` FROM `BINARY_TABLE` WHERE `ID` = ?',
        // MariaDB's version() is only ~22 chars, far short of the 4096 byte
        // buffer this test exists to overflow. Repeating it 500 times gives
        // ~11,500 characters.
        Sql.selectLongText =>
          "SELECT REPEAT(CONCAT(version(), ' '), 500) AS version",
        Sql.echoParameter => 'SELECT ? AS index_value',
        Sql.selectFromMissingTable => 'SELECT * FROM `DOES_NOT_EXIST`',
      };
}
