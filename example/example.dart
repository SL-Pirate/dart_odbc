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

  bool hasParams = args.length > 1;
  List<dynamic>? params;

  List result;

  if (hasParams) {
    params = args.sublist(1);
    result = odbc.execute(args.first, params: params);
  } else {
    result = odbc.execute(args.first);
  }

  print(result);
}
