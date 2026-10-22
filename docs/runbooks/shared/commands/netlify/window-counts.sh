#!/usr/bin/env bash
# Count JSONL log records, not invocations. Completeness cannot be inferred from count alone.
# Usage: window-counts.sh FUNCTION SECONDS START_UTC [START_UTC...]
# Optional NETLIFY_LOG_CAP: known record cap for the installed CLI/platform.
set -euo pipefail
fn=${1:?usage: window-counts.sh FUNCTION SECONDS START_UTC...}
secs=${2:?usage: window-counts.sh FUNCTION SECONDS START_UTC...}
shift 2
(( $# > 0 )) || { echo 'At least one START_UTC is required' >&2; exit 2; }
[[ "$secs" =~ ^[1-9][0-9]*$ ]] || { echo 'SECONDS must be a positive integer' >&2; exit 2; }
[[ -z ${NETLIFY_LOG_CAP:-} || ${NETLIFY_LOG_CAP} =~ ^[1-9][0-9]*$ ]] || { echo 'NETLIFY_LOG_CAP must be positive' >&2; exit 2; }
command -v netlify >/dev/null || { echo 'netlify CLI not found' >&2; exit 1; }
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
for start in "$@"; do
  end=$(python3 - "$start" "$secs" <<'PY'
from datetime import datetime, timedelta, timezone
import sys
try:
    start = datetime.fromisoformat(sys.argv[1].replace('Z', '+00:00'))
    if start.utcoffset() != timedelta(0):
        raise ValueError()
    print((start + timedelta(seconds=int(sys.argv[2]))).astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
except (ValueError, OverflowError):
    sys.exit('START_UTC must be an ISO timestamp with a zero UTC offset')
PY
)
  # A failed CLI invocation must never become a successful zero count. Keep stderr visible.
  netlify logs --source functions --function "$fn" --since "$start" --until "$end" --json > "$tmp"
  count=$(python3 - "$tmp" <<'PY'
import json, sys
count = 0
try:
    with open(sys.argv[1]) as stream:
        for line in stream:
            if not line.strip():
                continue
            if not isinstance(json.loads(line), dict):
                raise ValueError()
            count += 1
except (ValueError, OSError):
    sys.exit('Invalid JSONL object stream; log count unresolved')
print(count)
PY
)
  note='completeness=unverified'
  if [[ -n ${NETLIFY_LOG_CAP:-} ]] && (( count >= NETLIFY_LOG_CAP )); then
    note='possibly_truncated=true; shorten window or use a complete export'
  fi
  printf '%s  %s s  %s log_records  %s\n' "$start" "$secs" "$count" "$note"
done
