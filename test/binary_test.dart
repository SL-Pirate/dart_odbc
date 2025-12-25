import 'dart:io';
import 'dart:typed_data';

import 'package:dart_odbc/dart_odbc.dart';
import 'package:open_url/open_url.dart';
import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  final helper = TestHelper();
  final imageFile = File('test.png');

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);
  tearDownAll(() async {
      // Give user time to see it
      await Future<void>.delayed(const Duration(seconds: 10));

      // Cleanup
      await imageFile.delete();
  });

  test(
    'query an image from the database, embed it in html and show it to user',
    () async {
      final imgData = await helper.query(
        'SELECT DATA FROM BINARY_TABLE WHERE ID = 1',
        columnConfig: {
          'DATA': ColumnType(type: SQL_VARBINARY),
        },
      );
      expect(imgData, isNotEmpty);
      expect(imgData.first['DATA'], isA<Uint8List>());

      // Create a Blob from binary data
      final bytes = imgData.first['DATA'] as Uint8List;

      // Write image to disk
      await imageFile.writeAsBytes(bytes);

      await openUrl(imageFile.path);
    },
  );
}
