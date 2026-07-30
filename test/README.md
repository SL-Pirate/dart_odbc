# Test suite internals

How this suite is put together, how to add a test, and how to target another
database engine.

For **running** the tests, see the "Running the tests" section of the root
[`README.md`](../README.md). This document is about extending them.

## Layout

```
test/
├── unit/                  Pure Dart. No database, no Docker.
├── integration/           Real ODBC connections against a live database.
├── update_test.dart       Integration test (kept here for historical reasons).
├── test_helper.dart       Connection lifecycle + the run()/sql() entry points.
├── schema/                Fixtures per engine, named after the dialect.
│   ├── postgres.sql
│   └── mariadb.sql
└── support/
    ├── test_database.dart The Sql keys and the TestDatabase contract.
    └── impl/              One dialect per file.
        ├── test_database_postgres_dialect.dart
        └── test_database_mariadb_dialect.dart
```

`test/unit` needs nothing installed and runs in about a second — use it for
anything that does not genuinely require a database.

## The golden rule: tests contain no SQL

This suite exercises the ODBC/FFI layer, not any one vendor's SQL. So test files
never contain SQL. They name a statement and the active dialect translates it,
the same way a localization map turns a message key into text for a locale:

```dart
final rows = await helper.run(Sql.selectAllUsers);
// postgres  -> SELECT * FROM "USERS"
// sqlserver -> SELECT * FROM [USERS]
```

Keeping SQL out of the tests is what allows a single suite to verify the library
against several engines. `test/support/` is the only place SQL belongs.

## Writing a new test

A minimal integration test:

```dart
import 'package:test/test.dart';

import '../support/test_database.dart';
import '../test_helper.dart';

void main() {
  final helper = TestHelper();

  setUpAll(helper.initialize);
  tearDownAll(helper.disconnect);

  test('describe the behaviour under test', () async {
    final rows = await helper.run(Sql.selectUserNameById, params: [1]);

    expect(rows.length, 1);
    expect(rows.first['NAME'], isA<String>());
  });
}
```

The helper API:

| Call | Purpose |
| --- | --- |
| `helper.run(key, params: [...])` | Execute a named statement, get rows back. |
| `helper.runCursor(key, params: [...])` | Same, as a cursor. |
| `helper.sql(key)` | The translated SQL string, when you need to pass it to a client you constructed yourself. |
| `helper.id('NAME')` | Quote an identifier for the active engine. |
| `helper.dialect.dateParam(dt)` | Bind a `DateTime` the way this driver expects. |

### If your test needs SQL that does not exist yet

Do **not** inline it. Add a key instead:

1. Add a value to the `Sql` enum in `support/test_database.dart`, with a doc
   comment stating what it returns and what parameters it takes, in order.
2. Add the translation to every dialect in `support/impl/`.
3. Use it via `helper.run(...)`.

Step 2 is not optional and not easy to forget: `Sql` is matched with an
exhaustive `switch`, so a dialect missing a translation is a **compile error**,
not a failure on whichever test happens to run first.

### Assertions on column names

Column keys come back exactly as the driver reports them, so they follow the
schema. The fixtures use quoted upper-case identifiers (`"USERS"`, `"UID"`),
which PostgreSQL preserves — unquoted identifiers would be folded to lower case
and every key would arrive as `uid` instead of `UID`. Assert on `'UID'`, and if
you add a column, quote it in the schema too.

### Things to keep in mind

- **Suites run concurrently**, each opening its own connection. Do not assume
  ordering between files.
- **Write tests must be self-cleaning.** `insert_test` and `update_test` delete
  their row before inserting it, so reruns pass. Follow that pattern and use a
  dedicated id (1001, 1002, ...) rather than mutating the seeded rows.
- **Nothing may require a human.** No GUI, no interactive prompt, no sleeping to
  let someone look at output. `binary_test.dart` shows the pattern: assertions
  always run, and the image viewer is behind `SHOW_TEST_IMAGE=1`.
- **No wall-clock padding.** If you need to wait for something, wait for the
  thing itself, not a fixed delay.

## Targeting another database engine

The library works with any engine that has an ODBC driver. CI verifies
**PostgreSQL and MariaDB** — two engines with genuinely different quoting,
database selection, and binary types — which is what keeps the abstraction
honest rather than merely aspirational.

```bash
make test           # PostgreSQL
make test-mariadb   # MariaDB, same suite, no test file changes
make test-all       # both
```

Adding another engine takes five steps and **no changes to any test file**.
`support/impl/test_database_mariadb_dialect.dart` is the worked example to copy;
read it alongside the PostgreSQL one to see what actually varies.

### 1. Write the dialect

Add `support/impl/test_database_<name>_dialect.dart` as a `part` of
`support/test_database.dart`, and declare it there:

```dart
part 'impl/test_database_<name>_dialect.dart';
```

Then translate every `Sql` key. Sketched for SQL Server:

