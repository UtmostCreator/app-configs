#!/usr/bin/env bash
# Privacy lint for the runbooks: flags real-looking IP addresses, hostnames, emails, home paths,
# ticket ids and token-like strings. Only localhost, RFC 5737 documentation addresses and
# example.* domains are allowed. Usage: check-anonymized.sh [RUNBOOK_DIR]
set -euo pipefail
root=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
errors=0
report() { echo "FAIL: $1" >&2; errors=$((errors + 1)); }
[[ -d "$root" && -r "$root" ]] || { echo 'FAIL: unreadable scan directory' >&2; exit 2; }
# Keep one coverage list for every pattern. Binary artifacts are outside this text lint.
formats=(--include='*.md' --include='*.sh' --include='*.py' --include='*.jq'
  --include='*.json' --include='*.jsonl' --include='*.yaml' --include='*.yml'
  --include='*.toml' --include='*.ini' --include='*.conf' --include='*.txt'
  --include='*.csv' --include='*.tsv' --include='*.log' --include='*.fixture'
  --include='*.env' --include='.env' --include='.env.*')

# IPv4 other than 127.0.0.1, 0.0.0.0 and the documentation ranges 192.0.2/198.51.100/203.0.113
while IFS= read -r line; do report "IP address: $line"; done < <(
  grep -rnoE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$root" "${formats[@]}" |
  grep -vE ':(127\.0\.0\.1|0\.0\.0\.0|192\.0\.2\.[0-9]+|198\.51\.100\.[0-9]+|203\.0\.113\.[0-9]+)$' || true)

# Hostnames with common TLDs that are not placeholders or well-known public documentation hosts
allow='(^|\.)(example\.(com|org|net|test)|netlify\.com|apache\.org|kernel\.org|php\.net|w3\.org|nuxt\.com\.dev|laravel\.com|redis\.io|github\.com|shellcheck\.net|freedesktop\.org)$'
while IFS= read -r hit; do
  host=${hit##*:}
  [[ "$host" =~ $allow ]] || report "hostname: $hit"
done < <(grep -rnoE '\b[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.(com|net|org|io|dev|co\.uk|uk|app|cloud|test)\b' "$root" "${formats[@]}" || true)

while IFS= read -r line; do report "email: $line"; done < <(grep -rnoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$root" "${formats[@]}" || true)
while IFS= read -r line; do report "home path: $line"; done < <(grep -rnoE '/(Users|home)/[A-Za-z0-9_.-]+' "$root" "${formats[@]}" | grep -vE '/home/<|/Users/<' || true)
while IFS= read -r line; do report "ticket id: $line"; done < <(grep -rnoE '\b(DEV|JIRA|TICKET|PROJ)-[0-9]{2,}\b' "$root" "${formats[@]}" || true)
while IFS= read -r line; do report "token-like string: $line"; done < <(grep -rnoE '\b(ghp_|gho_|sk_live_|pk_live_|xox[bp]-|AKIA)[A-Za-z0-9]{8,}' "$root" "${formats[@]}" || true)
# Cloud internal hostnames encode the private address (for example ip-a-b-c-d in EC2 server names).
while IFS= read -r line; do report "cloud hostname: $line"; done < <(grep -rnoE '\bip-[0-9]{1,3}(-[0-9]{1,3}){3}\b' "$root" "${formats[@]}" || true)

# Optional private denylist (brand, product, vendor, site names), one fixed string per line, '#' comments.
# Keep the file outside the repository; matches report file:line only, never the term itself.
if [[ -n ${ANON_DENYLIST:-} ]]; then
  [[ -f "$ANON_DENYLIST" && -r "$ANON_DENYLIST" ]] || { echo 'FAIL: unreadable ANON_DENYLIST file' >&2; exit 2; }
  terms=()
  while IFS= read -r term; do terms+=(-e "$term"); done < <(grep -vE '^[[:space:]]*(#|$)' "$ANON_DENYLIST" || true)
  if (( ${#terms[@]} > 0 )); then
    while IFS= read -r line; do report "denylist term: $line"; done < <(
      grep -rniF "${terms[@]}" "$root" "${formats[@]}" | cut -d: -f1,2 || true)
  fi
fi

if (( errors > 0 )); then echo "$errors anonymisation problem(s) found" >&2; exit 1; fi
echo "OK: no identifying addresses, hosts, emails, paths, ticket ids or tokens found"
