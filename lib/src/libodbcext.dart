//
// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';

import 'package:dart_odbc/dart_odbc.dart';
import 'package:logging/logging.dart';

///
class LibOdbcExt extends LibOdbc {
  ///
  LibOdbcExt(super.dynamicLibrary);

  final _log = Logger('LibOdbcExt');

  @override
  int SQLAllocHandle(
    int HandleType,
    SQLHANDLE InputHandle,
    Pointer<SQLHANDLE> OutputHandle,
  ) {
    try {
      return super.SQLAllocHandle(HandleType, InputHandle, OutputHandle);
    } catch (e) {
      _log.severe(
        'Error allocating ODBC handle of type $HandleType!. Trying fallback.',
        e,
      );

      if (HandleType == SQL_HANDLE_DBC) {
        return super.SQLAllocConnect(InputHandle, OutputHandle);
      } else if (HandleType == SQL_HANDLE_ENV) {
        return super.SQLAllocEnv(OutputHandle);
      } else if (HandleType == SQL_HANDLE_STMT) {
        return super.SQLAllocStmt(InputHandle, OutputHandle);
      } else {
        rethrow;
      }
    }
  }
}
