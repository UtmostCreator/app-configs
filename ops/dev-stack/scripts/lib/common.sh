#!/usr/bin/env sh

: "${SCRIPT_DIR:?SCRIPT_DIR must be set before sourcing common.sh}"

STACK_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
WORKSPACE_ROOT=$(CDPATH= cd -- "$STACK_ROOT/.." && pwd)
REPOS_YAML="$STACK_ROOT/config/repositories.yml"

info() { printf '  %s\n' "$*"; }
ok() { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*" >&2; }
fail() { printf '  [FAIL] %s\n' "$*" >&2; }
step() { printf '\n==> %s\n' "$*"; }
die() { fail "$*"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

assert_profile() {
    case "${1:-}" in
        internal) return 0 ;;
        *) die "Unknown profile '${1:-}'. Valid values: internal" ;;
    esac
}

assert_compose_profile() {
    case "${1:-}" in
        internal|test|tools) return 0 ;;
        *) die "Unknown Compose profile '${1:-}'. Valid values: internal, test, tools" ;;
    esac
}

require_value() {
    [ -n "${2:-}" ] || die "$1 requires a value"
}

usage_error() {
    fail "$1"
    exit 2
}