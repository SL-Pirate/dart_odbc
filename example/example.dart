import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';

void main(List<String> args) {
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
  final pathToDriver = env['PATH_TO_DRIVER'];

  // This is the name you gave when setting up the driver manager
  // For more information, visit https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-driver-manager.html
  final dsn = env['DSN'];

  // optionally to select database
  final db = env['DATABASE'];

  final odbc = DartOdbc(pathToDriver!);
  odbc.connect(
    dsn: dsn!,
    username: username!,
    password: password!,
  );

  if (db != null) {
    odbc.execute('USE $db');
  }

  List result = [];

  result.add(
    odbc.execute(
      args[0],
      params: args.sublist(1),
    ),
  );

  print(result);
}
