# dart_odbc

A Dart package for interacting with ODBC databases. It allows you to connect to ODBC data sources and execute SQL queries directly from your Dart applications.

This package is inspired by the obsolete [odbc](https://pub.dev/packages/odbc) package by [Juan Mellado](https://github.com/jcmellado).

[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

## Usage

- Instanciate the ODBC class by providing the path to the odbc driver on the host machine

```dart
  final odbc = DartOdbc(
    dsn: '<your_dsn>',
    pathToDriver: '<path_to_odbc_driver>',
  );
```

### DSN (optional)

The DSN (Data Source Name) is the name you gave when setting up the driver manager.
For more information, visit this page from the [MySQL Documentation](https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-driver-manager.html)
If not provided, the connection can only be made via connection string.

- Connect to the database by providing the DSN (Data Source Name) configured in the ODBC Driver Manager

```dart
  await odbc.connect(
    username: 'db_username',
    password: 'db_password',
  );
```

- Or connect to the database via connection string

```dart
  await odbc.connectWithConnectionString(
    "DRIVER={Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)};DBQ=C:\Users\Computer\AppData\Local\Temp\test.xlsx;"
  );
```

### Executing SQL queries

```dart
  final result = await odbc.execute("SELECT 10");
```

### Executing prepared statements

- Prepared statements can be used to prevent `SQL Injection`
- Example query

```dart
  final List<Map<String, dynamic>> result = await odbc.execute(
    'SELECT * FROM USERS WHERE UID = ?',
    params: [1],
  );
```

### Providing configuration for result set columns

- DartOdbc can automatically decode result sets for most queries.
- In rare cases, columns with non-text data types (most commonly binary data) may not be decoded correctly using the default configuration.
- These cases can be handled by explicitly providing a ColumnType for the affected columns using the columnConfig parameter of the execute method.
- Only columns with decoding issues need to be configured.

```dart
// Assume a table like this:
//
// +-----+--------+----------------------+
// | UID | NAME   | AVATAR               |
// +-----+--------+----------------------+
// | 1   | Alice  | <binary data>        |
// | 2   | Bob    | <binary data>        |
// +-----+--------+----------------------+
//
// NAME   -> text column (NVARCHAR / VARCHAR)
// AVATAR -> binary column (VARBINARY / BLOB)

final result = await odbc.execute(
  'SELECT UID, NAME, AVATAR FROM USERS WHERE UID = ?',
  params: [1],

  /// By default, all columns are fetched as SQL_C_WCHAR.
  /// Binary columns must be explicitly overridden.
  columnConfig: {
    'AVATAR': ColumnType(type: SQL_C_BINARY),
  },
);
```

- This configuration is typically required only for binary columns.
Other column types do not require configuration and will ignore it if provided.
- The result is returned as a `Future<List<Map<String, dynamic>>>`, where each `Map` represents a row.
- If execution or decoding fails, DartOdbc will throw an ODBCException when possible.
Incorrect column configuration for binary data may result in memory errors or process termination.
- Text-based columns are returned as `String` values, while binary columns (for example `VARBINARY` or `BLOB`) are returned as `Uint8List`.

### Get Tables

```dart
final List<Map<String, String>> tables = await odbc.getTables();
```

### Disconnecting from the database

- Finally, don't forget to `disconnect` from the database and free resources.

```dart
  await odbc.disconnect();
```

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

### Accessing ODBC diver bindings directly

- Native `ODBC` methods can be executed by using the `LibOdbc` class

- For more information on the `ODBC` api go to [Microsoft ODBC Documentation](https://learn.microsoft.com/en-us/sql/odbc/microsoft-open-database-connectivity-odbc?view=sql-server-ver16)

## Testing

### Current status

This package has been tested to be working on the following Database Servers

- Microsoft SQL Sever
- Oracle

### Local testing

- This gives an overview on how you can setup the environment for testing with SQL Server on linux. For windows or mac, please check out the official documentation from Microsoft mentioned above.

#### Getting SQL server up and running

1. Get a working sql server. For this you can use a sql server instance from a managed provider or install it locally or on docker.
2. For docker setup check out [this guide](https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker?view=sql-server-ver17&tabs=cli&pivots=cs1-bash)

#### Setting up `unixodbc` and the Microsoft SQL Server ODBC driver

- For this, you can follow this [detailed guide](https://poweradm.com/connect-ms-sql-server-from-linux-odbc/)

#### Setting up the environment variables and the testing database.

1. Simply create a file `.env` in the project root, copy the content from the `test.env` to it and set the required variables according to your setup.
2. Connect to your SQL server and execute the commands in the `test/testdb.sql` file which will initialize the `odbc_test` database (or you can name this database any name and override it in the `.env`) which will be used for testing.

#### Run the tests

- Simply execute the following command to run the tests with `dart cli`

> $ dart test

## Support for other Database Servers

- Although not tested, this plugin should work on any database that provides an `ODBC Driver`.
- For a comprehensive list of supported database servers checkout `Drivers` section of the official [unixodbc](https://www.unixodbc.org/) site

## 💖 Support the Project

Hey everyone! 👋 I'm actively maintaining this project while juggling my studies and other responsibilities. If you find my work useful and would like to help me keep improving this project, consider supporting me! Your contributions will help me cover expenses, buy more coffee ☕, and dedicate more time to development. 🙌

Every little bit helps, and I really appreciate your support. Thank you for helping me keep this project going! 💛

- [buy me a coffee](https://buymeacoffee.com/slpirate)
