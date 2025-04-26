import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';

void main(List<String> args) {
  run(args);
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

  /// The column config can be provided as this.
  /// But for most cases this config is not necessary
  /// This is only needed when the data fetching is not working as expected
  /// Only the columns with issues need to be provided
  //   columnConfig: {
  //     'IMAGE': ColumnType(type: SQL_BINARY, size: 100),
  //   },
  // );

  List<Map<String, dynamic>> result = await odbc.execute(
    args[0], //  <-- SQL query
    params: args.sublist(1), // <-- SQL query parameters
    columnConfig: {
      "COL1": ColumnType(size: 100),
      'data': ColumnType(type: SQL_VARBINARY, size: 100),
    },
  );

  print(result);

  // finally disconnect from the db
  await odbc.disconnect();
}
