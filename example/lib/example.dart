import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';

void main(List<String> args) async {
  try {
    await run(args);
  } on ConnectionException catch (e) {
    // ignore: avoid_print
    print('Connection error: $e');
  } on QueryException catch (e) {
    // ignore: avoid_print
    print('Query error: $e');
  } on FetchException catch (e) {
    // ignore: avoid_print
    print('Fetch error: $e');
  } catch (e) {
    // ignore: avoid_print
    print('Unexpected error: $e');
  }
}

Future<void> run(List<String> args) async {
  // loading variable from env
  final DotEnv env = DotEnv()..load(['.env']);

  // username for the database
  final username = env['USERNAME'];
  // password for the database
  final password = env['PASSWORD'];

  final dsn = env['DSN'];

  // optionally to select database
  final db = env['DATABASE'];

  final odbc = DartOdbc(dsn: dsn);
  await odbc.connect(username: username!, password: password!);

  if (db != null) {
    // Use parameterized query to prevent SQL injection
    // Note: Some databases may not support parameters in USE statement
    // In that case, ensure db value is validated/whitelisted
    await odbc.execute('USE $db');
  }

  // Assume a table like this
  // +-----+-------+-------------+
  // | UID | NAME  | DESCRIPTION |
  // +-----+-------+-------------+
  // | 1   | Alice |             |
  // | 2   | Bob   |             |
  // +-----+-------+-------------+
  // The name is a column of size 150
  // The description is a column of size 500

  // result = odbc.execute(
  //   'SELECT * FROM USERS WHERE UID = ?',
  //   params: [1],
  // );
  // Example with parameterized query (recommended for security)
  // Parameters are validated and properly escaped
  // Supported types: int, double, String, bool, DateTime, Uint8List, null
  List<Map<String, dynamic>> result = await odbc.execute(
    args[0], //  <-- SQL query
    params: args.sublist(1), // <-- SQL query parameters
  );

  // ignore: avoid_print
  print(result);

  // finally disconnect from the db
  await odbc.disconnect();
}