```dart
part of '../test_database.dart';

class SqlServerDialect extends TestDatabase {
  const SqlServerDialect();

  @override
  String get name => 'sqlserver';

  // T-SQL brackets, where PostgreSQL uses double quotes and MariaDB backticks.
  @override
  String id(String raw) => '[$raw]';

  // T-SQL selects a database with a statement, as MariaDB does; PostgreSQL
  // selects it at connect time and returns null here.
  @override
  String? useDatabase(String database) => 'USE ${id(database)}';

  @override
  String sql(Sql key) => switch (key) {
        Sql.selectAllUsers => 'SELECT * FROM [USERS]',
        // ... one arm per Sql value; the compiler enforces completeness.
      };
}
```

Only `name`, `sql` and `id` are required. `useDatabase`, `dateParam` and
`schemaPath` have defaults on `TestDatabase` — override them only when the engine
differs.

Watch out for these, which is where the two existing dialects actually diverge:

- **Identifier quoting and case folding.** `"X"` in PostgreSQL, `` `X` `` in
  MariaDB, `[X]` in T-SQL. Get this wrong and every returned column key changes.
  Both current schemas use quoted upper case so the assertions match; note that
  MariaDB only preserves table-name case when `lower_case_table_names=0`, which
  is the default on Linux but not on macOS or Windows.
- **Database selection.** PostgreSQL selects at connect time (`useDatabase`
  returns `null`); MariaDB and SQL Server use a `USE` statement.
- **Binary columns.** `BYTEA` in PostgreSQL, `VARBINARY` in MariaDB, and whether
  the driver reports them as a binary type at all. If `binary_test` gets a
  `String` instead of a `Uint8List`, the driver is reporting the column as text —
  usually fixed with a driver option in `docker/odbc.ini`, not in Dart.
  PostgreSQL needs `ByteaAsLongVarBinary=1`; MariaDB needs nothing.
- **Untyped parameters.** Some engines cannot infer the type of a bare `?` and
  need an explicit cast. Both current engines bind it fine.
- **Date binding.** `DateTime` binds as a timestamp; engines vary on comparing
  that against a date column. Override `dateParam` if needed.
- **A long-text query.** `selectLongText` must return more than 4096 characters
  or the incremental `SQLGetData` path is never exercised and the test silently
  stops testing anything. This bites easily: PostgreSQL's `version()` is ~88
  characters and MariaDB's is ~22, so both dialects repeat it to clear the
  buffer. Check the length rather than assuming.

### 2. Register it

Add a case to `TestDatabase.resolve()` in `support/test_database.dart`:

```dart
'sqlserver' => const SqlServerDialect(),
```

An unrecognised `TEST_DB` fails immediately with a message naming what to do, so
a half-registered dialect cannot silently fall back to PostgreSQL.

### 3. Add the schema

Create `schema/<name>.sql` defining `USERS` and `BINARY_TABLE` with the same
columns and seed rows as `schema/postgres.sql`, in that engine's types. Keep the
identifier casing consistent with the dialect's `id()`.

### 4. Install the driver and DSN

In `docker/Dockerfile.tests`, install that engine's ODBC driver. In
`docker/odbc.ini`, add a DSN stanza named after the engine, pointing at the
compose service hostname.

Note that the driver has to be installed in the **runner image**, not the
database container: the library calls `DynamicLibrary.open('libodbc.so')`
in-process, so the driver must be present wherever the Dart process runs.

### 5. Add the compose services

Add two services to `docker-compose.yml`, both behind a `profiles: ["<name>"]`
entry so the default run stays a single database:

- the database itself, mounting `schema/<name>.sql` into
  `/docker-entrypoint-initdb.d/` and declaring a **healthcheck**;
- a runner, copying the `tests` service but with `TEST_DB` and `DSN` set to your
  engine and `depends_on` pointing at your database with
  `condition: service_healthy`.

The healthcheck is required, not cosmetic: the library never sets a login
timeout, so connecting to a database that is not yet accepting connections blocks
indefinitely rather than failing. A separate runner service is needed because
`depends_on` cannot be varied per invocation.

Mirror the `mariadb` and `tests-mariadb` pair — it is exactly this shape.

### Then run it

```bash
docker compose --profile <name> run --rm tests-<name>
```

Add a `test-<name>` target to the `Makefile` and a matrix entry to
`.github/workflows/ci.yml` so CI covers it too.

## Debugging

`make shell` opens a shell in the runner image, where `isql` talks to the
database without Dart in the picture:

```bash
isql -v postgres odbc_test odbc_test   # or: isql -v mariadb odbc_test odbc_test
odbcinst -q -d                         # which drivers are registered
```

This is the fastest way to split a problem in two. If `isql` connects and the
Dart tests do not, the problem is in the FFI layer or the test code. If `isql`
also fails, the problem is the ODBC configuration — the DSN, the driver, or the
database itself.
