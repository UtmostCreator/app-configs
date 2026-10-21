#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

VERIFY_SCRIPT="${VERIFY_SCRIPT:-$WS_SCRIPT_VERIFY_WORKSPACE}"

command -v jq >/dev/null 2>&1 || { echo "Missing required command: jq" >&2; exit 127; }
command -v fzf >/dev/null 2>&1 || { echo "Missing required command: fzf" >&2; exit 127; }

if data="$(WS_VERIFY_FAST=1 "$VERIFY_SCRIPT" --json 2>/dev/null)"; then
  :
elif [[ -z "${data:-}" ]]; then
  echo "ws-verify did not return JSON output" >&2
  exit 1
fi

selected="$({
  jq -r '.checks[] | select((.fix // "") != "") | [.name, .fix] | @tsv' <<<"$data" | awk -F'\t' '!seen[$2]++'
} | fzf --height 40% --border --prompt 'Run fix > ' --delimiter=$'\t' --with-nth 1,2)"

[[ -z "$selected" ]] && exit 0

cmd="$(printf '%s' "$selected" | cut -f2)"

if command -v gum >/dev/null 2>&1; then
  gum confirm "Run: $cmd?" && eval "$cmd"
else
  printf 'Run: %s? [y/N] ' "$cmd"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]] && eval "$cmd"
fi
