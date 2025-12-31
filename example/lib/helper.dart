import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';

class Helper {
  Helper([IDartOdbc? odbc]) {
    if (odbc != null) {
      this.odbc = odbc;
    }
  }

  final _log = Logger('_Helper');

  late IDartOdbc odbc;
  late DotEnv env;

  String? get dsn => env['DSN'];

  String get username => env['USERNAME']!;

  String get password => env['PASSWORD']!;

  Future<void> initialize({bool blocking = false}) async {
    env = DotEnv()..load(['.env']);
    odbc = blocking ? DartOdbcBlockingClient() : DartOdbc(dsn: dsn);
    _log.info("Initialized ${blocking ? 'blocking' : 'non blocking'} client");

    final connectionString = [
      'DSN=${env['DSN']}',
      'UID=${env['USERNAME']}',
      'PWD=${env['PASSWORD']}',
      if (env['DATABASE'] != null) 'DATABASE=${env['DATABASE']}',
      'Encrypt=no',
      'TrustServerCertificate=yes',
    ].join(';');

    _log.info('Using connection string: $connectionString');

    await odbc.connectWithConnectionString(connectionString);
  }

  Future<void> connect({
    required String username,
    required String password,
    String? database,
  }) async {
    _log.info('Connecting with DSN: $dsn');

    await odbc.connect(username: username, password: password);
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
    return odbc.executeCursor(sql, params: params);
  }

  Future<void> disconnect() async {
    await odbc.disconnect();
  }

  IDartOdbc getOdbc() {
    return odbc;
  }
}

// test entrypoint to test helper
Future<void> main() async {
  final helper = Helper();
  await helper.initialize();
  final userResult = await helper.exec("SELECT * FROM USERS");
  // ignore: avoid_print
  print(userResult);
  await helper.disconnect();
}
