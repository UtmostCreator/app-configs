#!/usr/bin/env bash
# Health runner.
#
# Discovers every executable file in ops/projects/health/checks.d/,
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
#   --quiet        — no output
#
# Exit-code contract for all modes:
#   0 — overall.failed == 0 (covers ok and warn-only runs)
#   1 — overall.failed >= 1
#
# Warnings deliberately do NOT fail automation. Anything you want to
# actually fail CI should emit status "fail" inside its checks.d script.
#
# Usage:
#   bash ops/projects/health/run.sh
#   bash ops/projects/health/run.sh --json
#   bash ops/projects/health/run.sh --quiet

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/projects/health/lib.sh
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
CHECK_TMP=''
trap 'rm -f "$TMP"; [[ -z "$CHECK_TMP" ]] || rm -f "$CHECK_TMP"' EXIT
for chk in "$CHECKS_DIR"/*.sh; do
  [[ -f "$chk" ]] || continue
  CHECK_TMP=$(mktemp)
  if bash "$chk" >"$CHECK_TMP" 2>/dev/null; then check_status=0; else check_status=$?; fi
  # A check must produce at least one well-formed record and exit successfully.
  # Invalid output is discarded rather than partially accepted as healthy.
  if (( check_status == 0 )) && jq -es '
    length > 0 and all(.[];
      type == "object" and
      (.name | type == "string" and length > 0) and
      (.section | type == "string") and
      (.note | type == "string") and
      (.status == "ok" or .status == "warn" or .status == "fail"))
    ' "$CHECK_TMP" >/dev/null 2>&1; then
    cat "$CHECK_TMP" >>"$TMP"
  else
    PROJ_CHECK_NAME="$(basename "$chk")" proj_emit fail "checks" \
      "check failed, emitted no records, or emitted invalid records (exit $check_status)" >>"$TMP"
  fi
  rm -f "$CHECK_TMP"
done
if [[ ! -s "$TMP" ]]; then
  PROJ_CHECK_NAME="check-discovery" proj_emit fail "checks" "no checks produced results" >>"$TMP"
fi

# Aggregate.
if ! AGG="$(jq -nc --slurpfile checks "$TMP" '
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
')"; then
  proj_fail "could not aggregate health results"
fi

# Exit-code contract (documented at the top of this file):
#   0 — all ok, or warn-only (no checks have status == fail)
#   1 — at least one check has status == fail
#
# Codex P2b: the previous '== ok' guard treated warn as failure too,
# which made --quiet exit non-zero on warning-only runs even though the
# docstring promised "exit 0 if all ok, 1 if any fail". We now key on
# overall.failed > 0, which mirrors the doc and lets warn-only runs
# pass automation gates.
final_exit() {
  local failed
  failed="$(jq -r '.overall.failed' <<<"$AGG")"
  if [[ "$failed" -gt 0 ]]; then
    return 1
  fi
  return 0
}

case "$MODE" in
  json)
    printf '%s\n' "$AGG"
    final_exit
    exit
    ;;
  quiet)
    final_exit
    exit
    ;;
  pretty)
    if [[ -x "$SCRIPT_DIR/render.sh" ]] || [[ -f "$SCRIPT_DIR/render.sh" ]]; then
      printf '%s\n' "$AGG" | bash "$SCRIPT_DIR/render.sh"
    else
      printf '%s\n' "$AGG" | jq .
    fi
    final_exit
    exit
    ;;
esac
