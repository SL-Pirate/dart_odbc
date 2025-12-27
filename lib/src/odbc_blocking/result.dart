part of 'base.dart';

extension on DartOdbcBlockingClient {
  Future<List<Map<String, dynamic>>> _getResultBulk(SQLHSTMT hStmt) async {
    final rows = <Map<String, dynamic>>[];
    final cursor = _getResult(hStmt);

    try {
      while (true) {
        final row = await cursor.next();
        if (row is CursorDone) {
          break;
        }

        rows.add((row as CursorItem).value);
      }
    } finally {
      await cursor.close();
    }

    return rows;
  }

  OdbcCursor _getResult(SQLHSTMT hStmt) {
    return _OdbcCursorImpl(odbc: this, hStmt: hStmt);
  }
}

/// Implementation of the [OdbcCursor] interface.
class _OdbcCursorImpl implements OdbcCursor {
  /// Constructor
  /// This constructor can throw [ODBCException] if there is an error
  /// while fetching the result set metadata.
  _OdbcCursorImpl({required this.odbc, required this.hStmt})
      : sql = odbc._sql,
        tryOdbc = odbc._tryOdbc {
    tryOdbc(
      sql.SQLNumResultCols(hStmt, pColumnCount),
      handle: hStmt,
      onException: FetchException(),
      beforeThrow: _close,
    );

    final columnNameCharSize = defaultBufferSize ~/ sizeOf<Uint16>();
    // allocating memory for column names
    // outside the loop to reduce overhead in memory allocation
    final pColumnNameLength = calloc<SQLSMALLINT>();
    final pColumnName = calloc<Uint16>(columnNameCharSize);
    final pDataType = calloc<SQLSMALLINT>();

    for (var i = 1; i <= pColumnCount.value; i++) {
      tryOdbc(
        sql.SQLDescribeColW(
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
            ..free(pDataType);

          _close();
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
  }

  final DartOdbcBlockingClient odbc;
  SQLHSTMT hStmt;

  final LibOdbc sql;
  final int Function(
    int status, {
    SQLHANDLE? handle,
    int operationType,
    void Function()? beforeThrow,
    ODBCException? onException,
  }) tryOdbc;

  final columnNames = <String>[];
  final columnTypes = <String, int>{};

  // pointers
  Pointer<SQLSMALLINT> pColumnCount = calloc<SQLSMALLINT>();
  Pointer<SQLLEN> pColumnValueLength = calloc<SQLLEN>();
  Pointer<Void> buf = calloc.allocate(defaultBufferSize);

  @override
  Future<void> close() async {
    _close();
  }

  void _close() {
    // free memory
    calloc
      ..free(buf)
      ..free(pColumnCount)
      ..free(pColumnValueLength);

    buf = nullptr;
    pColumnCount = nullptr;
    pColumnValueLength = nullptr;

    if (hStmt != nullptr) {
      odbc._freeSqlStmtHandle(hStmt);
      hStmt = nullptr;
    }
  }

  bool _isOpen() =>
      buf != nullptr &&
      pColumnCount != nullptr &&
      pColumnValueLength != nullptr;

  @override
  Future<CursorResult> next() async {
    if (!_isOpen()) {
      return const CursorDone();
    }

    final rc = sql.SQLFetch(hStmt);
    if (rc < 0 || rc == SQL_NO_DATA) {
      // implicit close on done or error
      _close();
      return const CursorDone();
    }

    final row = <String, dynamic>{};
    for (var i = 1; i <= pColumnCount.value; i++) {
      final columnType = columnTypes[columnNames[i - 1]];

      if (columnType != null && isSQLTypeBinary(columnType)) {
        // incremental read for binary data
        final collected = <int>[];

        while (true) {
          final status = tryOdbc(
            sql.SQLGetData(
              hStmt,
              i,
              SQL_C_BINARY,
              buf.cast(),
              defaultBufferSize,
              pColumnValueLength,
            ),
            handle: hStmt,
            onException: FetchException(),
            beforeThrow: _close,
          );

          if (pColumnValueLength.value == SQL_NULL_DATA) {
            // null column
            break;
          }

          final returnedBytes = pColumnValueLength.value;
          final unitsReturned = returnedBytes == SQL_NO_TOTAL
              ? defaultBufferSize
              : (returnedBytes ~/ sizeOf<Uint8>()).clamp(0, defaultBufferSize);

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
            sql.SQLGetData(
              hStmt,
              i,
              SQL_WCHAR,
              buf.cast(),
              bufBytes,
              pColumnValueLength,
            ),
            handle: hStmt,
            onException: FetchException(),
            beforeThrow: _close,
          );

          if (pColumnValueLength.value == SQL_NULL_DATA) {
            // null column
            break;
          }

          final returnedBytes = pColumnValueLength.value;
          final maxUnitsInBuffer = unitBuf;

          final unitsReturned = returnedBytes == SQL_NO_TOTAL
              ? maxUnitsInBuffer
              : (returnedBytes ~/ sizeOf<Uint16>()).clamp(0, maxUnitsInBuffer);

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

    return CursorItem(row);
  }
}
