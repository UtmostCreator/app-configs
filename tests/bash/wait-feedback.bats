#!/usr/bin/env bats
# ops/lib/wait-feedback.sh (T-0050): a long wait says what it is, how long it
# can take, keeps a heartbeat going on stderr, and ends with a result line. The
# ticker is tracked by PID and must be gone on every exit path.

bats_require_minimum_version 1.5.0

# A regression that hangs must fail, not stall the suite.
export BATS_TEST_TIMEOUT=30

# `! cmd` mid-test cannot fail a test (set -e ignores it): assert absence explicitly.
no() { if "$@"; then echo "unexpected success: $*" >&2; return 1; fi; }

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export WAIT_HEARTBEAT_SECS=1
    export WAIT_TICKER_PIDFILE="$BATS_TEST_TMPDIR/ticker.pid"
    # shellcheck source=/dev/null
    source "$REPO_ROOT/ops/lib/wait-feedback.sh"
}

slow() { sleep 3; echo "payload"; return "${1:-0}"; }

@test "says what and how long first, heartbeats on stderr, then a result line" {
    run --separate-stderr wait_run "checking things" "a few seconds" slow
    [ "$status" -eq 0 ]
    [ "$output" = payload ]
    [[ "${stderr_lines[0]}" == *"checking things"*"a few seconds"* ]]
    local hb
    hb="$(printf '%s\n' "$stderr" | grep -c 'still running')"
    [ "$hb" -ge 2 ]
    [[ "${stderr_lines[-1]}" == *"done"*"exit 0"* ]]
}

@test "stdout carries only the command's own output" {
    run --separate-stderr wait_run "x" "y" slow
    [ "$output" = payload ]
}

@test "the ticker is gone afterwards on success" {
    wait_run "x" "y" slow >/dev/null 2>&1
    local pid; pid="$(cat "$WAIT_TICKER_PIDFILE")"
    [ -n "$pid" ]
    no kill -0 "$pid" 2>/dev/null
}

@test "the ticker is gone afterwards on failure, and the exit code is kept" {
    local rc=0
    wait_run "x" "y" slow 7 >/dev/null 2>&1 || rc=$?
    [ "$rc" -eq 7 ]
    local pid; pid="$(cat "$WAIT_TICKER_PIDFILE")"
    no kill -0 "$pid" 2>/dev/null
}

@test "a failure ends with a result line carrying the exit code" {
    run --separate-stderr wait_run "x" "y" slow 7
    [ "$status" -eq 7 ]
    [[ "${stderr_lines[-1]}" == *"exit 7"* ]]
}

@test "no escape sequences or carriage returns (non-TTY and CI logs stay plain)" {
    run --separate-stderr wait_run "x" "y" slow
    [[ "$stderr" != *$'\r'* ]]
    [[ "$stderr" != *$'\033'* ]]
}

@test "inside command substitution it does not hang on the ticker's stdout" {
    local out
    out="$(wait_run "x" "y" slow 2>/dev/null)"
    [ "$out" = payload ]
}

@test "a bad interval falls back to 30 seconds (no heartbeat within a 3 second wait)" {
    WAIT_HEARTBEAT_SECS=abc run --separate-stderr wait_run "x" "y" slow
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"every 30s"* ]]
    [[ "$stderr" != *"still running"* ]]
}

@test "the ticker stops by itself when its parent is killed" {
    local pidfile="$BATS_TEST_TMPDIR/p2"
    bash -c "source '$REPO_ROOT/ops/lib/wait-feedback.sh'; WAIT_TICKER_PIDFILE='$pidfile' wait_run x y sleep 30" >/dev/null 2>&1 &
    local parent=$!
    local i
    for i in $(seq 1 50); do [ -s "$pidfile" ] && break; sleep 0.1; done
    local tick; tick="$(cat "$pidfile")"
    kill -9 "$parent"
    for i in $(seq 1 50); do kill -0 "$tick" 2>/dev/null || break; sleep 0.2; done
    no kill -0 "$tick" 2>/dev/null
}

@test "the ticker stops when a SUBSHELL caller is killed (the owner is the caller, not the top-level script)" {
    local pidfile="$BATS_TEST_TMPDIR/p3"
    ( WAIT_TICKER_PIDFILE="$pidfile" wait_run x y sleep 4 >/dev/null 2>&1 ) &
    local sub=$!
    local i
    for i in $(seq 1 50); do [ -s "$pidfile" ] && break; sleep 0.1; done
    local tick; tick="$(cat "$pidfile")"
    kill -9 "$sub"
    for i in $(seq 1 40); do kill -0 "$tick" 2>/dev/null || break; sleep 0.2; done
    no kill -0 "$tick" 2>/dev/null
}
