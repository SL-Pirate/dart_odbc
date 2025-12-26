---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: SL-Pirate

---

## Summary

<!-- One–two sentences: what is broken and why it matters -->
A clear, concise description of the problem.

## 🔁 Steps to Reproduce

Provide the smallest reproducible example.

1. Environment Setup
<!-- Include only what is required to reproduce -->

### Database setup (DDL / schema)

### Required configuration (DSN, connection string, driver options)

```sql
-- Example: schema + seed data
CREATE TABLE example (...);
INSERT INTO example VALUES (...);
```

2. Triggering Code / Queries
<!-- SQL, Dart, or native code that reliably reproduces the issue -->

```sql
-- SQL that triggers the bug
```

```dart
// Dart code calling `DartOdbc`
```

## ✅ Expected Behavior

What should happen?

## ❌ Actual Behavior

What actually happens?

Error messages

Incorrect data

Crashes / memory corruption

Performance issues

Include exact error output when possible.

## 📸 Logs / Screenshots

If applicable, attach:

Stack traces

ODBC trace logs

Debug output

Screenshots (only if they add clarity)

## 🧩 Environment

Please complete all that apply:

1. OS: (e.g. Linux, Windows 11)

2. Architecture: (x64, arm64)

3. Database: (e.g. SQL Server 2025)

4. ODBC Driver: (e.g. msodbcsql-18 x64)

5. Driver Manager: (e.g. unixODBC 2.3.12 / iODBC)

6. Dart Version: (e.g. 3.10.4 stable)

7. `DartOdbc` Version / Commit: (tag, version, or commit hash)

## 🧠 ABI / ODBC Details

## 🔍 Regression?

This worked in a previous version

First time in `DartOdbc`?

If yes, specify the last known working version.

## 🧪 Workarounds

Have you found any temporary workaround or mitigation?

## 📝 Additional Context

Anything else useful:

Platform-specific behavior

Comparison with native ODBC usage

Notes from debugging / tracing

Spec references (ODBC / driver docs)
