#!/usr/bin/env bash
# Method and status counts for one request path (for example, is a GraphQL endpoint hit by GET or POST).
# Access logs do not contain request bodies, so this cannot show which operations were run.
# Usage: method-by-path.sh LOG PATH      Optional: WINDOW='<timestamp regex>'
set -euo pipefail
log=${1:?usage: method-by-path.sh LOG PATH}
path=${2:?usage: method-by-path.sh LOG PATH}
[[ -r "$log" ]] || { echo "Cannot read $log (try sudo)" >&2; exit 1; }
window_filter() { if [[ -n "${WINDOW:-}" ]]; then grep -E "\[${WINDOW}" || true; else cat; fi; }
zcat -f -- "$log" | window_filter | awk -F'"' -v want="$path" '
  { split($2, r, " "); split($3, s, " "); p = r[2]; sub(/\?.*/, "", p); if (p == want) c[r[1] " " s[1]]++ }
  END { for (k in c) print c[k], k }' | sort -nr
