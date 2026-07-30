import 'package:dart_odbc/dart_odbc.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';
import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);

  tearDownAll(helper.disconnect);

  test('read long text via incremental SQLGetData (no garbage)', () async {
    final rows = await helper.run(Sql.selectLongText);

    expect(rows, isNotEmpty);

    final version = rows[0]['version'] as String?;
    expect(version, isNotNull);

    // The point of this test is the multi-chunk read path, so assert the value
    // actually exceeds one buffer (defaultBufferSize is 4096). A short string
    // would fit in a single SQLGetData call and test nothing.
    expect(version!.length, greaterThan(defaultBufferSize));

    // Garbage from a mis-stitched buffer shows up as replacement characters or
    // embedded NULs at a chunk boundary.
    expect(version, isNot(contains('\u{FFFD}')));
    expect(version, isNot(contains('\u0000')));
  });
}
