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
    return _OdbcCursorImpl(
      odbc: this,
      hStmt: hStmt,
      bufferSize: _bufferSize,
      maxBufferSize: _maxBufferSize,
      enableAdaptiveBuffer: _enableAdaptiveBuffer,
    );
  }
}

/// Implementation of the [OdbcCursor] interface.
class _OdbcCursorImpl implements OdbcCursor {
  /// Constructor
  /// This constructor can throw [ODBCException] if there is an error
  /// while fetching the result set metadata.
  _OdbcCursorImpl({
    required this.odbc,
    required this.hStmt,
    required this.bufferSize,
    required this.maxBufferSize,
    required this.enableAdaptiveBuffer,
  })  : sql = odbc._sql,
        tryOdbc = odbc._tryOdbc,
        currentBufferSize = bufferSize,
        buf = calloc.allocate(bufferSize) {
    tryOdbc(
      sql.SQLNumResultCols(hStmt, pColumnCount),
      handle: hStmt,
      onException: FetchException(),
      beforeThrow: _close,
    );

    // allocating memory for column names
    // outside the loop to reduce overhead in memory allocation
    // Use fixed buffer size for column names to avoid HY090 with large
    // bufferSize
    final pColumnNameLength = calloc<SQLSMALLINT>();
    final pColumnName = calloc<Uint16>(columnNameBufferChars);
    final pDataType = calloc<SQLSMALLINT>();

    for (var i = 1; i <= pColumnCount.value; i++) {
      tryOdbc(
        sql.SQLDescribeColW(
          hStmt,
          i,
          pColumnName.cast(),
          columnNameBufferChars,
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
  final int bufferSize;
  final int maxBufferSize;
  final bool enableAdaptiveBuffer;
  int currentBufferSize;

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
  Pointer<Void> buf;

  // Track buffer expansions to prevent infinite loops
  int _expansionCount = 0;
  static const int _maxExpansions = 10;

  @override
  Future<void> close() async {
    _close();
  }

  void _expandBuffer() {
    // Don't expand if adaptive buffer is disabled
    if (!enableAdaptiveBuffer) return;

    // Don't expand if already at maximum
    if (currentBufferSize >= maxBufferSize) {
      odbc._log.warning(
        'Buffer expansion requested but already at maximum size: '
        '$currentBufferSize bytes (max: $maxBufferSize)',
      );
      return;
    }

    // Check expansion limit to prevent infinite loops
    _expansionCount++;
    if (_expansionCount > _maxExpansions) {
      odbc._log.severe(
        'Maximum buffer expansion limit reached ($_maxExpansions). '
        'This may indicate data corruption or a driver issue.',
      );
      throw FetchException()
        ..message = 'Buffer expansion limit exceeded'
        ..code = -1;
    }

    // Gradual expansion: add 8KB at a time instead of doubling
    // This avoids excessive memory allocation
    final oldSize = currentBufferSize;
    const incrementSize = 8192; // 8KB
    final newSize = (currentBufferSize + incrementSize).clamp(0, maxBufferSize);

    if (newSize <= currentBufferSize) return;

    // Free old buffer
    calloc.free(buf);
    buf = nullptr; // Protection: mark as null before allocating new one

    // Allocate new larger buffer (may throw exception if it fails)
    try {
      buf = calloc.allocate(newSize);
      currentBufferSize = newSize;
      odbc._log.fine(
        'Buffer expanded from $oldSize to $newSize bytes '
        '(expansion $_expansionCount/$_maxExpansions)',
      );
    } catch (e) {
      // If allocation fails, cursor is in invalid state
      // Rethrow exception so caller can handle it
      odbc._log.severe('Failed to allocate expanded buffer: $newSize bytes', e);
      rethrow;
    }
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

    // Case 1: No more data (normal end of result set)
    if (rc == SQL_NO_DATA) {
      _close();
      return const CursorDone();
    }

    // Case 2: Error (rc < 0)
    // Note: Some ODBC drivers put the statement handle in an invalid state
    // when SQLFetch fails (SQL_ERROR, SQL_INVALID_HANDLE, etc.), making it
    // unsafe to call SQLGetDiagRec. We log the error and close gracefully.
    if (rc < 0) {
      odbc._log.warning(
        'SQLFetch returned error code $rc. Closing cursor. '
        'This may indicate data corruption, driver issue, or query timeout.',
      );
      _close();
      return const CursorDone();
    }

    // Case 3: Success (rc >= 0, including SQL_SUCCESS_WITH_INFO)
    // Process row normally (code continues below)

    final row = <String, dynamic>{};
    for (var i = 1; i <= pColumnCount.value; i++) {
      // Check if cursor is still open before reading each column
      // This prevents issues in concurrent scenarios where cursor might
      // be closed by another operation
      if (!_isOpen()) {
        odbc._log.warning(
          'Cursor closed unexpectedly while reading column $i. '
          'This may indicate a concurrency issue.',
        );
        return const CursorDone();
      }

      final columnType = columnTypes[columnNames[i - 1]];

      if (columnType != null && isSQLTypeBinary(columnType)) {
        // incremental read for binary data
        final collected = <int>[];
        var expansionAttempts = 0;
        const maxExpansionAttempts = 10; // Safety limit

        while (true) {
          try {
            final status = tryOdbc(
              sql.SQLGetData(
                hStmt,
                i,
                SQL_C_BINARY,
                buf.cast(),
                currentBufferSize, // Use dynamic currentBufferSize
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
                ? currentBufferSize
                : (returnedBytes ~/ sizeOf<Uint8>())
                    .clamp(0, currentBufferSize);

            if (unitsReturned > 0) {
              collected.addAll(buf.cast<Uint8>().asTypedList(unitsReturned));
            }

            if (status == SQL_SUCCESS) {
              break;
            }
          } on ODBCException catch (e) {
            // Handle SQL_INVALID_HANDLE (-2) which can occur in
            // concurrent scenarios
            if (e.code == -2) {
              odbc._log.warning(
                'SQL_INVALID_HANDLE (-2) detected for column $i. '
                'This typically indicates a concurrency issue. Closing cursor.',
              );
              // Cursor already closed by beforeThrow, just return
              return const CursorDone();
            }

            // Detect HY090 (invalid buffer)
            if (e.sqlState == 'HY090' && enableAdaptiveBuffer) {
              if (expansionAttempts >= maxExpansionAttempts) {
                odbc._log.warning(
                  'Max expansion attempts ($maxExpansionAttempts) reached '
                  'for column $i',
                );
                rethrow; // Rethrow error after many attempts
              }

              final oldSize = currentBufferSize;
              _expandBuffer();
              expansionAttempts++;

              // If didn't expand (reached maximum), rethrow error
              if (currentBufferSize == oldSize) {
                odbc._log.warning(
                  'Buffer expansion failed: already at maximum size '
                  '($currentBufferSize)',
                );
                rethrow;
              }

              // Continue loop to retry with larger buffer
              continue;
            }
            // Other errors: rethrow
            rethrow;
          }
        }

        if (collected.isEmpty) {
          row[columnNames[i - 1]] = null;
        } else {
          row[columnNames[i - 1]] = Uint8List.fromList(collected);
        }
      } else if (columnType != null && isSQLTypeDateTime(columnType)) {
        final timestampBuffer = calloc<tagTIMESTAMP_STRUCT>();

        try {
          tryOdbc(
            sql.SQLGetData(
              hStmt,
              i,
              SQL_C_TYPE_TIMESTAMP,
              timestampBuffer.cast(),
              sizeOf<tagTIMESTAMP_STRUCT>(),
              pColumnValueLength,
            ),
            handle: hStmt,
            onException: FetchException(),
            beforeThrow: () {
              calloc.free(timestampBuffer);
              _close();
            },
          );

          if (pColumnValueLength.value == SQL_NULL_DATA) {
            row[columnNames[i - 1]] = null;
          } else {
            row[columnNames[i - 1]] = fromTimestampValue(timestampBuffer.ref);
          }
        } finally {
          calloc.free(timestampBuffer);
        }
      } else {
        final collectedUnits = <int>[];

        // incremental read for wide char (UTF-16) data
        // Recalculate unitBuf and bufBytes with currentBufferSize (dynamic)
        var expansionAttempts = 0;
        const maxExpansionAttempts = 10;

        while (true) {
          // Recalculate on each iteration (may have expanded)
          final unitBuf = currentBufferSize ~/ sizeOf<Uint16>();
          final bufBytes = unitBuf * sizeOf<Uint16>();

          try {
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
                : (returnedBytes ~/ sizeOf<Uint16>())
                    .clamp(0, maxUnitsInBuffer);

            if (unitsReturned > 0) {
              collectedUnits
                  .addAll(buf.cast<Uint16>().asTypedList(unitsReturned));
            }

            if (status == SQL_SUCCESS) {
              break;
            }
          } on ODBCException catch (e) {
            // Handle SQL_INVALID_HANDLE (-2) which can occur in
            // concurrent scenarios
            if (e.code == -2) {
              odbc._log.warning(
                'SQL_INVALID_HANDLE (-2) detected for column $i. '
                'This typically indicates a concurrency issue. '
                'Closing cursor.',
              );
              // Cursor already closed by beforeThrow, just return
              return const CursorDone();
            }

            if (e.sqlState == 'HY090' && enableAdaptiveBuffer) {
              if (expansionAttempts >= maxExpansionAttempts) {
                odbc._log.warning(
                  'Max expansion attempts ($maxExpansionAttempts) reached '
                  'for column $i',
                );
                rethrow;
              }
              final oldSize = currentBufferSize;
              _expandBuffer();
              expansionAttempts++;
              if (currentBufferSize == oldSize) {
                odbc._log.warning(
                  'Buffer expansion failed: already at maximum size '
                  '($currentBufferSize)',
                );
                rethrow;
              }
              continue; // Retry with new buffer
            }
            rethrow;
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
