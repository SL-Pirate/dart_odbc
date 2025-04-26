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

- The abstraction layer of DartOdbc should be able to handle output for most queries
- But output for columns with very long column size or uncommon data types could get corrupted due to issues in default memory allocation
- Thes can be handled by providing the `ColumnType` in the `columnConfig` parameter of the `execute` method on `DartOdbc` class
- Please refer the following example

```dart

  // Assume a table like this
  // +-----+-------+-------------+
  // | UID | NAME  | DESCRIPTION |
  // +-----+-------+-------------+
  // | 1   | Alice |             |
  // | 2   | Bob   |             |
  // +-----+-------+-------------+
  // The name is a column of size 150
  // The description is a column of size 500

  result = await odbc.execute(
    'SELECT * FROM USERS WHERE UID = ?',
    params: [1],

    /// The column config can be provided as this.
    /// But for most cases this config is not necessary
    /// This is only needed when the data fetching is not working as expected
    /// Only the columns with issues need to be provided
    columnConfig: {
      'NAME': ColumnType(size: 150),
      'DESCRIPTION': ColumnType(type: SQL_C_WCHAR, size: 500),
    },
  );

```

- Result will be a `Future` of `List` of `Map` objects (`Future<List<Map<String, dynamic>>>`) where each Map represents a row. If anything goes wrong an `ODBCException` will be thrown

### Working with binary data

- ODBC supports binary data types like `BINARY` and `VARBINARY`.
- To work with binary data, you must provide the `ColumnType` for the column in the `columnConfig` parameter of the `execute` method on `DartOdbc` class

```dart
  result = await odbc.execute(
    'SELECT * FROM USERS WHERE UID = ?',
    params: [1],
    columnConfig: {
      'BINARY_COLUMN': ColumnType(type: SQL_BINARY, size: 100),
      'VARBINARY_COLUMN': ColumnType(type: SQL_VARBINARY, size: 200),
    },
  );
```

- The resulting colummn will yield a `Uint8List` object.

### Get Tables

```dart
final List<Map<String, String>> tables = await odbc.getTables();
```

### Disconnecting from the database

- Finally, don't forget to `disconnect` from the database and free resources.

```dart
  await odbc.disconnect();
```

### Accessing ODBC diver bindings directly

- Native `ODBC` methods can be executed by using the `LibOdbc` class

- For more information on the `ODBC` api go to [Microsoft ODBC Documentation](https://learn.microsoft.com/en-us/sql/odbc/microsoft-open-database-connectivity-odbc?view=sql-server-ver16)

## Tested On

This package has been tested to be working on the following Database Servers

- Microsoft SQL Sever
- Oracle

## Support for other Database Servers

- Although not tested, this plugin should work on any database that provides an `ODBC Driver`.
- For a comprehensive list of supported database servers checkout `Drivers` section of the official [unixodbc](https://www.unixodbc.org/) site

## 💖 Support the Project

Hey everyone! 👋 I'm actively maintaining this project while juggling my studies and other responsibilities. If you find my work useful and would like to help me keep improving this project, consider supporting me! Your contributions will help me cover expenses, buy more coffee ☕, and dedicate more time to development. 🙌

Every little bit helps, and I really appreciate your support. Thank you for helping me keep this project going! 💛

- [buy me a coffee](https://buymeacoffee.com/slpirate)
