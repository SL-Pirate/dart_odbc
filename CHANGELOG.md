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
