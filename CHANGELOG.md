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
