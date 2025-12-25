import 'dart:io';
import 'package:dart_odbc/dart_odbc.dart';
import 'package:test/test.dart';

Map<String, String> loadDotEnv(String path) {
  final file = File(path);
  final map = <String, String>{};
  if (!file.existsSync()) return map;
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    final key = trimmed.substring(0, idx).trim();
    var value = trimmed.substring(idx + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    map[key] = value;
  }
  return map;
}

void main() {
  test('read long NVARCHAR via incremental SQLGetData (no garbage)', () async {
    final env = loadDotEnv('example/.env');
    final dsn = env['DSN'] ?? '';
    final username = env['USERNAME'] ?? '';
    final password = env['PASSWORD'] ?? '';

    final odbc = DartOdbc(dsn: dsn);
    await odbc.connect(username: username, password: password);

    final rows = await odbc.execute('SELECT @@VERSION AS version');
    expect(rows, isNotEmpty);
    final version = rows[0]['version'] as String?;
    expect(version, isNotNull);
    expect(version!.toLowerCase(), contains('microsoft sql server'));

    // Ensure there are no long runs (>2) of control/non-printable bytes
    final nonPrintable = RegExp(r'[\x00-\x08\x0E-\x1F\x7F-\x9F]{2,}');
    expect(nonPrintable.hasMatch(version), isFalse);

    await odbc.disconnect();
  });
}
