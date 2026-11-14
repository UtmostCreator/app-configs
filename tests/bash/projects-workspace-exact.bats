#!/usr/bin/env bats
# T-0028 follow-up: ws-* stop/restart/stop-watch/verify tmux targets are exact.
#
# stop.sh and restart.sh run real stop scripts, so the tmux functions are cut
# out of the scripts and run alone. tmux is a PATH stub that logs argv, or a
# wrapper pinned to a private socket (temp dir, killed in teardown). Nothing
# here touches the user's real tmux server.
#
# Run:  bats tests/bash/projects-workspace-exact.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    WS="$REPO_ROOT/ops/projects/workspace"
    export HOME="$BATS_TEST_TMPDIR/home"
    unset TMUX WS_HERD_ROOT_DIR WS_NETLIFY_ENV_KEYS
    STUBS="$BATS_TEST_TMPDIR/bin"
    LOG="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$HOME" "$STUBS"
    : >"$LOG"
}

teardown() {
    if [ -n "${SOCK:-}" ] && [ -S "$SOCK" ]; then
        "$REAL_TMUX" -S "$SOCK" kill-server 2>/dev/null || true
    fi
    if [ -n "${SOCKDIR:-}" ]; then
        rm -rf "$SOCKDIR"
    fi
}

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

stub_tmux() {
    stub tmux 'printf "%s\n" "$*" >>"'"$LOG"'"
[ "$1" = has-session ] && [ "${HAS:-0}" != 1 ] && exit 1
exit 0'
}

# Private server (short temp path: unix sockets cap near 108 bytes) holding
# only the session names given as arguments.
isolated_tmux() {
    command -v tmux >/dev/null 2>&1 || skip "tmux not installed"
    SOCKDIR="$(mktemp -d /tmp/tx.XXXXXX)"
    SOCK="$SOCKDIR/s"
    REAL_TMUX="$(command -v tmux)"
    stub tmux 'exec "'"$REAL_TMUX"'" -S "'"$SOCK"'" "$@"'
    local s
    for s in "$@"; do
        "$REAL_TMUX" -S "$SOCK" -f /dev/null new-session -d -s "$s" "sleep 300"
    done
}

# fn_of <script> <function>: print that function's definition.
fn_of() {
    sed -n "/^$2() {/,/^}/p" "$1"
}

@test "stop.sh: stop_tmux_session uses exact targets" {
    stub_tmux
    { echo 'log() { :; }'; echo 'SESSION=ws-dev'; fn_of "$WS/stop.sh" stop_tmux_session; echo 'stop_tmux_session'; } >"$BATS_TEST_TMPDIR/f.sh"
    run env PATH="$STUBS:$PATH" HAS=1 bash "$BATS_TEST_TMPDIR/f.sh"
    [ "$status" -eq 0 ]
    grep -Fxq 'has-session -t =ws-dev' "$LOG"
    grep -Fxq 'detach-client -s =ws-dev' "$LOG"
    grep -Fxq 'kill-session -t =ws-dev' "$LOG"
}

@test "stop.sh: with ws-dev absent, ws-dev-restart-helper-1 survives" {
    isolated_tmux ws-dev-restart-helper-1
    { echo 'log() { echo "$1"; }'; echo 'SESSION=ws-dev'; fn_of "$WS/stop.sh" stop_tmux_session; echo 'stop_tmux_session'; } >"$BATS_TEST_TMPDIR/f.sh"
    run env PATH="$STUBS:$PATH" bash "$BATS_TEST_TMPDIR/f.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not running"* ]]
    "$REAL_TMUX" -S "$SOCK" has-session -t '=ws-dev-restart-helper-1'
}

@test "restart.sh: wait_for_session_shutdown polls an exact target" {
    stub_tmux
    { echo 'SESSION=ws-dev SHUTDOWN_TIMEOUT_SECONDS=1'; fn_of "$WS/restart.sh" wait_for_session_shutdown; echo 'wait_for_session_shutdown'; } >"$BATS_TEST_TMPDIR/f.sh"
    run env PATH="$STUBS:$PATH" bash "$BATS_TEST_TMPDIR/f.sh"
    [ "$status" -eq 0 ]
    grep -Fxq 'has-session -t =ws-dev' "$LOG"
}

@test "restart.sh: helper session kill and switch use exact targets" {
    stub_tmux
    {
        echo 'log() { :; }'
        echo 'SESSION=ws-dev OPEN_WORKSPACE_SCRIPT=/dev/null'
        echo 'stop_workspace() { :; }'
        fn_of "$WS/restart.sh" restart_from_tmux
        echo 'restart_from_tmux'
    } >"$BATS_TEST_TMPDIR/f.sh"
    run env PATH="$STUBS:$PATH" bash "$BATS_TEST_TMPDIR/f.sh"
    [ "$status" -eq 0 ]
    grep -Eq '^kill-session -t =ws-dev-restart-helper-[0-9]+$' "$LOG"
    grep -Eq '^switch-client -t =ws-dev-restart-helper-[0-9]+$' "$LOG"
    run grep -Ec '^kill-session -t ws-dev' "$LOG"
    [ "$output" = "0" ]
}

@test "stop-watch.sh: session probe uses an exact target" {
    stub_tmux
    # pkill is a stub: the real one would signal the host's process table.
    stub pkill 'printf "pkill %s\n" "$*" >>"'"$LOG"'"'
    run env PATH="$STUBS:$PATH" HAS=1 bash "$REPO_ROOT/ops/projects/logging/watch/stop-watch.sh"
    grep -Fxq 'has-session -t =ws-dev' "$LOG"
    grep -Fq "pkill -f just --justfile $HOME/Herd/backend/justfile log-bat" "$LOG"
}

@test "frontend/stack scripts: session probes use exact targets" {
    run grep -E 'has-session -t "\$SESSION"' \
        "$WS/frontend/restart.sh" "$WS/frontend/stop.sh" "$WS/stack/stop.sh"
    [ "$status" -ne 0 ]
}

@test "verify-workspace.sh: session probe uses an exact target" {
    run grep -E 'has-session -t "\$SESSION"' "$REPO_ROOT/ops/projects/health/verify-workspace.sh"
    [ "$status" -ne 0 ]
    grep -Fq 'has-session -t "=$SESSION"' "$REPO_ROOT/ops/projects/health/verify-workspace.sh"
}
