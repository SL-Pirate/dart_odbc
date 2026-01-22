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

    final columnNameCharSize = bufferSize ~/ sizeOf<Uint16>();
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

  @override
  Future<void> close() async {
    _close();
  }

  void _expandBuffer() {
    // Não expandir se adaptativo estiver desabilitado
    if (!enableAdaptiveBuffer) return;

    // Não expandir se já atingiu o máximo
    if (currentBufferSize >= maxBufferSize) {
      odbc._log.warning(
        'Buffer expansion requested but already at maximum size: '
        '$currentBufferSize bytes (max: $maxBufferSize)',
      );
      return;
    }

    // Dobrar o tamanho, mas respeitando o máximo
    final oldSize = currentBufferSize;
    final newSize = (currentBufferSize * 2).clamp(0, maxBufferSize);
    if (newSize <= currentBufferSize) return;

    // Liberar buffer antigo
    calloc.free(buf);
    buf = nullptr; // Proteção: marcar como null antes de alocar novo

    // Alocar novo buffer maior (pode lançar exceção se falhar)
    try {
      buf = calloc.allocate(newSize);
      currentBufferSize = newSize;
      odbc._log.fine('Buffer expanded from $oldSize to $newSize bytes');
    } catch (e) {
      // Se alocação falhar, cursor fica em estado inválido
      // Relançar exceção para que caller possa tratar
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
        var expansionAttempts = 0;
        const maxExpansionAttempts = 10; // Limite de segurança

        while (true) {
          try {
            final status = tryOdbc(
              sql.SQLGetData(
                hStmt,
                i,
                SQL_C_BINARY,
                buf.cast(),
                currentBufferSize, // Usar currentBufferSize dinâmico
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
            // Detectar HY090 (buffer inválido)
            if (e.sqlState == 'HY090' && enableAdaptiveBuffer) {
              if (expansionAttempts >= maxExpansionAttempts) {
                odbc._log.warning(
                  'Max expansion attempts ($maxExpansionAttempts) reached '
                  'for column $i',
                );
                rethrow; // Relançar erro após muitas tentativas
              }

              final oldSize = currentBufferSize;
              _expandBuffer();
              expansionAttempts++;

              // Se não expandiu (atingiu máximo), relançar erro
              if (currentBufferSize == oldSize) {
                odbc._log.warning(
                  'Buffer expansion failed: already at maximum size '
                  '($currentBufferSize)',
                );
                rethrow;
              }

              // Continuar loop para retentar com novo buffer maior
              continue;
            }
            // Outros erros: relançar
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
        // Recalcular unitBuf e bufBytes com currentBufferSize (dinâmico)
        var expansionAttempts = 0;
        const maxExpansionAttempts = 10;

        while (true) {
          // Recalcular a cada iteração (pode ter expandido)
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
              continue; // Retentar com novo buffer
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
