import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';

import 'support/test_database.dart';

class TestHelper {
  TestHelper([IDartOdbc? odbc]) {
    // Loaded in the constructor, not in initialize(): TestHelper(someOdbc) is
    // constructed without ever calling initialize() (see connection_test.dart),
    // and reading `env`/`username`/`password` in that state used to throw a
    // LateInitializationError.
    //
    // includePlatformEnvironment lets configuration arrive as real environment
    // variables; quiet suppresses the "file not found" notice when there is no
    // .env, which is the normal case when env vars are used instead. Values
    // from the file still win, so an existing local .env behaves as before.
    env = DotEnv(includePlatformEnvironment: true, quiet: true)..load(['.env']);

    if (odbc != null) {
      this.odbc = odbc;
    }
  }

  late IDartOdbc odbc;
  late DotEnv env;

  /// SQL dialect of the database under test, selected by `TEST_DB`.
  final TestDatabase dialect = TestDatabase.resolve();

  String? get dsn => env['DSN'];

  String get username => env['USERNAME']!;

  String get password => env['PASSWORD']!;

  String? get database => env['DATABASE'];

  /// Quotes an identifier for the dialect under test.
  String id(String raw) => dialect.id(raw);

  /// Translates a statement key into SQL for the dialect under test.
  String sql(Sql key) => dialect.sql(key);

  /// Runs the statement named by [key] against the dialect under test.
  Future<List<Map<String, dynamic>>> run(
    Sql key, {
    List<dynamic> params = const [],
  }) {
    return exec(dialect.sql(key), params: params);
  }

  /// Opens a cursor over the statement named by [key].
  Future<OdbcCursor> runCursor(
    Sql key, {
    List<dynamic> params = const [],
  }) {
    return cursor(dialect.sql(key), params: params);
  }

  Future<void> initialize() async {
    odbc = DartOdbc(dsn: dsn);
    await connect(
      username: username,
      password: password,
      database: database,
    );
  }

  Future<void> connect({
    required String username,
    required String password,
    String? database,
  }) async {
    await odbc.connect(username: username, password: password);

    // Engines that select the database at connect time return null here.
    if (database != null) {
      final useStatement = dialect.useDatabase(database);
      if (useStatement != null) {
        await odbc.execute(useStatement);
      }
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
}

void main() {}
