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

  // Path to the ODBC driver
  // This can be found in the ODBC driver manager
  // In windows this is a '.dll' file that is there in the installation folder of the ODBC driver
  // in linux this has an extension of '.so' (shared library)
  // In macos this should have an extension of '.dylib'
  // final pathToDriver = env['PATH_TO_DRIVER'];

  // This is the name you gave when setting up the driver manager
  // For more information, visit https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-driver-manager.html
  final dsn = env['DSN'];

  // optionally to select database
  final db = env['DATABASE'];

  final odbc = DartOdbc(dsn: dsn);
  await odbc.connect(
    username: username!,
    password: password!,
  );

  if (db != null) {
    await odbc.execute('USE $db');
  }

  List<Map<String, dynamic>> result = await odbc.execute(
    args[0], //  <-- SQL query
    params: args.sublist(1), // <-- SQL query parameters
    columnConfig: {
      "COL1": ColumnType(size: 100),
    },
  );

  print(result);

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
  //     'NAME': ColumnType(size: 150),
  //     'DESCRIPTION': ColumnType(type: SQL_C_WCHAR, size: 500),
  //   },
  // );

  // finally disconnect from the db
  await odbc.disconnect();
}
