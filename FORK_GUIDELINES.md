# Fork and Contribution Guidelines

This repository is a **fork** of the original [dart_odbc](https://github.com/SL-Pirate/dart_odbc) package by SL-Pirate.

## Repository Information

- **Original Repository**: https://github.com/SL-Pirate/dart_odbc
- **Fork Repository**: https://github.com/cesar-carlos/dart_odbc
- **Original Maintainer**: SL-Pirate (isiraherath626@gmail.com)
- **License**: MIT

## Fork Management

- ✅ **Keep fork synchronized** with upstream repository
- ✅ **Use English for all commits** (Conventional Commits format)
- ✅ **Follow original project's coding standards** and architecture
- ✅ **Respect original maintainer's decisions** and project direction
- ✅ **Document fork-specific changes** in README or CHANGELOG if diverging

## Contribution Workflow

### For Contributing Back to Original Repository

1. **Create Pull Requests to Original Repository**:
   - Use the original repository's PR template (`.github/pull_request_template.md`)
   - Follow the checklist requirements:
     - [ ] Tests added to cover changes
     - [ ] All tests passed
     - [ ] Self-reviewed code
     - [ ] Documentation updated (if necessary)
     - [ ] Pana test passes with at least 150/160 points

2. **PR Types** (from template):
   - Bugfix
   - New Feature
   - Improvement
   - Documentation Update
   - Other (with description)

3. **Commit Message Format**:
   - Use **Conventional Commits** in English
   - Format: `type(scope): description`
   - Examples:
     - `fix(connection): resolve memory leak in disconnect`
     - `feat(cursor): add streaming support for large result sets`
     - `chore(deps): update dependencies`
     - `docs(readme): update usage examples`

### For Fork-Specific Changes

- ✅ **Document fork-specific changes** clearly
- ✅ **Maintain compatibility** with original API when possible
- ✅ **Create issues** in fork repository for tracking
- ✅ **Consider upstream contribution** for improvements that benefit the community

## Code of Conduct

- ✅ **Follow Contributor Covenant Code of Conduct** (see `CODE_OF_CONDUCT.md`)
- ✅ **Respectful communication** with all contributors
- ✅ **Report violations** to: isiraherath626@gmail.com (original maintainer)

## Issue Reporting

When reporting bugs, use the bug report template (`.github/ISSUE_TEMPLATE/bug_report.md`) and include:

- **Environment details**: OS, Architecture, Database, ODBC Driver, Driver Manager, Dart Version
- **Reproducible steps**: Database setup, configuration, triggering code
- **Expected vs Actual behavior**
- **Logs/Screenshots**: Stack traces, ODBC trace logs, debug output

## Testing Requirements

- ✅ **All tests must pass** before submitting PRs
- ✅ **Add tests** for new features or bug fixes
- ✅ **Run tests locally**: `dart test`
- ✅ **Pana test** must pass with at least 150/160 points

## Dependencies Management

- ✅ **Keep dependencies updated** regularly
- ✅ **Use `flutter pub upgrade`** to check for updates
- ✅ **Test thoroughly** after dependency updates
- ✅ **Document breaking changes** in CHANGELOG

## Original Project Standards

Based on the original repository structure and templates:

- ✅ **Style**: very_good_analysis (see badge in README)
- ✅ **Logging**: Uses `package:logging` for internal diagnostics
- ✅ **Platform Support**: Windows, Linux, macOS (desktop/server-side)
- ✅ **Database Support**: SQL Server, Oracle, MariaDB/MySQL (tested)

## Commit Standards

All commits must follow **Conventional Commits** format in English:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks (dependencies, build, etc.)
- `perf`: Performance improvements
- `ci`: CI/CD changes

### Examples:

```bash
feat(cursor): add streaming support for large result sets

fix(connection): resolve memory leak in disconnect method

chore(deps): update ffi from ^2.1.2 to ^2.1.5

docs(readme): update usage examples with new API
```
