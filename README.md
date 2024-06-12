# dart_odbc

A Dart package for interacting with ODBC databases. It allows you to connect to ODBC data sources and execute SQL queries directly from your Dart applications.

This package is inspired by the obsolete [odbc](https://pub.dev/packages/odbc) package by [Juan Mellado](https://github.com/jcmellado).

[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

## Usage

- Instanciate the ODBC class by providing the path to the odbc driver on the host machine

```dart
  final odbc = DartOdbc(
    '/path/to/the/odbc/driver',
    version=SQL_OV_ODBC3_80 // optional
  );
```

### Path to ODBC Driver

Path to the ODBC driver can be found in the ODBC driver manager.
In windows this is a `.dll` file that is there in the installation folder of the ODBC driver.
In linux this has an extension of `.so`.
In macos this should have an extension of `.dylib`.

### version

The ODBC version can be specified using the `version` parameter.
Definitions for these values can be found in the `LibODBC` class.
Please note that some drivers may not work properly with manually setting version.

- Connect to the database by providing the DSN (Data Source Name) configured in the ODBC Driver Manager

```dart
  odbc.connect(
    dsn: '<your_dsn>',
    username: 'db_username',
    password: 'db_password',
  );
```

### DSN (Data Source Name)

This is the name you gave when setting up the driver manager.
For more information, visit this page from the [MySQL Documentation](https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-driver-manager.html)

- In case the path privided to the driver is invalid or there is any issue with setting up the environment/connecting to the database, an `Exception` will be thrown when intanciating the ODBC or connecting to the database.
- Execute your queries directly as follows

```dart
  final result = odbc.execute("SELECT 10");
```

### Executing prepared statements

- Prepared statements can be used to prevent `SQL Injection`
- Example query

```dart
  final List<Map<String, dynamic>> result = odbc.execute(
    'SELECT * FROM USERS WHERE UID = ?',
    params: [1],
  );
```

- Result will be a `List` of `Map` objects where each Map represents a row. If anything goes wrong an `ODBCException` will be thrown

### Unsupported whitespace unicode characters

- On some platforms with some drivers sometimes unsupprted unicode characters can be included.
- These characters can be pruned from the result set using the `removeWhitespaceUnicodes` method from the `DartOdbc` class.

```dart
  print(DartOdbc.removeWhitespaceUnicodes(result));
```

### Accessing ODBC diver bindings directly

- Native `ODBC` methods can be executed by using the `LibODBC` import

- For more information on the `ODBC` api go to [Microsoft ODBC Documentation](https://learn.microsoft.com/en-us/sql/odbc/microsoft-open-database-connectivity-odbc?view=sql-server-ver16)

## Tested On

This package has been tested to be working on the following Database Servers

- Microsoft SQL Sever
- Oracle

## Support for other Database Servers

- Although not tested, this plugin should work on any database that provides an `ODBC Driver`.
- For a comprehensive list of supported database servers checkout `Drivers` section of the official [unixodbc](https://www.unixodbc.org/) site
