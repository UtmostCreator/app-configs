#!/usr/bin/env bash
# PreToolUse hook. Claude Code pipes a JSON object on stdin (session_id,
# transcript_path, cwd, hook_event_name, tool_name, tool_input, ...). Unlike
# the statusline input it has NO context_window block, so the hook used to
# read 0 forever and never warned. Usage now comes from the transcript: the
# last assistant message's input + cache-read + cache-creation tokens, which
# is what the next request will carry. A context_window block still wins if
# Claude Code ever starts sending one.
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
if [[ "$used" == 0 ]]; then
    transcript=$(jq -r '.transcript_path // empty' <<<"$input")
    if [[ -n "$transcript" && -r "$transcript" ]]; then
        # Only the tail: transcripts grow to many MB. Lines that are not JSON
        # (or not usage records) are skipped.
        used=$(tail -n 400 "$transcript" | jq -R -s -r '
            [split("\n")[] | fromjson? | select(.message.usage? != null) | .message.usage]
            | last // {}
            | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' 2>/dev/null || echo 0)
    fi
fi
[[ "$used" =~ ^[0-9]+$ ]] || used=0

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
