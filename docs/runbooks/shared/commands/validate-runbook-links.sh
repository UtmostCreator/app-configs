#!/usr/bin/env bash
# Validate runbook frontmatter, relative links, anchors and RB-xx/XXX-nn step references.
# Usage: validate-runbook-links.sh [RUNBOOK_DIR]   (default: docs/runbooks)
set -euo pipefail
root=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
errors=0
fail() { echo "FAIL: $*" >&2; errors=$((errors + 1)); }

slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9 _-]//g; s/ /-/g'; }

has_anchor() { # file anchor
  local f=$1 a=$2 h
  while IFS= read -r h; do
    [[ "$(slug "${h#\#* }")" == "$a" ]] && return 0
    h=${h#"${h%%[! #]*}"}
    [[ "$(slug "$h")" == "$a" ]] && return 0
  done < <(grep -E '^#{1,6} ' "$f" | sed -E 's/^#{1,6} //')
  return 1
}

declare -A file_of_id
mapfile -t files < <(find "$root" -name '*.md' -not -path '*/node_modules/*' | sort)

for f in "${files[@]}"; do
  [[ "$(head -n 1 "$f")" == "---" ]] || { fail "$f: missing frontmatter"; continue; }
  fmt=$(awk 'NR==1 {next} /^---$/ {exit} {print}' "$f")
  for key in id title type status updated; do
    grep -q "^$key:" <<<"$fmt" || fail "$f: frontmatter missing '$key'"
  done
  id=$(sed -n 's/^id: //p' <<<"$fmt")
  [[ -n "$id" ]] && file_of_id["$id"]=$f
done

for f in "${files[@]}"; do
  dir=$(dirname "$f")
  # relative links and anchors
  while IFS= read -r link; do
    target=${link%%#*}; anchor=""
    [[ "$link" == *"#"* ]] && anchor=${link#*#}
    case "$link" in http*|mailto:*|'') continue ;; esac
    dest=$f
    if [[ -n "$target" ]]; then
      dest="$dir/$target"
      [[ -e "$dest" ]] || { fail "$f: broken link '$link'"; continue; }
    fi
    if [[ -n "$anchor" && -f "$dest" && "$dest" == *.md ]]; then
      has_anchor "$dest" "$anchor" || fail "$f: missing anchor '#$anchor' in ${dest#"$root"/}"
    fi
  done < <(awk '/^```/ {fence = !fence; next} !fence' "$f" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//' | grep -vE '^(http|mailto:)' || true)

  # step references: RB-xx/ABC-nn
  while IFS= read -r ref; do
    rid=${ref%%/*}; sid=${ref#*/}
    dest=${file_of_id[$rid]:-}
    if [[ -z "$dest" ]]; then fail "$f: unknown runbook in reference $ref"; continue; fi
    grep -qE "^## $sid\$" "$dest" || fail "$f: unknown step in reference $ref"
  done < <(grep -oE '\bRB-[0-9]{2}/[A-Z]{3}-[0-9]{2}\b' "$f" | sort -u || true)

  # steps listed in frontmatter must exist as headings
  steps=$(sed -n 's/^steps: \[\(.*\)\]$/\1/p' "$f" | tr -d ' ' | tr ',' '\n')
  for s in $steps; do
    grep -qE "^## $s\$" "$f" || fail "$f: frontmatter step $s has no heading"
  done
done

if (( errors > 0 )); then echo "$errors problem(s) found" >&2; exit 1; fi
echo "OK: ${#files[@]} files validated"
