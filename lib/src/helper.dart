import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_odbc/dart_odbc.dart';
import 'package:dart_odbc/src/libodbcext.dart';
import 'package:ffi/ffi.dart';

/// Discover and load the ODBC driver library based on the provided path or
/// the operating system's default library name.
/// If `pathToDriver` is provided,
/// it attempts to load the library from that path.
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
      return SQL_TIMESTAMP;
    } else if (type == List) {
      return SQL_BINARY;
    } else if (type == Null) {
      return SQL_DEFAULT;
    } else {
      throw Exception('Unsupported type');
    }
  }

  /// Function to get the column size from a Dart type
  /// This is used for binding parameters to the statement
  static int getColumnSizeForBindParamsFromType(Type type) {
    if (type == DateTime) {
      return sizeOf<tagTIMESTAMP_STRUCT>();
    }

    return 0;
  }

  /// Function to get the decimal digits from a Dart type
  /// This is used for binding parameters to the statement
  static int getDecimalDigitsFromType(Type type) {
    if (type == double) {
      return 15; // Typical precision for double
    } else if (type == DateTime) {
      return 6;
    }

    return 0;
  }

  /// Convert dart type to a pointer
  static OdbcPointer toPointer(dynamic value) {
    if (value is String) {
      final result = value.toNativeUtf16();
      return OdbcPointer<Utf16>(
        result.cast(),
        result.length * sizeOf<Uint16>(),
        value: value,
      );
    } else if (value is int) {
      final result = calloc<Int>()..value = value;
      return OdbcPointer<Int>(result.cast(), sizeOf<Int>(), value: value);
    } else if (value is double) {
      final result = calloc<Double>()..value = value;
      return OdbcPointer<Double>(result.cast(), sizeOf<Double>(), value: value);
    } else if (value is bool) {
      // Allocate memory for a single byte (bool is typically 1 byte)
      final result = calloc<Uint8>()..value = value ? 1 : 0;
      return OdbcPointer<Uint8>(result.cast(), 1, value: value);
    } else if (value is DateTime) {
      final timestamp = calloc<tagTIMESTAMP_STRUCT>();
      timestamp.ref.year = value.year;
      timestamp.ref.month = value.month;
      timestamp.ref.day = value.day;
      timestamp.ref.hour = value.hour;
      timestamp.ref.minute = value.minute;
      timestamp.ref.second = value.second;
      timestamp.ref.fraction = value.microsecond * 1000; // nanoseconds
      return OdbcPointer<tagTIMESTAMP_STRUCT>(
        timestamp.cast(),
        sizeOf<tagTIMESTAMP_STRUCT>(),
        value: value,
      );
    } else if (value is Uint8List) {
      final result = calloc<Uint8>(value.length);
      result.asTypedList(value.length).setAll(0, value);
      return OdbcPointer<Uint8>(
        result.cast(),
        value.length * sizeOf<Uint8>(),
        value: value,
      );
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
class OdbcPointer<T extends NativeType> {
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

  /// actual size (eg: for strings, number of characters)
  /// If the value is a null, returns SQL_NULL_DATA
  /// If the value is a String or Uint8List, returns the length
  /// Otherwise, returns null (meaning size is not applicable)
  int? get actualSize {
    if (value == null) return SQL_NULL_DATA;

    if (value is String) {
      return (value as String).length * sizeOf<Uint16>();
    }
    if (value is Uint8List) {
      return (value as Uint8List).length * sizeOf<Uint8>();
    } else {
      return null;
    }
  }

  /// get the dart type of the pointer
  Type get type => T.runtimeType;
}

/// default Buffer size (match OS page size)
const defaultBufferSize = 4096;

/// Check if the SQL type is a binary type
bool isSQLTypeBinary(int type) {
  return type == SQL_BINARY ||
      type == SQL_VARBINARY ||
      type == SQL_LONGVARBINARY;
}
