#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$ROOT_DIR/.copilot-logs"
SNAP_DIR="$LOG_DIR/snapshots"
SESSION_DIR="$LOG_DIR/sessions"

label="${1:-checkpoint}"
session_id="session-checkpoint-$(date +%Y%m%d-%H%M%S)-$$"

mkdir -p "$SNAP_DIR" "$SESSION_DIR"

snap_file="$SNAP_DIR/${session_id}-${label}.patch"
git -C "$ROOT_DIR" diff --binary HEAD >"$snap_file"

if [[ ! -s "$snap_file" ]]; then
    git -C "$ROOT_DIR" rev-parse HEAD >"${snap_file%.patch}.ref"
    rm -f "$snap_file"
    snap_file="${snap_file%.patch}.ref"
fi

printf '{"ts":"%s","session":"%s","event":"snapshot.create","file":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$session_id" "$snap_file" >>"$LOG_DIR/tool-usage.jsonl"

printf 'checkpoint created: %s\n' "$snap_file"
