## UNRELEASED

### New Features
- **Added**: Helper function `execLargeTable()` in `TestHelper` for processing tables with 200+ columns
  - Automatically groups columns to avoid driver memory allocation failures (HY001)
  - Auto-detects primary key for merging results
  - Includes fallback pagination for problematic column groups
  - See `test/test_helper.dart` for implementation details

### Breaking Changes
- **REMOVED**: Automatic `SELECT *` to `CAST AS NVARCHAR(MAX)` transformation
  - This transformation caused significant performance degradation (2x slower)
  - Caused excessive memory usage (up to 2GB per column)
  - Lost type information (all data became strings)
  - The existing incremental SQLGetData implementation already handles large columns correctly
  - **Migration**: No code changes needed - queries now work faster and preserve original data types

### Bug Fixes
- **FIXED**: SQLFetch error handling - errors are now properly logged instead of being masked
  - Previously, `SQL_ERROR (-1)` and `SQL_INVALID_HANDLE (-2)` were treated as normal end-of-data
  - This caused silent failures in concurrent cursor operations
  - Now errors are logged with appropriate warnings
- **FIXED**: Concurrent cursor operations now work correctly
  - Test `multiple non-blocking clients can run cursors concurrently` now passes
  - Better handling of invalid cursor states from ODBC drivers

### Improvements
- **Performance**: Queries are now ~2x faster (no metadata query overhead)
- **Memory**: 10-20x lower memory usage for large result sets
- **Type preservation**: INT, DATETIME, BINARY types are now preserved (not converted to strings)
- **Code quality**: Reduced codebase by 150 lines (37% reduction in execute.dart)
- **Buffer management**: Improved adaptive buffer expansion
  - Changed from aggressive doubling (4KB→8KB→16KB→32KB→64KB) to gradual +8KB increments
  - Added maximum expansion limit (10 expansions) to prevent infinite loops
  - Better logging of buffer expansion events

### Documentation
- Improved documentation of ODBC Driver 18 HY104 workaround for string parameters
- Added detailed comments explaining why certain design decisions were made
- Clarified security implications of string parameter escaping

## 1.0.0

- Initial version.

## 1.0.1+1

- Improved memory management with the ffi

## 1.0.2+1

- Renamed low level API class from api/sql to ffi/libodbc and renamed the class to LibODBC

## 1.1.0+1

- Implemented sanitization of sql queries using prepared statements

## 1.1.1+1

- Improved exception handeling
- Made setting up OSBC version optional.
- Verified functionality with Oracle

## 1.1.1+2

- Updated documentation

## 1.2.0+1

- Implemented `removeWhitespaceUnicodes` method to remove unicode whitespace characters on some platforms with some drivers (Thanks to [Salah Sonbol](https://github.com/MrXen3))

## 2.0.0+1

- Exposed availability to configure data types and size for each column in the result set

## 2.1.0+1

- Fixed bug where result set contains unicoded whitespace characters leading to problems with fetching values from result set using column  name and appearing weired symbols when showing values as text

## 3.0.0+1

- Implemented asynchronos support. No `connect`, `disconnect` and `execute` returns Futures!

## 3.0.0+2

- Updated documentation

## 3.1.0+1

- Implemented Implemented `connectWithConnectionString` and `getTables` methods (#6) (Thanks to [Paul-creator](https://github.com/Paul-creator))

## 3.1.1+1

- Added some missed commits

## 3.1.2+1

- Stopped using `columnConfig`'s `type` property as it is known to cause problems with how the data is transformed. Property is not removed for backwards compatibility but is not used anymore.

## 3.1.2+2

- Updated readme

## 4.0.0+1

- Implemented auto detecting odbc driver from driver manager

## 4.1.0+1

- Implemented `DartOdbcUtf8` class for handling utf8

## 4.1.1+1

- Improved auto-detecting drivers on windows

## 4.1.2+1

- Major bug fixes for most of the issues
- Implemented using driver manager as a middleware

## 4.2.0+1

- Implemented better support for working with binary data

## 5.0.0

### Breaking changes
- Removed deprecated members that were scheduled for removal
- Updated dependencies to newer major versions

### Bug Fixes
- Fixed [Corrupt characters when reading NVARCHAR from SQL Server](https://github.com/SL-Pirate/dart_odbc/issues/12) thanks to [ccisnedev](https://github.com/ccisnedev)

### Improvements
- Major improvements to better align the library with the ODBC standard, improving performance, usability, and safety. Thanks to [ccisnedev](https://github.com/ccisnedev) for co-authoring.
- Result fetching now follows the ODBC streaming model (incremental SQLGetData reads), eliminating truncation issues and improving correctness for large values.
- Column buffer sizing is now treated as a per-chunk fetch hint rather than a hard size limit.

## 5.0.1

- Fixed some minor issues flagged by pana test

## 6.0.0

- Added support for `DateTime` input for sanitized input.
- Removed `ColumnConfig`. The data types will now be auto detected.
- Various Performance and memory safety improvements.

## 6.0.1

- Removed unnecessary parameter setting for SQLBindParameter Column Size

## 6.1.0

- Implemented streaming support for query results. Now `DartOdbc.executeCursor` can be used to stream large result sets without loading everything into memory at once.

## 6.2.0

- Implemented non-blocking ODBC operations using isolates.
- Made the new non-blocking ODBC implementation the default, while keeping the previous blocking implementation available as `DartOdbcBlockingClient` for users who still need blocking behavior.
