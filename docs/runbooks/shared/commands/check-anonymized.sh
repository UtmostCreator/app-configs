#!/usr/bin/env bash
# Privacy lint for the runbooks: flags real-looking IP addresses, hostnames, emails, home paths,
# ticket ids and token-like strings. Only localhost, RFC 5737 documentation addresses and
# example.* domains are allowed. Usage: check-anonymized.sh [RUNBOOK_DIR]
set -euo pipefail
root=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
errors=0
report() { echo "FAIL: $1" >&2; errors=$((errors + 1)); }

# IPv4 other than 127.0.0.1, 0.0.0.0 and the documentation ranges 192.0.2/198.51.100/203.0.113
while IFS= read -r line; do report "IP address: $line"; done < <(
  grep -rnoE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$root" --include='*.md' --include='*.sh' |
  grep -vE ':(127\.0\.0\.1|0\.0\.0\.0|192\.0\.2\.[0-9]+|198\.51\.100\.[0-9]+|203\.0\.113\.[0-9]+)$' || true)

# Hostnames with common TLDs that are not placeholders or well-known public documentation hosts
allow='(^|\.)(example\.(com|org|net|test)|netlify\.com|apache\.org|kernel\.org|php\.net|w3\.org|nuxt\.com\.dev|laravel\.com|redis\.io|github\.com|shellcheck\.net)$'
while IFS= read -r hit; do
  host=${hit##*:}
  [[ "$host" =~ $allow ]] || report "hostname: $hit"
done < <(grep -rnoE '\b[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.(com|net|org|io|dev|co\.uk|uk|app|cloud|test)\b' "$root" --include='*.md' --include='*.sh' || true)

while IFS= read -r line; do report "email: $line"; done < <(grep -rnoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$root" --include='*.md' --include='*.sh' || true)
while IFS= read -r line; do report "home path: $line"; done < <(grep -rnoE '/(Users|home)/[A-Za-z0-9_.-]+' "$root" --include='*.md' --include='*.sh' | grep -vE '/home/<|/Users/<' || true)
while IFS= read -r line; do report "ticket id: $line"; done < <(grep -rnoE '\b(DEV|JIRA|TICKET|PROJ)-[0-9]{2,}\b' "$root" --include='*.md' --include='*.sh' || true)
while IFS= read -r line; do report "token-like string: $line"; done < <(grep -rnoE '\b(ghp_|gho_|sk_live_|pk_live_|xox[bp]-|AKIA)[A-Za-z0-9]{8,}' "$root" --include='*.md' --include='*.sh' || true)

if (( errors > 0 )); then echo "$errors anonymisation problem(s) found" >&2; exit 1; fi
echo "OK: no identifying addresses, hosts, emails, paths, ticket ids or tokens found"
