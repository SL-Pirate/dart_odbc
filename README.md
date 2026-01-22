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

By default, encryption is enabled. To disable encryption (for example, when connecting to a local database without SSL/TLS):

```dart
await odbc.connect(
  username: 'db_username',
  password: 'db_password',
  encrypt: false,
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
    final data = (row as CursorItem).value;
    print(data);
  }
} finally {
  await cursor.close(); // Ensure resources are freed
}
```

You can also use prepared statements with cursors:

```dart
final cursor = await odbc.executeCursor(
  'SELECT * FROM USERS WHERE UID = ?',
  params: [1],
);
try {
  while (true) {
    final row = await cursor.next();
    if (row is CursorDone) {
      break;
    }
    final data = (row as CursorItem).value;
    print(data);
  }
} finally {
  await cursor.close();
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

Get all tables in the database:

```dart
final List<Map<String, dynamic>> tables = await odbc.getTables();
```

Filter tables by name, catalog, schema, or type:

```dart
// Get tables with a specific name
final tables = await odbc.getTables(tableName: 'USERS');

// Get tables in a specific schema
final tables = await odbc.getTables(schema: 'dbo');

// Get only user tables (exclude system tables)
final userTables = await odbc.getTables(tableType: 'TABLE');

// Combine filters
final tables = await odbc.getTables(
  tableName: 'USERS',
  schema: 'dbo',
  catalog: 'MyDatabase',
);
```

### Get Columns

Retrieve information about columns in a table:

```dart
final columns = await odbc.getColumns(tableName: 'USERS');

for (final column in columns) {
  print('Column: ${column['COLUMN_NAME']}');
  print('Type: ${column['TYPE_NAME']}');
  print('Size: ${column['COLUMN_SIZE']}');
  print('Nullable: ${column['NULLABLE']}');
}
```

Filter columns by catalog, schema, or column name:

```dart
// Get specific column
final column = await odbc.getColumns(
  tableName: 'USERS',
  columnName: 'UID',
);

// Get columns from specific schema
final columns = await odbc.getColumns(
  tableName: 'USERS',
  schema: 'dbo',
  catalog: 'MyDatabase',
);
```

### Get Primary Keys

Retrieve information about primary key columns:

```dart
final primaryKeys = await odbc.getPrimaryKeys(tableName: 'USERS');

for (final pk in primaryKeys) {
  print('PK Column: ${pk['COLUMN_NAME']}');
  print('Sequence: ${pk['KEY_SEQ']}');
}
```

Filter by catalog and schema:

```dart
final primaryKeys = await odbc.getPrimaryKeys(
  tableName: 'USERS',
  schema: 'dbo',
  catalog: 'MyDatabase',
);
```

### Get Foreign Keys

Retrieve information about foreign key relationships:

```dart
// Get all foreign keys in the USERS table
final foreignKeys = await odbc.getForeignKeys(fkTableName: 'USERS');

// Get foreign keys that reference the ORDERS table
final foreignKeys = await odbc.getForeignKeys(pkTableName: 'ORDERS');

// Get specific foreign key relationship
final foreignKeys = await odbc.getForeignKeys(
  pkTableName: 'ORDERS',
  fkTableName: 'USERS',
);

for (final fk in foreignKeys) {
  print('FK Column: ${fk['FKCOLUMN_NAME']}');
  print('References: ${fk['PKTABLE_NAME']}.${fk['PKCOLUMN_NAME']}');
}
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

### Blocking Client

By default, `DartOdbc` uses a non-blocking implementation that runs database operations in a dedicated isolate. For environments where isolates are not desired or not available, you can use `DartOdbcBlockingClient`:

```dart
import 'package:dart_odbc/dart_odbc.dart';

final odbc = DartOdbcBlockingClient(dsn: '<your_dsn>');

await odbc.connect(
  username: 'db_username',
  password: 'db_password',
);

final result = await odbc.execute('SELECT * FROM USERS');

await odbc.disconnect();
```

**Note**: The blocking client runs all operations synchronously in the current isolate, which may block the UI thread in Flutter applications. Use the default `DartOdbc` (non-blocking) for Flutter apps.

### Accessing ODBC driver bindings directly

Native ODBC methods can be executed via the `LibOdbc` class.

- For more information on the ODBC API, see the [Microsoft ODBC Documentation](https://learn.microsoft.com/en-us/sql/odbc/microsoft-open-database-connectivity-odbc)

## Testing

### Current status

This package has been tested to be working on the following Database Servers

- Microsoft SQL Server
- Oracle
- MariaDB / MySQL

### Local testing

This gives an overview of how you can set up the environment for testing with SQL Server on Linux. For Windows or macOS, please check out the official documentation from Microsoft mentioned above.

#### Getting SQL server up and running

1. Get a working SQL Server. For this you can use a SQL Server instance from a managed provider or install it locally or on Docker.
2. For docker setup check out [this guide](https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker?tabs=cli&pivots=cs1-bash)

#### Setting up `unixodbc` and the Microsoft SQL Server ODBC driver

- For this, you can follow this [detailed guide](https://poweradm.com/connect-ms-sql-server-from-linux-odbc/)

#### Setting up the environment variables and the testing database.

1. Simply create a file `.env` in the project root, copy the content from the `test.env` to it and set the required variables according to your setup.
2. Connect to your SQL server and execute the commands in the `test/testdb.sql` file which will initialize the `odbc_test` database (or you can name this database any name and override it in the `.env`) which will be used for testing.

#### Run the tests

- Simply execute the following command to run the tests with `dart cli`

> $ dart test

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
