#!/usr/bin/env bash
# PreToolUse hook. Claude Code pipes a JSON object on stdin (session_id,
# transcript_path, cwd, hook_event_name, tool_name, tool_input, ...) and
# ALSO includes the same context_window block the statusline gets.
#
# Exit code contract (PreToolUse):
#   exit 0, no output      -> tool proceeds silently
#   exit 1 + stderr         -> tool proceeds, stderr shown to user as a notice
#   exit 2 + stderr         -> tool call is BLOCKED, stderr shown as an error
# This hook only ever advises (exit 1) or stays silent (exit 0) — it never
# blocks a tool call, since blocking every tool once context climbs would
# make the session unusable rather than just warn you.
set -euo pipefail

INFO_AT=140000
WARN_AT=160000
CRIT_AT=200000

input="$(cat)"
session_id=$(jq -r '.session_id // "unknown"' <<<"$input")
used=$(jq -r '.context_window.total_input_tokens // 0' <<<"$input")

state_dir="$HOME/.claude/hooks/.state"
mkdir -p "$state_dir"
state_file="$state_dir/${session_id}.tier"
last_tier=0
[[ -f "$state_file" ]] && last_tier=$(cat "$state_file")

tier=0
if   (( used >= CRIT_AT )); then tier=3
elif (( used >= WARN_AT )); then tier=2
elif (( used >= INFO_AT )); then tier=1
fi

echo "$tier" > "$state_file"

# Only notify on entering a new (higher) tier, not on every tool call.
if (( tier > last_tier )); then
    case "$tier" in
        1) echo "[CONTEXT] ${used} tokens used (>=140k). Getting long — keep an eye on it." >&2 ;;
        2) echo "[CONTEXT WARNING] ${used} tokens used (>=160k). Consider wrapping up soon." >&2 ;;
        3) echo "[CONTEXT CRITICAL] ${used} tokens used (>=200k, approaching the window limit). Run /compact or /clear before continuing." >&2 ;;
    esac
    exit 1
fi

exit 0
