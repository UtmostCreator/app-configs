#!/usr/bin/env bash
# Claude Code statusLine command. Claude Code pipes a JSON object on stdin
# (see `statusLine` in settings.json). Docs: statusline.md, fields include
# model.{id,display_name} and context_window.{total_input_tokens,context_window_size,...}.
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

input="$(cat)"

model_id=$(jq -r '.model.id // ""' <<<"$input")
model_name=$(jq -r '.model.display_name // "unknown"' <<<"$input")
used=$(jq -r '.context_window.total_input_tokens // 0' <<<"$input")
window_size=$(jq -r '.context_window.context_window_size // 200000' <<<"$input")

# Per-model soft budgets (independent of the model's actual context window size).
target=200000
case "${model_id}${model_name}" in
    *[Oo]pus*|*[Ff]able*) target=200000 ;;
    *[Ss]onnet*)          target=160000 ;;
    *[Hh]aiku*)           target=70000  ;;
esac

pct=$(( window_size > 0 ? used * 100 / target : 0 ))

if   (( pct < 70 )); then color=$GREEN
elif (( pct < 90 )); then color=$YELLOW
else                      color=$RED
fi

printf "${BLUE}%s${NC} | ${color}%d%%${NC} | %s/%sk (window %sk)\n" \
    "$model_name" "$pct" "$(( used / 1000 ))" "$(( target / 1000 ))" "$(( window_size / 1000 ))"
