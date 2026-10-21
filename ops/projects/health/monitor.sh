#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../workspace/config.sh"

VERIFY_SCRIPT="${VERIFY_SCRIPT:-$WS_SCRIPT_VERIFY_WORKSPACE}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-8}"
SOUND_DEBOUNCE_SECONDS="${SOUND_DEBOUNCE_SECONDS:-5}"
SHOW_RAW_CHECKS="${SHOW_RAW_CHECKS:-1}"
USE_ALT_SCREEN="${USE_ALT_SCREEN:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

LAST_OVERALL_STATE="unknown"
LAST_SECTION_SIG=""
LAST_SOUND_TS=0
BLINK_TOGGLE=0
ALT_SCREEN_ACTIVE=0

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 127
  }
}

require_cmd jq

have_gum() {
  command -v gum >/dev/null 2>&1
}

# Presentation/IO concerns live in focused libs (sourced; functions only).
# shellcheck source=lib/sound.sh
source "$SCRIPT_DIR/lib/sound.sh"
# shellcheck source=lib/notify.sh
source "$SCRIPT_DIR/lib/notify.sh"
# shellcheck source=lib/render.sh
source "$SCRIPT_DIR/lib/render.sh"

run_fix_picker() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is required for --fix" >&2
    exit 127
  fi

  local data selected cmd verify_rc
  if data="$(WS_VERIFY_FAST=1 "$VERIFY_SCRIPT" --json 2>/dev/null)"; then
    verify_rc=0
  else
    verify_rc=$?
  fi
  if [[ -z "$data" && "$verify_rc" -ne 0 ]]; then
    echo "ws-verify did not return JSON output" >&2
    exit "$verify_rc"
  fi
  selected="$({
      jq -r '.checks[] | select((.fix // "") != "") | [.name, .fix] | @tsv' <<<"$data" | awk -F'\t' '!seen[$2]++'
    } | fzf --height 40% --border --prompt 'Run fix > ' --delimiter=$'\t' --with-nth 1,2)"
  [[ -z "$selected" ]] && exit 0
  cmd="$(printf '%s' "$selected" | cut -f2)"

  if have_gum; then
    gum confirm "Run: $cmd?" && eval "$cmd"
  else
    printf 'Run: %s? [y/N] ' "$cmd"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] && eval "$cmd"
  fi
}

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "verify script not executable: $VERIFY_SCRIPT" >&2
  exit 1
fi

trap cleanup_screen EXIT INT TERM

case "${1:-}" in
  --json)
    WS_VERIFY_FAST=1 "$VERIFY_SCRIPT" --json
    exit $?
    ;;
  --fix)
    run_fix_picker
    exit 0
    ;;
esac

while true; do
  if data="$(WS_VERIFY_FAST=1 "$VERIFY_SCRIPT" --json 2>/dev/null)"; then
    :
  elif [[ -z "${data:-}" ]]; then
    echo "ws-verify did not return JSON output" >&2
    exit 1
  fi
  if (( BLINK_TOGGLE == 0 )); then
    filled=1
    BLINK_TOGGLE=1
  else
    filled=0
    BLINK_TOGGLE=0
  fi
  render_dashboard "$data" "$filled"
  sleep "$INTERVAL_SECONDS"
done
