#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$SCRIPT_DIR/core.php"

if [[ ! -r "$CORE" ]]; then
  printf 'log-errors: required core is missing or unreadable: %s\n' "$CORE" >&2
  exit 4
fi
if ! command -v php >/dev/null 2>&1; then
  printf 'log-errors: PHP 8.2 or newer is required.\n' >&2
  exit 4
fi
if ! php -r 'exit(version_compare(PHP_VERSION, "8.2.0", ">=") ? 0 : 1);' >/dev/null 2>&1; then
  printf 'log-errors: PHP 8.2 or newer is required (found %s).\n' "$(php -r 'echo PHP_VERSION;' 2>/dev/null || printf unknown)" >&2
  exit 4
fi
if ! php -l "$CORE" >/dev/null 2>&1; then
  printf 'log-errors: required core failed PHP syntax validation: %s\n' "$CORE" >&2
  exit 4
fi

exec php "$CORE" "$@"
