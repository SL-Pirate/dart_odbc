import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:path/path.dart' as p;
import 'package:dart_odbc/dart_odbc.dart';

Future<void> main(List<String> args) async {
  await run(args);
}

Future<void> run(List<String> args) async {
  // Load environment variables
  final env = DotEnv()..load(['.env']);

  final driverName = env['DRIVER_NAME']!;
  final pathToFile = env['PATH_TO_FILE']!;

  // Resolve file path (must exist on disk)
  final resolvedPath = await _resolveFilePath(pathToFile);

  final connStr = "DRIVER={$driverName};DBQ=$resolvedPath;";
  final odbc = DartOdbc();

  try {
    await odbc.connectWithConnectionString(connStr);
    await _getAndPrintSheetsWithData(odbc);
  } catch (e) {
    stderr.writeln("Error: $e");
  } finally {
    await odbc.disconnect();
  }
}

// Handles retrieving and printing sheets and rows
Future<void> _getAndPrintSheetsWithData(DartOdbc odbc) async {
  stdout.writeln("Retrieving sheets...");
  final sheets = await odbc.getTables();

  if (sheets.isEmpty) {
    stdout.writeln("No sheets found.");
    return;
  }

  stdout.writeln("Sheets found:");
  for (final sheet in sheets) {
    _printPrettyJson(sheet);
  }

  final sheetNames = sheets
      .map((sheet) => sheet["TABLE_NAME"] as String)
      .toList();

  for (final sheet in sheetNames) {
    stdout.writeln("\n\nSheet $sheet:");
    await _getAndPrintSheetData(odbc, sheet);
  }
}

// Fetch and print rows from a sheet
Future<void> _getAndPrintSheetData(DartOdbc odbc, String sheet) async {
  final rows = await odbc.execute("SELECT * FROM [$sheet]");

  if (rows.isEmpty) {
    stdout.writeln("No data in sheet: $sheet");
    return;
  }

  for (final row in rows) {
    _printPrettyJson(row);
  }
}

// Resolve file path for console apps
Future<String> _resolveFilePath(String path) async {
  final file = File(path);

  if (!file.existsSync()) {
    throw FileSystemException("Database file not found", p.absolute(path));
  }

  return file.absolute.path;
}

// Pretty print JSON data
void _printPrettyJson(Map<String, dynamic> jsonData) {
  final encoder = JsonEncoder.withIndent('  ');
  final prettyPrint = encoder.convert(jsonData);
  stdout.writeln(prettyPrint);
}
