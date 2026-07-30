# How to Contribute

## 1. Issue First

**Do not submit a Pull Request without an associated Issue.** If you have an idea for a feature or have found a bug, please [open an issue](https://github.com/SL-Pirate/dart_odbc/issues) first to discuss it. This ensures:
-   The change aligns with the project's goals.
-   You aren't working on something already being handled by someone else.
-   We agree on the implementation approach before you spend time coding.

## 2. Modular PRs
Keep PRs **small and focused**.
-   One PR = One Feature/Fix.
-   Do not bundle unrelated changes, metadata files, or style updates into a single PR.
-   PRs that change dozens of files for a single "helper function" will be closed without review.

## 3. Running the Tests

Docker is the only prerequisite. You do **not** need to install unixODBC, an ODBC
driver, or a database on your machine.

```bash
docker compose run --rm tests     # or: make test
```

This starts PostgreSQL, waits for it to be ready, seeds the schema, and runs the
suite inside an image that already has the ODBC driver manager and the
PostgreSQL ODBC driver installed.

While iterating, `make test-unit` runs the database-free unit tests natively and
returns in about a second. `make shell` gives you a shell in the ODBC
environment, where `isql -v postgres odbc_test odbc_test` tests the ODBC layer
without Dart involved — useful for telling a configuration problem apart from a
code problem.

Please make sure `make test` passes before opening a PR. CI runs the same
containers, so a green run locally means a green run in CI.

If you are **writing** tests rather than just running them, read
[`test/README.md`](test/README.md) first. It covers the suite's conventions —
most importantly that test files contain no SQL — and how to target a database
engine other than PostgreSQL.

## 4. Ethical Use of AI
While AI tools can assist in writing code, **you are responsible for every line you submit.** Do not submit unsupervised AI output.
-   If it is clear that you have not manually validated, tested, or understood the code you are pushing, the PR will be rejected.
-   We value human-curated contributions that respect the project's existing structure and logic.
