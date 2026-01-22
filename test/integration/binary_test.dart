import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../test_helper.dart';

void main() {
  final helper = TestHelper();
  final imageFile = File('test.png');

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);
  tearDownAll(() async {
    // Cleanup
    if (imageFile.existsSync()) {
      await imageFile.delete();
    }
  });

  test(
    'query an image from the database, embed it in html and show it to user',
    () async {
      final imgData = await helper.exec(
        'SELECT DATA FROM BINARY_TABLE WHERE ID = 1',
      );
      expect(imgData, isNotEmpty);
      expect(imgData.first['DATA'], isA<Uint8List>());

      // Create a Blob from binary data
      final bytes = imgData.first['DATA'] as Uint8List;

      // Write image to disk
      await imageFile.writeAsBytes(bytes);

      // Image is written to disk for verification
      // To view it manually, open test.png in an image viewer
    },
  );
}
