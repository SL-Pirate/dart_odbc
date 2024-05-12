import 'package:dart_odbc/dart_odbc.dart';
import 'package:dotenv/dotenv.dart';

void main(List<String> args) {
  final DotEnv env = DotEnv()..load(['.env']);
  final odbc = DartOdbc(env['PATH_TO_DRIVER']!);
  odbc.connect(
    dsn: env['DSN']!,
    username: env['USERNAME']!,
    password: env['PASSWORD']!,
  );

  if (env['DATABASE'] != null) {
    odbc.execute('USE ${env['DATABASE']}');
  }
  print(odbc.execute(args.firstOrNull ?? "SELECT 10"));
}
