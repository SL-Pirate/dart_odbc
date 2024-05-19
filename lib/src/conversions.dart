import 'dart:ffi';
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
  static ToPointerDto<dynamic> toPointer(dynamic value) {
    if (value is String) {
      final result = value.toNativeUtf16();
      return ToPointerDto<Utf16>(result.cast(), result.length, value: value);
    } else if (value is int) {
      final result = calloc.allocate<Int>(sizeOf<Int>())..value = value;
      return ToPointerDto<Int>(result.cast(), sizeOf<Int>(), value: value);
    } else if (value is double) {
      final result = calloc.allocate<Float>(sizeOf<Float>())..value = value;
      return ToPointerDto<Float>(result.cast(), sizeOf<Float>(), value: value);
    } else if (value is bool) {
      // Allocate memory for a single byte (bool is typically 1 byte)
      final result = calloc.allocate<Uint8>(1)..value = value ? 1 : 0;
      return ToPointerDto<Uint8>(result.cast(), 1, value: value);
    } else {
      throw Exception('Unsupported data type: ${value.runtimeType}');
    }
  }
}

/// A model that will be used to return the response of to pointer method
class ToPointerDto<T> {
  /// constructor
  ToPointerDto(this.ptr, this.length, {this.value});

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
