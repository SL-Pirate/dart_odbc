import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_odbc/dart_odbc.dart';
import 'package:dart_odbc/src/libodbcext.dart';
import 'package:ffi/ffi.dart';

/// Discover and load the ODBC driver library based on the provided path or
/// the operating system's default library name.
/// If `pathToDriver` is provided, it attempts to load the library from that path.
/// Otherwise, it uses the default library names for Linux, Windows, and macOS.
/// Throws an [ODBCException] if the library cannot be found.
LibOdbcExt discoverDriver(String? pathToDriver) {
  if (pathToDriver != null) {
    return LibOdbcExt(DynamicLibrary.open(pathToDriver));
  } else {
    if (Platform.isLinux) {
      return LibOdbcExt(DynamicLibrary.open('libodbc.so'));
    } else if (Platform.isWindows) {
      return LibOdbcExt(DynamicLibrary.open('odbc32.dll'));
    } else if (Platform.isMacOS) {
      return LibOdbcExt(DynamicLibrary.open('libodbc.dylib'));
    }

    throw ODBCException('ODBC driver not found');
  }
}

/// This class contains the conversion techniques required by odbc
/// to interact with the native code via ffi layer
class OdbcConversions {
  /// Function to get the C type from a Dart type
  static int getCtypeFromType(Type type) {
    if (type == int) {
      return SQL_C_SLONG;
    } else if (type == double) {
      return SQL_C_DOUBLE;
    } else if (type == String) {
      return SQL_C_WCHAR;
    } else if (type == bool) {
      return SQL_C_BIT;
    } else if (type == DateTime) {
      return SQL_C_TYPE_TIMESTAMP;
    } else if (type == List) {
      return SQL_C_BINARY;
    } else if (type == Null) {
      return SQL_C_DEFAULT;
    } else {
      throw Exception('Unsupported type');
    }
  }

  /// Function to get the SQL type from a Dart type
  static int getSqlTypeFromType(Type type) {
    if (type == int) {
      return SQL_INTEGER;
    } else if (type == double) {
      return SQL_DOUBLE;
    } else if (type == String) {
      return SQL_WVARCHAR;
    } else if (type == bool) {
      return SQL_BIT;
    } else if (type == DateTime) {
      return SQL_TYPE_TIMESTAMP;
    } else if (type == List) {
      return SQL_BINARY;
    } else if (type == Null) {
      return SQL_DEFAULT;
    } else {
      throw Exception('Unsupported type');
    }
  }

  /// Convert dart type to a pointer
  static OdbcPointer<dynamic> toPointer(dynamic value) {
    if (value is String) {
      final result = value.toNativeUtf16();
      return OdbcPointer<Utf16>(
        result.cast(),
        result.length * sizeOf<Uint16>(),
        value: value,
      );
    } else if (value is int) {
      final result = calloc.allocate<Int>(sizeOf<Int>())..value = value;
      return OdbcPointer<Int>(result.cast(), sizeOf<Int>(), value: value);
    } else if (value is double) {
      final result = calloc.allocate<Double>(sizeOf<Double>())..value = value;
      return OdbcPointer<Double>(result.cast(), sizeOf<Double>(), value: value);
    } else if (value is bool) {
      // Allocate memory for a single byte (bool is typically 1 byte)
      final result = calloc.allocate<Uint8>(1)..value = value ? 1 : 0;
      return OdbcPointer<Uint8>(result.cast(), 1, value: value);
    } else {
      throw Exception('Unsupported data type: ${value.runtimeType}');
    }
  }

  /// Convert a hex string to a Uint8List
  @Deprecated('This method is no longer in use '
      'and will be removed in future versions. '
      'Furthermore, it silently truncates invalid hex input '
      'instead of throwing an error, making it unreliable for production use.')
  static Uint8List hexToUint8List(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final couple = hex.substring(i, i + 2);
      if (couple.length != 2 || !RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(couple)) {
        break;
      }
      final byte = int.parse(couple, radix: 16);
      bytes.add(byte);
    }

    return Uint8List.fromList(bytes);
  }
}

/// A model that will be used to return the response of to pointer method
class OdbcPointer<T> {
  /// constructor
  OdbcPointer(this.ptr, this.length, {this.value});

  /// frees memory from the pointer
  void free() {
    calloc.free(ptr);
  }

  /// Original value
  dynamic value;

  /// Resulting pointer
  Pointer<Void> ptr;

  /// size of the pointer
  int length;

  /// get the dart type of the pointer
  Type get type => T.runtimeType;
}

/// A model that will be used to configure the column type
class ColumnType {
  /// constructor
  ColumnType({this.type, this.size});

  /// SQL type
  /// This can be any of the constants defined in the LibOdbc class
  /// that start with SQL_C.
  final int? type;

  /// Size (in bytes) of the buffer used when fetching this column.
  ///
  /// This controls the chunk size passed to SQLGetData. Larger values may
  /// reduce the number of driver calls for large columns at the cost of
  /// increased memory usage.
  ///
  /// If null, [defaultBufferSize] is used.
  ///
  /// Note: This does not cap the total size of the fetched value.
  @Deprecated('This will not be used anymore and the buffer size will be '
      'always be set to defaultBufferSize'
      ' This is to improve performance'
      ' when allocating memory for fetching data.')
  final int? size;

  /// Check if the column type is a binary type
  bool isBinary() {
    return type == SQL_BINARY ||
        type == SQL_VARBINARY ||
        type == SQL_LONGVARBINARY;
  }
}

/// default Buffer size (match OS page size)
const defaultBufferSize = 4096;
