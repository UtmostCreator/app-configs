#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-full}"
TOTAL_STEPS=0
FAILED_STEPS=0

usage() {
  cat <<'EOF'
Usage: bash scripts/repo-health-check.sh [full|staged]

Modes:
  full    Run the full repo health matrix.
  staged  Run the full repo health matrix only when staged changes exist.
EOF
}

run_step() {
  local label="$1"
  shift
  TOTAL_STEPS=$((TOTAL_STEPS + 1))

  echo "==> $label"
  if "$@"; then
    echo "[OK] $label"
  else
    echo "[FAIL] $label" >&2
    FAILED_STEPS=$((FAILED_STEPS + 1))
  fi
}

case "$MODE" in
  full)
    ;;
  staged)
    cd "$ROOT_DIR"
    staged_files="$(git diff --cached --name-only --diff-filter=ACMRTUXB || true)"
    if [[ -z "$staged_files" ]]; then
      echo "No staged changes detected. Skipping repo health check."
      exit 0
    fi
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"

echo "== repo health check =="
echo "mode: $MODE"

tool_missing=0
for bin in bash git rg php just; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "[ERROR] required binary '$bin' missing" >&2
    tool_missing=1
  fi
done

if [[ "$tool_missing" -ne 0 ]]; then
  exit 1
fi

run_step "doctor" bash scripts/doctor.sh
run_step "ai-check" just ai-check
run_step "lint" just lint
run_step "test-php" just test-php
run_step "test-shell" just test-shell

echo "== summary =="
echo "steps: $TOTAL_STEPS"
echo "failures: $FAILED_STEPS"

if [[ "$FAILED_STEPS" -ne 0 ]]; then
  exit 1
fi

echo "Repo health check passed."
