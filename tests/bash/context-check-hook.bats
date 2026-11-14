#!/usr/bin/env bats
# home/dot_claude/hooks/executable_context-check.sh (PreToolUse). The hook
# input has transcript_path but no context_window, so usage must come from
# the transcript's last assistant message.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$REPO_ROOT/home/dot_claude/hooks/executable_context-check.sh"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    T="$BATS_TEST_TMPDIR/transcript.jsonl"
}

usage_line() { # usage_line <input> <cache_read> <cache_creation>
    printf '{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":%s,"cache_read_input_tokens":%s,"cache_creation_input_tokens":%s,"output_tokens":50}}}\n' "$1" "$2" "$3"
}
hook() { # hook <session>
    printf '{"session_id":"%s","transcript_path":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{}}' "$1" "$T" |
        bash "$HOOK"
}

@test "below 140k: silent, exit 0" {
    { echo '{"type":"user"}'; usage_line 1000 50000 2000; } >"$T"
    run hook s1
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "uses the LAST assistant usage, summing input and both cache counts" {
    { usage_line 10 10 10; echo '{"type":"user"}'; usage_line 5000 150000 1000; } >"$T"
    run hook s2
    [ "$status" -eq 1 ]
    [[ "$output" == *"156000 tokens"* ]]
    [[ "$output" == *">=140k"* ]]
}

@test "warns once per tier, then again when the next tier is reached" {
    usage_line 0 150000 0 >"$T"
    run hook s3; [ "$status" -eq 1 ]
    run hook s3; [ "$status" -eq 0 ] && [ -z "$output" ]
    usage_line 0 205000 0 >>"$T"
    run hook s3; [ "$status" -eq 1 ]
    [[ "$output" == *"CRITICAL"* ]]
}

@test "missing or unreadable transcript stays silent" {
    T="$BATS_TEST_TMPDIR/nope.jsonl"
    run hook s4
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "a context_window block, if Claude Code ever sends one, wins" {
    usage_line 0 1000 0 >"$T"
    run bash -c "printf '{\"session_id\":\"s5\",\"transcript_path\":\"$T\",\"context_window\":{\"total_input_tokens\":170000}}' | bash '$HOOK'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"170000 tokens"* ]]
}
