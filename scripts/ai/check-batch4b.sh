#!/usr/bin/env bash
set +e

LOG_DIR=".copilot-logs/checks"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/batch4b-shellcheck-$(date +%Y%m%d-%H%M%S).log"
bad=0

files=(
  scripts/ai/ai-test-select.sh
  scripts/ai/ai-doc-check.sh
  scripts/ai/pre-tool-use.sh
)

{
  echo "Batch 4B shell verification"
  echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo

  for f in "${files[@]}"; do
    echo
    echo "== file $f =="

    if [ ! -f "$f" ]; then
      echo "MISSING: $f"
      bad=1
      continue
    fi

    tr -d '\r' < "$f" > "$f.tmp" && mv "$f.tmp" "$f"

    echo
    echo "== bash -n $f =="
    if ! bash -n "$f"; then
      bad=1
    fi

    echo
    echo "== shellcheck -x -e SC1091 $f =="
    if ! shellcheck -x -e SC1091 "$f"; then
      bad=1
    fi
  done

  echo
  if [ "$bad" -eq 0 ]; then
    echo "Batch 4B checks passed."
  else
    echo "Batch 4B checks failed."
  fi

  echo
  echo "Log: $LOG_FILE"
} 2>&1 | tee "$LOG_FILE"

if [ "${STRICT:-0}" = "1" ]; then
  exit "$bad"
fi

exit 0
