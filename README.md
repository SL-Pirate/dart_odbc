# dart_odbc

A Dart package for interacting with ODBC databases. It allows you to connect to ODBC data sources and execute SQL queries directly from your Dart applications.

This package is inspired by the obsolete [odbc](https://pub.dev/packages/odbc) package by [Juan Mellado](https://github.com/jcmellado).

[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

## Features

- Async-first API (`connect`, `execute`, `getTables`, ...)
- Non-blocking by default: work is executed in a dedicated isolate so database calls don’t block the main isolate
- Optional blocking client (`DartOdbcBlockingClient`) for environments where isolates are not desired
- Prepared statements with positional parameters (`?`) to help sanitize user input
- Cursor-based streaming (`executeCursor`) for large result sets (row-by-row fetching)
- Lightweight schema discovery via `getTables`
- Direct access to native ODBC bindings via `LibOdbc` for advanced use cases

## Usage

### Getting started

Add the dependency:

```sh
dart pub add dart_odbc
```

Import and instantiate `DartOdbc` by providing a DSN (Data Source Name):

```dart
import 'package:dart_odbc/dart_odbc.dart';

final odbc = DartOdbc(dsn: '<your_dsn>');
```

This should discover and load the ODBC driver manager and initialize the internal mechanisms required to communicate with it.

Alternatively, you can provide the path to the driver manager library when it is not placed in a discoverable location or auto-detection fails. This is not recommended due to security concerns; use only as a fallback.

```dart
final odbc = DartOdbc(
  dsn: '<your_dsn>',
  pathToDriver: '/path/to/odbc/driver/manager',
);
```

It is generally preferable to provide the path to the ODBC driver manager (for example, unixODBC) rather than a vendor-issued driver library. The driver manager acts as a compatibility layer across drivers; a vendor driver may work but is not recommended.

### DSN

The DSN (Data Source Name) is the name you gave when setting up the driver manager.
For more information, visit this page from the [MySQL Documentation](https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-driver-manager.html).
If not provided, the connection will be limited to connecting via a connection string. For more information, see below.

Connect to the database using the DSN configured in the ODBC driver manager:

```dart
await odbc.connect(
  username: 'db_username',
  password: 'db_password',
);
```

Or connect via a connection string:

```dart
await odbc.connectWithConnectionString(
  r'DRIVER={Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)};'
  r'DBQ=C:\Users\Computer\AppData\Local\Temp\test.xlsx;'
);
```

### Executing SQL queries

```dart
final result = await odbc.execute("SELECT 10");
```

### Executing prepared statements

Prepared statements should be used to sanitize user input and prevent SQL injection.

Example:

```dart
final List<Map<String, dynamic>> result = await odbc.execute(
  'SELECT * FROM USERS WHERE UID = ?',
  params: [1],
);
```

### Streaming support

For large result sets, you can use the `executeCursor` method to stream results row by row without loading everything into memory at once.

```dart
final cursor = await odbc.executeCursor('SELECT * FROM LARGE_TABLE');
try {
  while (true) {
    final row = await cursor.next();
    if (row is CursorDone) {
      break; // No more rows
    }
    // Process the row (which is a Map<String, dynamic>)
    print(row);
  }
} finally {
  await cursor.close(); // Ensure resources are freed
}
```

#### Currently supported data types for parameter binding

Below are currently supported data types for parameter binding. If this does not include a type that you are looking for, please open a feature request.

- `String`
- `int`
- `double`
- `bool`
- `DateTime`
- `Uint8List`

### Fetching data

Currently the library only discriminates between text and binary data types:

- Binary data types (for example `VARBINARY` or `BINARY`) are returned as `Uint8List`.
- All other data types are converted to `String` by design.

When calling `execute`, the result is a `Future<List<Map<String, dynamic>>>`, where each `Map` represents a row.

- Each key in the `Map` corresponds to a column name.
- If execution or decoding fails, DartOdbc throws an `ODBCException`.
- `ODBCException` includes `message`, `sqlState` (a five-character ODBC standard code), and a `nativeError` code from the driver.

### Get Tables

```dart
final List<Map<String, String>> tables = await odbc.getTables();
```

### Disconnecting from the database

Finally, don’t forget to disconnect and free resources:

```dart
  await odbc.disconnect();
```

### Examples

See the runnable examples in:

- `example/lib`

## Logging

DartOdbc uses the standard [package:logging](https://pub.dev/packages/logging) package for internal diagnostics.

- Logging is disabled by default
- The library does not print to stdout or stderr
- Applications can opt in and control how log messages are handled
- This allows DartOdbc to emit diagnostic information (for example, unexpected return codes during cleanup) without imposing any logging behavior on the application.

### Example: enable logging in an application

```dart
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.FINE;

  Logger.root.onRecord.listen((record) {
    print(
      '[${record.level.name}] '
      '${record.loggerName}: '
      '${record.message}',
    );
  });

  // Use DartOdbc normally
}
```

- If logging is not enabled by the application, all log messages are silently ignored.

### Accessing ODBC driver bindings directly

Native ODBC methods can be executed via the `LibOdbc` class.

- For more information on the ODBC API, see the [Microsoft ODBC Documentation](https://learn.microsoft.com/en-us/sql/odbc/microsoft-open-database-connectivity-odbc)

## Testing

### Current status

This package has been tested to be working on the following Database Servers

- PostgreSQL — verified in CI on every change
- MariaDB / MySQL — verified in CI on every change
- Microsoft SQL Server
- Oracle

### Running the tests (recommended)

The test suite is fully containerized. **Docker is the only prerequisite** — you
do not need to install unixODBC, an ODBC driver, or a database on your machine.

```bash
docker compose run --rm tests
```

That starts PostgreSQL, waits until it is accepting connections, seeds the test
schema, and runs the full suite inside an image that already has the driver
manager and the ODBC drivers installed.

A `Makefile` wraps the common tasks:

```bash
make test                 # full suite against PostgreSQL
make test-mariadb         # same suite against MariaDB
make test-all             # both engines
make test-unit            # DB-free unit tests, natively (fastest loop)
make test-file FILE=test/integration/query_test.dart
make shell                # shell in the ODBC environment, for debugging
make db                   # start only the database
make down                 # stop everything
```

The tests exercise the ODBC/FFI layer rather than any one vendor's SQL dialect,
so the suite is dialect-agnostic and CI runs it against **PostgreSQL and
MariaDB**. Both drivers install from the standard distribution repositories with
no licence acceptance, and both database images run natively on `x86_64` and
`arm64`.

#### Debugging a connection problem

`make shell` drops you into the runner image, where `isql` can test the ODBC
layer directly, without Dart in the picture:

```bash
isql -v postgres odbc_test odbc_test
```

If `isql` connects but the Dart tests fail, the problem is in the FFI layer. If
both fail, the problem is in the ODBC configuration.

#### Writing tests or targeting another database

See [`test/README.md`](test/README.md) for the suite's internals: how to add a
test, and how to run it against a database engine other than PostgreSQL.

### Testing against your own database

You can still run the suite natively against a database you manage. This
requires the manual setup that the container image otherwise handles for you:

1. Install a driver manager (`unixodbc`) and an ODBC driver for your database.
   On Debian/Ubuntu, `unixodbc-dev` is required — it provides the unversioned
   `libodbc.so` that this package loads.
2. Register a DSN in your `odbc.ini`. For SQL Server on Linux, see
   [this guide](https://poweradm.com/connect-ms-sql-server-from-linux-odbc/);
   for a Docker-hosted SQL Server, see
   [Microsoft's quickstart](https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker?tabs=cli&pivots=cs1-bash).
3. Copy `test.env` to `.env` and set the values to match your setup.
4. Create the test schema. `test/schema/postgres.sql` holds the fixtures;
   adapt the types for another engine.
5. Run the tests:

> $ dart test

To run natively against just the containerized database, use `make db` and point
your DSN at `localhost:15432`.

## Support for other Database Servers

- Although not tested, this package should work on any database that provides an `ODBC Driver`.
- For a comprehensive list of supported database servers checkout `Drivers` section of the official [unixodbc](https://www.unixodbc.org/) site

## Support for mobile (`Android` and `iOS`) platforms

This library is primarily intended for desktop and server-side use.

There are no technical restrictions in the codebase that explicitly prevent it from running on mobile platforms. However, in practice, ODBC drivers are rarely available or supported on Android and iOS, and most database vendors do not provide official ODBC implementations for these environments.

To avoid confusion and false expectations, the package is not listed as supported on mobile platforms. That said, if you are able to obtain a working ODBC driver for Android or iOS, the library should function correctly on those platforms.

The Web platform is not supported. This library depends on `dart:ffi` and `dart:io`, which are unavailable in web environments.

## 💖 Support the Project

Hey everyone! 👋 I'm actively maintaining this project while juggling my studies and other responsibilities. If you find my work useful and would like to help me keep improving this project, consider supporting me! Your contributions will help me cover expenses, buy more coffee ☕, and dedicate more time to development. 🙌

Every little bit helps, and I really appreciate your support. Thank you for helping me keep this project going! 💛

- [buy me a coffee](https://buymeacoffee.com/slpirate)
