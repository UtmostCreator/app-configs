#!/usr/bin/env bash
# Health runner.
#
# Discovers every executable file in scripts/projects/health/checks.d/,
# runs it once, collects its JSON output, and emits an aggregate
# JSON document:
#
#   {
#     "checks": [ {name, section, status, note, fix}, ... ],
#     "overall": { "status": "ok|fail|warn", "passed": N, "failed": N }
#   }
#
# Modes:
#   default        — pretty-print via render.sh (or jq fallback)
#   --json         — raw aggregate JSON on stdout
#   --quiet        — no output; exit 0 if all ok, 1 if any fail
#
# Usage:
#   bash scripts/projects/health/run.sh
#   bash scripts/projects/health/run.sh --json
#   bash scripts/projects/health/run.sh --quiet

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/projects/health/lib.sh
source "$SCRIPT_DIR/lib.sh"

MODE="pretty"
for arg in "$@"; do
  case "$arg" in
    --json)  MODE="json" ;;
    --quiet) MODE="quiet" ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) proj_fail "unknown arg: $arg" ;;
  esac
done

require_cmd jq

CHECKS_DIR="$SCRIPT_DIR/checks.d"
if [[ ! -d "$CHECKS_DIR" ]]; then
  proj_fail "no checks.d/ at $CHECKS_DIR"
fi

# Run every check, collect JSON lines.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
for chk in "$CHECKS_DIR"/*.sh; do
  [[ -f "$chk" ]] || continue
  bash "$chk" >>"$TMP" 2>/dev/null || true
done

# Aggregate.
AGG="$(jq -nc --slurpfile checks <(jq -nc 'inputs' <"$TMP" 2>/dev/null || echo '[]') '
  ($checks | flatten) as $all |
  ($all | map(select(.status == "ok"))   | length) as $ok |
  ($all | map(select(.status == "fail")) | length) as $fail |
  ($all | map(select(.status == "warn")) | length) as $warn |
  {
    checks: $all,
    overall: {
      status: (if $fail > 0 then "fail" elif $warn > 0 then "warn" else "ok" end),
      passed: $ok,
      failed: $fail,
      warned: $warn
    }
  }
')"

case "$MODE" in
  json)
    printf '%s\n' "$AGG"
    ;;
  quiet)
    [[ "$(jq -r '.overall.status' <<<"$AGG")" == "ok" ]]
    exit
    ;;
  pretty)
    if [[ -x "$SCRIPT_DIR/render.sh" ]] || [[ -f "$SCRIPT_DIR/render.sh" ]]; then
      printf '%s\n' "$AGG" | bash "$SCRIPT_DIR/render.sh"
    else
      printf '%s\n' "$AGG" | jq .
    fi
    [[ "$(jq -r '.overall.status' <<<"$AGG")" == "ok" ]]
    exit
    ;;
esac
