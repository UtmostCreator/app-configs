#!/usr/bin/env bash
# Presentation layer for ops/update-all.sh.
#
# The contract: the terminal shows one line per step — a severity, a label and
# a short human summary — while the raw output of every command goes to a run
# log. Raw output only reaches the terminal when a step fails or --verbose is
# on, so the few things worth acting on are never buried.
#
#   ✓ ok       done, nothing to do
#   ! warn     it worked, but something wants a look
#   ✗ error    it failed
#   → info     worth knowing, no action needed
#   · skip     deliberately not run here

UI_LOG=""            # run log, appended to by every step
UI_LAST_LOG=""       # output of the most recent ui_run
UI_VERBOSE=0
UI_DRY_RUN=0
UI_COUNT_OK=0
UI_COUNT_WARN=0
UI_COUNT_ERR=0
UI_COUNT_SKIP=0
UI_COUNT_INFO=0
UI_NOTES=()
UI_LABEL_WIDTH=20

# ui_init <logfile> [verbose]
ui_init() {
  UI_LOG="${1:-}"
  UI_VERBOSE="${2:-0}"
  UI_COUNT_OK=0; UI_COUNT_WARN=0; UI_COUNT_ERR=0; UI_COUNT_SKIP=0; UI_COUNT_INFO=0
  UI_NOTES=()
  if [[ -n "$UI_LOG" ]]; then
    mkdir -p "$(dirname "$UI_LOG")" 2>/dev/null || true
    : > "$UI_LOG" 2>/dev/null || UI_LOG=""
  fi
  UI_LAST_LOG="${UI_LAST_LOG:-}"
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    UI_C_OK=$'\033[32m'; UI_C_WARN=$'\033[33m'; UI_C_ERR=$'\033[31m'
    UI_C_DIM=$'\033[2m'; UI_C_BOLD=$'\033[1m'; UI_C_OFF=$'\033[0m'
  else
    UI_C_OK=""; UI_C_WARN=""; UI_C_ERR=""; UI_C_DIM=""; UI_C_BOLD=""; UI_C_OFF=""
  fi
}

ui_log_only() { [[ -n "$UI_LOG" ]] && printf '%s\n' "$*" >> "$UI_LOG"; return 0; }

_ui_line() { # _ui_line <color> <glyph> <label> <note...>
  local color="$1" glyph="$2" label="$3"; shift 3
  printf '  %s%s%s %-*s %s\n' "$color" "$glyph" "$UI_C_OFF" "$UI_LABEL_WIDTH" "$label" "$*"
  ui_log_only "[$glyph] $label: $*"
}

ui_ok()   { UI_COUNT_OK=$((UI_COUNT_OK+1));     _ui_line "$UI_C_OK"   "✓" "$@"; }
ui_warn() { UI_COUNT_WARN=$((UI_COUNT_WARN+1)); _ui_line "$UI_C_WARN" "!" "$@"; }
ui_info() { UI_COUNT_INFO=$((UI_COUNT_INFO+1)); _ui_line "$UI_C_DIM"  "→" "$@"; }
ui_skip() { UI_COUNT_SKIP=$((UI_COUNT_SKIP+1)); _ui_line "$UI_C_DIM"  "·" "$@"; }

# ui_err <label> <note> — also replays the tail of the failed command's output,
# because a failure is exactly when the raw text earns its screen space.
ui_err() {
  UI_COUNT_ERR=$((UI_COUNT_ERR+1))
  _ui_line "$UI_C_ERR" "✗" "$@"
  if [[ -n "$UI_LAST_LOG" && -s "$UI_LAST_LOG" ]]; then
    printf '%s' "$UI_C_DIM"
    tail -n "${UI_FAIL_TAIL:-20}" "$UI_LAST_LOG" | sed 's/^/      /'
    printf '%s' "$UI_C_OFF"
  fi
}

ui_section() { printf '\n%s%s%s\n' "$UI_C_BOLD" "$1" "$UI_C_OFF"; ui_log_only "== $1 =="; }

# ui_run <label> <command...>
#
# Runs the command with its output captured. Returns the command's own status
# so the caller decides whether that means ok, warn or error.
ui_run() {
  local label="$1"; shift
  if [[ "$UI_DRY_RUN" == 1 ]]; then
    _ui_line "$UI_C_DIM" "·" "$label" "would run: $*"
    return 0
  fi
  local tmp status=0
  tmp="$(mktemp "${TMPDIR:-/tmp}/sys-update-step.XXXXXX")"
  ui_log_only "" ; ui_log_only "\$ $*"
  if [[ "$UI_VERBOSE" == 1 ]]; then
    "$@" 2>&1 | tee "$tmp"
    status="${PIPESTATUS[0]}"
  else
    "$@" > "$tmp" 2>&1
    status=$?
  fi
  [[ -n "$UI_LOG" ]] && cat "$tmp" >> "$UI_LOG"
  UI_LAST_LOG="$tmp"
  return "$status"
}

# ui_note <severity> <source> <message> — queued for the end-of-run block.
ui_note() {
  local sev="$1" src="$2"; shift 2
  local entry="$sev	$src	$*"
  local existing
  for existing in "${UI_NOTES[@]}"; do
    [[ "$existing" == "$entry" ]] && return 0   # never repeat the same note
  done
  UI_NOTES+=("$entry")
}

# ui_scan_warnings — classify the last step's output into notes.
ui_scan_warnings() {
  local file="${1:-$UI_LAST_LOG}" line classified
  [[ -n "$file" && -s "$file" ]] || return 0
  declare -F classify_warning >/dev/null || return 0
  while IFS= read -r line; do
    if classified="$(classify_warning "$line")"; then
      IFS=$'\t' read -r sev src msg <<< "$classified"
      ui_note "$sev" "$src" "$msg"
    fi
  done < <(grep -iE 'warning|warn |error|ERESOLVE|news items' "$file" 2>/dev/null | head -100)
}

ui_notes_report() {
  [[ "${#UI_NOTES[@]}" -gt 0 ]] || return 0
  ui_section "Warnings"
  local entry sev src msg
  for entry in "${UI_NOTES[@]}"; do
    IFS=$'\t' read -r sev src msg <<< "$entry"
    case "$sev" in
      warn) _ui_line "$UI_C_WARN" "!" "$src" "$msg" ;;
      *)    _ui_line "$UI_C_DIM"  "→" "$src" "$msg" ;;
    esac
  done
}

# ui_counts_line — one-line tally for the final verdict.
ui_counts_line() {
  printf '%d ok · %d warning(s) · %d error(s) · %d skipped' \
    "$UI_COUNT_OK" "$UI_COUNT_WARN" "$UI_COUNT_ERR" "$UI_COUNT_SKIP"
  [[ "${#UI_NOTES[@]}" -gt 0 ]] && printf ' · %d note(s)' "${#UI_NOTES[@]}"
  return 0
}
