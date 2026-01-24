# Dart ODBC Examples

This directory contains runnable examples demonstrating how to use the `dart_odbc` package.

## Available Examples

### 1. Basic Example (`example.dart`)

A simple console application that demonstrates basic ODBC operations:

```bash
cd example
dart run lib/example.dart "SELECT * FROM USERS WHERE UID = ?" 1
```

**Features demonstrated:**
- Connecting to database using DSN
- Executing queries with prepared statements
- Error handling

### 2. File Database Example (`example_connect_to_file_db.dart`)

Demonstrates connecting to file-based databases (Excel, Access, CSV, etc.):

```bash
cd example
dart run lib/example_connect_to_file_db.dart
```

**Features demonstrated:**
- Connecting via connection string (no DSN required)
- Listing tables/sheets
- Reading data from file-based databases

**Required environment variables** (in `.env` file):
- `DRIVER_NAME` - ODBC driver name (e.g., "Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)")
- `PATH_TO_FILE` - Path to the database file

### 3. Flutter Application Example (`example_flutter_app.dart`)

A complete Flutter application demonstrating ODBC operations in a UI:

```bash
cd example
flutter run
```

**Features demonstrated:**
- Non-blocking vs blocking client comparison
- Real-time UI updates during database operations
- Handling binary data
- Error display in UI

### 4. Helper Class (`helper.dart`)

A utility class for testing and examples that encapsulates common ODBC operations.

## Setup

1. **Create `.env` file** in the `example` directory:

```env
DSN=your_dsn_name
USERNAME=your_username
PASSWORD=your_password
DATABASE=your_database_name
```

2. **For file database example**, also add:

```env
DRIVER_NAME=Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)
PATH_TO_FILE=/path/to/your/file.xlsx
```

3. **Install dependencies**:

```bash
cd example
flutter pub get
```

## Running Examples

### Console Examples

```bash
# Basic example
dart run lib/example.dart "SELECT * FROM USERS"

# File database example
dart run lib/example_connect_to_file_db.dart
```

### Flutter Example

```bash
flutter run
```

## Notes

- All examples use the `dotenv` package for environment variables
- Make sure your ODBC driver is properly configured before running examples
- The Flutter example requires a Flutter development environment
