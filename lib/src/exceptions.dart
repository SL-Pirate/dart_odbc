/// Generic odbc exception.
class ODBCException implements Exception {
  /// Constructor.
  ODBCException(this.message);

  /// Error message.
  String message;

  /// Error code returned from the ODBC driver
  int? code;

  @override
  String toString() {
    var txt = message;
    if (code != null) {
      txt += '\nErrorCode: $code';
    }

    return txt;
  }
}

/// Exception thrown when a connection to the database cannot be established.
class ConnectionException extends ODBCException {
  /// Constructor.
  ConnectionException()
      : super('Connection to the database could not be established');
}

/// Exception thrown when a query cannot be executed.
class QueryException extends ODBCException {
  /// Constructor.
  QueryException() : super('Query could not be executed');
}

/// Exception thrown when preparing a statement fails.
class PrepareException extends ODBCException {
  /// Constructor.
  PrepareException() : super('Statement could not be prepared');
}

/// Exception thrown when resources cannot be allocated for handle
class HandleException extends ODBCException {
  /// Constructor.
  HandleException() : super('Handle could not be allocated');
}

/// Exception thrown when environment cannot be allocated.
class EnvironmentAllocationException extends ODBCException {
  /// Constructor.
  EnvironmentAllocationException()
      : super('Environment could not be allocated');
}

/// Exception thrown when result set cannot be fetched.
class FetchException extends ODBCException {
  /// Constructor.
  FetchException() : super('Result set could not be fetched');
}
