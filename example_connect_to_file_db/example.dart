import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:dart_odbc/dart_odbc.dart';

void main(List<String> args) {
  run(args);
}

Future<void> run(List<String> args) async {
  // loading variable from env
  final DotEnv env = DotEnv()..load(['.env']);

  // Path to the ODBC driver
  // This can be found in the ODBC driver manager
  // In windows this is a '.dll' file that is there in the installation folder of the ODBC driver
  // in linux this has an extension of '.so' (shared library)
  // In macos this should have an extension of '.dylib'
  final pathToDriver = env['PATH_TO_DRIVER']!;
  final driverName = env['DRIVER_NAME']!;
  final pathToFile = env['PATH_TO_FILE']!;

  // Load file if it's from assets, otherwise use provided path
  final pathOfLoadedFile = pathToFile.startsWith("assets/")
      ? await _loadAssetAndReturnPath(pathToFile)
      : pathToFile;

  final connStr = "DRIVER={$driverName};DBQ=$pathOfLoadedFile;";
  final odbc = DartOdbc(pathToDriver);

  try {
    await odbc.connectWithConnectionString(connStr);
    await _getAndPrintSheetsWithData(odbc);
  } catch (ex) {
    print("Error: $ex");
  } finally {
    await odbc.disconnect();
  }
}

// Handles retrieving and printing sheets and rows
Future<void> _getAndPrintSheetsWithData(DartOdbc odbc) async {
  print("Retrieving sheets...");
  final sheets = await odbc.getTables();

  if (sheets.isEmpty) {
    print("No sheets found.");
    return;
  }

  print("Sheets found:");
  for (var sheet in sheets) {
    _printPrettyJson(sheet);
  }

  // Extract sheet names
  final sheetNames =
      sheets.map((sheet) => sheet["TABLE_NAME"] as String).toList();

  for (var sheet in sheetNames) {
    print("\n\nSheet $sheet:");
    await _getAndPrintSheetData(odbc, sheet);
  }
}

// Fetch and print rows from a sheet
Future<void> _getAndPrintSheetData(DartOdbc odbc, String sheet) async {
  final rows = await odbc.execute("SELECT * FROM [$sheet]");

  if (rows.isEmpty) {
    print("No data in sheet: $sheet");
    return;
  }

  for (var row in rows) {
    _printPrettyJson(row);
  }
}

// Load asset and return path for non-web platforms
Future<String> _loadAssetAndReturnPath(String path) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final byteData = await rootBundle.load(path);
    final tempDir = await getTemporaryDirectory();
    final tempFilePath = p.join(tempDir.path, path.substring("assets/".length));
    final tempFile = File(tempFilePath);
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());

    return tempFile.path;
  } catch (error) {
    print("Unable to load asset '$path'. Using the original path.");
    return path;
  }
}

// Pretty print JSON data
void _printPrettyJson(Map<String, dynamic> jsonData) {
  final encoder = JsonEncoder.withIndent('  ');
  final prettyPrint = encoder.convert(jsonData);
  debugPrint(prettyPrint);
}
