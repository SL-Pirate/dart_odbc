#!/usr/bin/env bash
#
# Prepares the container for `dart test`, then execs the given command.
set -euo pipefail

: "${DSN:=postgres}"
: "${DB_USER:=odbc_test}"
: "${DB_PASSWORD:=odbc_test}"
: "${DB_NAME:=odbc_test}"

# The tests read configuration from a '.env' file via package:dotenv. Writing
# the file here means the container works without relying on dotenv's
# platform-environment behaviour.
#
# The guard matters: a contributor may bind-mount a real .env, and we must never
# clobber it.
if [ ! -f .env ]; then
  echo "[entrypoint] writing .env for DSN='${DSN}'"
  cat > .env <<EOF
DSN='${DSN}'
USERNAME='${DB_USER}'
PASSWORD='${DB_PASSWORD}'
DATABASE='${DB_NAME}'
EOF
fi

# `dart pub get` exits non-zero at the repo root because it recurses into
# example/, a Flutter app that needs the Flutter SDK. It still writes a valid
# package_config.json, so tolerate that specific failure but verify the artifact
# that actually matters -- otherwise a real resolution failure would be masked.
dart pub get >/dev/null 2>&1 \
  || echo "[entrypoint] note: pub get warned (example/ needs Flutter); continuing"

if [ ! -f .dart_tool/package_config.json ]; then
  echo "[entrypoint] ERROR: dependency resolution genuinely failed" >&2
  dart pub get || true
  exit 1
fi

exec "$@"
