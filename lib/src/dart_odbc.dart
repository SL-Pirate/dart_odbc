// only comments go beyond this limit!!!
// ignore_for_file: lines_longer_than_80_chars

import 'package:dart_odbc/dart_odbc.dart';

/// Contains the interface definition for DartOdbc
abstract interface class IDartOdbc {
  /// Connect to a database
  /// This is the name you gave when setting up the ODBC manager.
  /// The [username] parameter is the username to connect to the database.
  /// The [password] parameter is the password to connect to the database.
  /// The [encrypt] parameter controls SSL/TLS encryption. Set to `false` to disable encryption.
  /// Defaults to `true` (encryption enabled).
  Future<void> connect({
    required String username,
    required String password,
    bool encrypt = true,
  });

  /// Connects to the database using a connection string instead of a DSN.
  ///
  /// [connectionString] is the full connection string that provides all necessary
  /// connection details like driver, server, database, etc.
  ///
  /// This method is useful for connecting to data sources like Excel files or text files
  /// without having to define a DSN.
  ///
  /// Returns the completed connection string used for the connection.
  ///
  /// Throws a [ConnectionException] if the connection fails.
  Future<String> connectWithConnectionString(String connectionString);

  /// Retrieves a list of tables from the connected database.
  ///
  /// Optionally, you can filter the results by specifying [tableName], [catalog],
  /// [schema], or [tableType]. If these are omitted, all tables will be returned.
  ///
  /// Returns a list of maps, where each map represents a table with its name,
  /// catalog, schema, and type.
  ///
  /// Throws a [FetchException] if fetching tables fails.
  Future<List<Map<String, dynamic>>> getTables({
    String? tableName,
    String? catalog,
    String? schema,
    String? tableType,
  });

  /// Retrieves information about columns in a table.
  ///
  /// Returns details about each column including name, data type, size,
  /// nullable status, and other attributes.
  ///
  /// Optionally, you can filter by [catalog], [schema], [tableName], and
  /// [columnName]. If omitted, all columns will be returned.
  ///
  /// Throws a [FetchException] if fetching columns fails.
  Future<List<Map<String, dynamic>>> getColumns({
    required String tableName,
    String? catalog,
    String? schema,
    String? columnName,
  });

  /// Retrieves information about primary key columns for a specified table.
  ///
  /// Returns details about which columns form the table's primary key,
  /// including column names and their sequence in the key.
  ///
  /// Optionally, you can filter by [catalog] and [schema].
  ///
  /// Throws a [FetchException] if fetching primary keys fails.
  Future<List<Map<String, dynamic>>> getPrimaryKeys({
    required String tableName,
    String? catalog,
    String? schema,
  });

  /// Retrieves information about foreign key relationships.
  ///
  /// Returns details about foreign keys, including which columns reference
  /// primary keys in other tables.
  ///
  /// You can specify either [pkTableName] (primary key table) or
  /// [fkTableName] (foreign key table), or both.
  ///
  /// Optionally, you can filter by [pkCatalog], [pkSchema], [fkCatalog],
  /// and [fkSchema].
  ///
  /// Throws a [FetchException] if fetching foreign keys fails.
  Future<List<Map<String, dynamic>>> getForeignKeys({
    String? pkTableName,
    String? fkTableName,
    String? pkCatalog,
    String? pkSchema,
    String? fkCatalog,
    String? fkSchema,
  });

  /// Execute a query
  /// The [query] parameter is the SQL query to execute.
  /// This function will return a list of maps where each map represents a row
  /// in the result set. The keys in the map are the column names and the values
  /// are the column values.
  /// The [params] parameter is a list of parameters to bind to the query.
  /// Example query:
  /// ```dart
  /// final List<Map<String, dynamic>> result = odbc.execute(
  ///   'SELECT * FROM USERS WHERE UID = ?',
  ///   params: [1],
  /// );
  /// ```
  Future<List<Map<String, dynamic>>> execute(
    String query, {
    List<dynamic>? params,
  });

  /// Execute a query that returns a cursor
  /// The [query] parameter is the SQL query to execute.
  /// This function will return an [OdbcCursor] that can be used to pull rows
  /// one at a time.
  /// The [params] parameter is a list of parameters to bind to the query.
  /// Example query:
  /// ```dart
  /// final OdbcCursor cursor = await odbc.executeCursor(
  ///   'SELECT * FROM USERS WHERE UID = ?',
  ///   params: [1],
  /// );
  /// ```
  /// You can then use the cursor to pull rows one at a time.
  /// For more information on using cursors, see the [OdbcCursor] documentation.
  Future<OdbcCursor> executeCursor(
    String query, {
    List<dynamic>? params,
  });

  /// Disconnects from the database.
  Future<void> disconnect();

  /// Function to handle ODBC errors
  /// The [status] parameter is the status code returned by the ODBC function.
  /// The [onException] parameter is the exception to throw if the status code
  /// is an error.
  /// The [handle] parameter is the handle to the ODBC object that caused the
  /// error.
  /// The [operationType] parameter is the type of operation that caused the
  /// error.
  /// If [handle] is not provided, the error message will not be descriptive.
  /// The [beforeThrow] parameter is an optional callback that is executed
  /// before throwing the exception. This can be used for cleanup or logging.
  /// Returns the status code if it indicates success.
  @Deprecated(
    'tryOdbc exposes low-level synchronous ODBC semantics and will be removed '
    'in a future release. It is not supported in non-blocking mode.',
  )
  int tryOdbc(
    int status, {
    SQLHANDLE? handle,
    int operationType = SQL_HANDLE_STMT,
    void Function()? beforeThrow,
    ODBCException? onException,
  });
}
