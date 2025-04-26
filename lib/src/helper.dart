import 'dart:ffi';
import 'dart:typed_data';
import 'package:dart_odbc/dart_odbc.dart';
import 'package:ffi/ffi.dart';

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
      return OdbcPointer<Utf16>(result.cast(), result.length, value: value);
    } else if (value is int) {
      final result = calloc.allocate<Int>(sizeOf<Int>())..value = value;
      return OdbcPointer<Int>(result.cast(), sizeOf<Int>(), value: value);
    } else if (value is double) {
      final result = calloc.allocate<Float>(sizeOf<Float>())..value = value;
      return OdbcPointer<Float>(result.cast(), sizeOf<Float>(), value: value);
    } else if (value is bool) {
      // Allocate memory for a single byte (bool is typically 1 byte)
      final result = calloc.allocate<Uint8>(1)..value = value ? 1 : 0;
      return OdbcPointer<Uint8>(result.cast(), 1, value: value);
    } else {
      throw Exception('Unsupported data type: ${value.runtimeType}');
    }
  }

  /// Convert a hex string to a Uint8List
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

  /// Size of the column
  final int? size;

  /// Check if the column type is a binary type
  bool isBinary() {
    return type == SQL_BINARY ||
        type == SQL_VARBINARY ||
        type == SQL_LONGVARBINARY;
  }
}

/// Extension class for dart [String]
extension OdbcString on String {
  static final _unicodeWhitespaceRegExp = RegExp(
    r'[\u0000\u0020\u00A0\u180E\u200A\u200B\u202F\u205F\u3000\uFEFF\u2800\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u2400]',
  );

  /// Removes all unicode whitespaces from the string
  @Deprecated('This method is no longer needed')
  String removeUnicodeWhitespaces() {
    return replaceAll(_unicodeWhitespaceRegExp, '');
  }
}

///
enum UtfType {
  ///
  utf8,

  ///
  utf16,
}
