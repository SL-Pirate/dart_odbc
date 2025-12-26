part of './base.dart';

extension on DartOdbc {
  List<Map<String, dynamic>> _getResult(SQLHSTMT hStmt) {
    final pColumnCount = calloc<SQLSMALLINT>();
    tryOdbc(
      _sql.SQLNumResultCols(hStmt, pColumnCount),
      handle: hStmt,
      onException: FetchException(),
      beforeThrow: () {
        calloc.free(pColumnCount);
      },
    );

    final columnNameCharSize = defaultBufferSize ~/ sizeOf<Uint16>();
    // allocating memory for column names
    // outside the loop to reduce overhead in memory allocation
    final pColumnNameLength = calloc<SQLSMALLINT>();
    final pColumnName = calloc<Uint16>(columnNameCharSize);
    final pDataType = calloc<SQLSMALLINT>();
    final columnNames = <String>[];
    final columnTypes = <String, int>{};

    for (var i = 1; i <= pColumnCount.value; i++) {
      tryOdbc(
        _sql.SQLDescribeColW(
          hStmt,
          i,
          pColumnName.cast(),
          columnNameCharSize,
          pColumnNameLength,
          pDataType,
          nullptr,
          nullptr,
          nullptr,
        ),
        handle: hStmt,
        onException: FetchException(),
        beforeThrow: () {
          calloc
            ..free(pColumnName)
            ..free(pColumnNameLength)
            ..free(pDataType)
            ..free(pColumnCount);
        },
      );
      final columnName = pColumnName
          .cast<Utf16>()
          .toDartString(length: pColumnNameLength.value);
      columnNames.add(columnName);
      columnTypes[columnName] = pDataType.value;
    }

    // free memory
    calloc
      ..free(pColumnName)
      ..free(pDataType)
      ..free(pColumnNameLength);

    final rows = <Map<String, dynamic>>[];

    // keeping outside the loop to reduce overhead in memory allocation
    final pColumnValueLength = calloc<SQLLEN>();
    final buf = calloc.allocate(defaultBufferSize);

    while (true) {
      final rc = _sql.SQLFetch(hStmt);
      if (rc < 0 || rc == SQL_NO_DATA) break;

      final row = <String, dynamic>{};
      for (var i = 1; i <= pColumnCount.value; i++) {
        final columnType = columnTypes[columnNames[i - 1]];

        if (columnType != null && isSQLTypeBinary(columnType)) {
          // incremental read for binary data
          final collected = <int>[];

          while (true) {
            final status = tryOdbc(
              _sql.SQLGetData(
                hStmt,
                i,
                SQL_C_BINARY,
                buf.cast(),
                defaultBufferSize,
                pColumnValueLength,
              ),
              handle: hStmt,
              onException: FetchException(),
              beforeThrow: () {
                calloc
                  ..free(buf)
                  ..free(pColumnValueLength)
                  ..free(pColumnCount);
              },
            );

            if (pColumnValueLength.value == SQL_NULL_DATA) {
              // null column
              break;
            }

            final returnedBytes = pColumnValueLength.value;
            final unitsReturned = returnedBytes == SQL_NO_TOTAL
                ? defaultBufferSize
                : (returnedBytes ~/ sizeOf<Uint8>())
                    .clamp(0, defaultBufferSize);

            if (unitsReturned > 0) {
              collected.addAll(buf.cast<Uint8>().asTypedList(unitsReturned));
            }

            if (status == SQL_SUCCESS) {
              break;
            }
          }

          if (collected.isEmpty) {
            row[columnNames[i - 1]] = null;
          } else {
            row[columnNames[i - 1]] = Uint8List.fromList(collected);
          }
        } else {
          final collectedUnits = <int>[];

          // incremental read for wide char (UTF-16) data
          final unitBuf = defaultBufferSize ~/ sizeOf<Uint16>();
          final bufBytes = unitBuf * sizeOf<Uint16>();

          while (true) {
            final status = tryOdbc(
              _sql.SQLGetData(
                hStmt,
                i,
                SQL_WCHAR,
                buf.cast(),
                bufBytes,
                pColumnValueLength,
              ),
              handle: hStmt,
              onException: FetchException(),
              beforeThrow: () {
                calloc
                  ..free(buf)
                  ..free(pColumnValueLength)
                  ..free(pColumnCount);
              },
            );

            if (pColumnValueLength.value == SQL_NULL_DATA) {
              // null column
              break;
            }

            final returnedBytes = pColumnValueLength.value;
            final maxUnitsInBuffer = unitBuf;

            final unitsReturned = returnedBytes == SQL_NO_TOTAL
                ? maxUnitsInBuffer
                : (returnedBytes ~/ sizeOf<Uint16>())
                    .clamp(0, maxUnitsInBuffer);

            if (unitsReturned > 0) {
              collectedUnits
                  .addAll(buf.cast<Uint16>().asTypedList(unitsReturned));
            }

            if (status == SQL_SUCCESS) {
              break;
            }
          }

          if (collectedUnits.isEmpty) {
            row[columnNames[i - 1]] = null;
          } else {
            collectedUnits.removeWhere((e) => e == 0);
            row[columnNames[i - 1]] = String.fromCharCodes(collectedUnits);
          }
        }
      }

      rows.add(row);
    }

    // free memory
    calloc
      ..free(buf)
      ..free(pColumnCount)
      ..free(pColumnValueLength);

    return rows;
  }
}
