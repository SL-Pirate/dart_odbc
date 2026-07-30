import 'dart:io';
import 'dart:typed_data';

import 'package:open_url/open_url.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';
import '../test_helper.dart';

void main() {
  final helper = TestHelper();
  final imageFile = File('test.png');

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);
  tearDownAll(() async {
    if (imageFile.existsSync()) {
      await imageFile.delete();
    }
  });

  test(
    'query binary data from the database and write it to a file',
    () async {
      final imgData = await helper.run(
        Sql.selectBinaryDataById,
        params: [1],
      );
      expect(imgData, isNotEmpty);
      expect(imgData.first['DATA'], isA<Uint8List>());

      final bytes = imgData.first['DATA'] as Uint8List;

      // Write image to disk
      await imageFile.writeAsBytes(bytes);
      expect(imageFile.existsSync(), isTrue);

      // Opening a viewer and waiting for a human is a developer convenience,
      // not an assertion. Gate it so the test runs headless in containers and
      // CI, and does not cost 10 seconds on every run.
      if (Platform.environment['SHOW_TEST_IMAGE'] == '1') {
        await openUrl(imageFile.path);

        // Give user time to see it
        await Future<void>.delayed(const Duration(seconds: 10));
      }
    },
  );
}
