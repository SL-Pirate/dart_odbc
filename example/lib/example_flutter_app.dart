import 'dart:async';

import 'package:dart_odbc/dart_odbc.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'helper.dart'; // Adjust import based on your package export

void main() {
  enableLogging();
  runApp(const MaterialApp(home: OdbcExampleApp()));
}

class OdbcExampleApp extends StatefulWidget {
  const OdbcExampleApp({super.key});

  @override
  State<OdbcExampleApp> createState() => _OdbcExampleAppState();
}

class _OdbcExampleAppState extends State<OdbcExampleApp> {
  // State variables
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _binaryData = [];
  bool _isLoading = false;
  bool _isBlockingClient = false;
  String? _error;

  // The client instance
  final helper = Helper();

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _users = [];
      _binaryData = [];
    });

    // timer would only work if the client is non-blocking
    final counter = _AsyncCounter();
    counter.start();

    try {
      // 1. Connect (This runs in your isolate)
      await helper.initialize(blocking: _isBlockingClient);
      // await _odbc.execute('USE $database');

      // 2. Fetch Users
      // Assuming your execute returns a generic result structure (rows/cols)
      final userResult = await helper.exec("SELECT * FROM USERS");

      // 3. Fetch Binary Data
      final binResult = await helper.exec("SELECT id, data FROM BINARY_TABLE");

      // 4. Update UI
      if (mounted) {
        setState(() {
          // Mapping logic depends on your exact Result object structure.
          // Assuming result is a List/Map or similar iterable.
          _users = userResult;
          _binaryData = binResult;
        });
      }
    } on ConnectionException catch (e) {
      debugPrint('Connection error: $e');
      if (mounted) {
        setState(() => _error = 'Connection error: $e');
      }
    } on QueryException catch (e) {
      debugPrint('Query error: $e');
      if (mounted) {
        setState(() => _error = 'Query error: $e');
      }
    } on FetchException catch (e) {
      debugPrint('Fetch error: $e');
      if (mounted) {
        setState(() => _error = 'Fetch error: $e');
      }
    } catch (e) {
      debugPrint('Unexpected error during ODBC operations: $e');
      if (mounted) {
        setState(() => _error = 'Unexpected error: $e');
      }
    } finally {
      // Clean up connection if needed, or keep it open for the session
      counter.stop();

      if (mounted) {
        setState(() => _isLoading = false);
      }

      helper.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Dart ODBC Isolate Test"),
          actions: [
            Text('Blocking Client: $_isBlockingClient'),
            Switch(
              value: _isBlockingClient,
              onChanged: (value) {
                setState(() {
                  _isBlockingClient = value;
                });
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Control Panel
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchData,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Load Data"),
                  ),
                  const SizedBox(width: 20),
                  if (_isLoading)
                    const Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Querying in background isolate... UI is active!",
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Divider(height: 30),

              // Error Display
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.red.shade100,
                  child: Text(
                    "Error: $_error",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // Data Display
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Users Table (Strings & Dates)"),
                      _buildUsersTable(),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Binary Table (VarBinary)"),
                      _buildBinaryTable(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    helper.disconnect();
    super.dispose();
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildUsersTable() {
    if (_users.isEmpty && !_isLoading) {
      return const Text("No user data loaded.");
    }

    return Card(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('UID')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Birthday')),
          DataColumn(label: Text('Desc')),
        ],
        rows: _users.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row['UID'].toString())),
              DataCell(Text(row['NAME'] ?? '')),
              DataCell(
                Text(row['BIRTHDAY']?.toString() ?? 'N/A'),
              ), // Handling NULL date
              DataCell(
                Text(
                  row['DESCRIPTION'] == null
                      ? 'NULL'
                      : row['DESCRIPTION'].toString(),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBinaryTable() {
    if (_binaryData.isEmpty && !_isLoading) {
      return const Text("No binary data loaded.");
    }

    return Card(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Data (Hex)')),
        ],
        rows: _binaryData.map((row) {
          // Handle the binary data conversion for display
          final dynamic rawData = row['data'];
          String hexDisplay = "Empty";

          if (rawData is List<int>) {
            hexDisplay =
                "0x${rawData.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase()}";
          } else if (rawData != null) {
            hexDisplay = rawData.toString();
          }

          return DataRow(
            cells: [
              DataCell(Text(row['id'].toString())),
              DataCell(
                Text(
                  hexDisplay,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                  ), // Monospace for hex
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// 2. The concrete implementation
class _AsyncCounter {
  Timer? _timer;
  int _currentCount = 0;

  final _log = Logger('Seconds Counter');

  void start() {
    if (_timer != null && _timer!.isActive) return; // Prevent double starting

    // Schedule the _count method to run every 1 second
    _timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
      _count();
    });
  }

  void stop() {
    _timer?.cancel();
    _currentCount = 0;
    _timer = null;
  }

  void _count() {
    _currentCount++;
    _log.info('Count: $_currentCount');
  }
}

void enableLogging() {
  // enable logging
  Logger.root.level = Level.ALL;

  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
      '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      // ignore: avoid_print
      print('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('StackTrace: ${record.stackTrace}');
    }
  });
}
