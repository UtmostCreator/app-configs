#!/usr/bin/env bats
# T-0028: tmux targets in ops/projects scripts must be exact (`=name`), the
# master.sh attach must honour --detached inside $TMUX, and the tmux health
# check must fail on an unreadable config.
#
# tmux is a PATH stub that logs argv, or (isolated test) a wrapper that pins
# the real tmux to a private socket in a temp dir that is killed afterwards.
# Nothing here touches the user's real tmux server.
#
# Run:  bats tests/bash/projects-tmux-exact.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    P="$REPO_ROOT/ops/projects"
    command -v yq >/dev/null 2>&1 || skip "yq not installed"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    export PROJECTS_CONFIG="$BATS_TEST_TMPDIR/config.yaml"
    unset TMUX
    STUBS="$BATS_TEST_TMPDIR/bin"
    LOG="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$HOME" "$STUBS"
    : >"$LOG"
}

teardown() {
    # Only ever the private socket created by an isolated test.
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

# Logging tmux stub; has-session succeeds only when $HAS=1.
stub_tmux() {
    stub tmux 'printf "%s\n" "$*" >>"'"$LOG"'"
case "$1" in
  has-session) [ "${HAS:-0}" = 1 ] ;;
  display-message|split-window) echo "%1" ;;
esac'
}

# Wrapper pinning the real tmux to a private socket; starts session dev-other.
isolated_tmux() {
    command -v tmux >/dev/null 2>&1 || skip "tmux not installed"
    # Short temp path: unix socket paths cap near 108 bytes.
    SOCKDIR="$(mktemp -d /tmp/tx.XXXXXX)"
    SOCK="$SOCKDIR/s"
    REAL_TMUX="$(command -v tmux)"
    stub tmux 'exec "'"$REAL_TMUX"'" -S "'"$SOCK"'" "$@"'
    # Hermetic: panes started by the private server must never reach the real
    # ssh, so ssh is a stub on the PATH the server starts with.
    stub ssh 'exit 0'
    PATH="$STUBS:$PATH" "$REAL_TMUX" -S "$SOCK" -f /dev/null new-session -d -s dev-other
}

@test "ssh.sh --force: kill-session target is exact" {
    stub_tmux
    printf 'ssh_workspace:\n  hosts: [h1]\n  session: dev\n' >"$PROJECTS_CONFIG"
    run env PATH="$STUBS:$PATH" bash "$P/tmux/ssh.sh" --detached --force
    [ "$status" -eq 0 ]
    grep -Fxq 'kill-session -t =dev' "$LOG"
}

@test "ssh.sh --force: killing absent 'dev' leaves prefix-sharing 'dev-other' alive" {
    isolated_tmux
    printf 'ssh_workspace:\n  hosts: [h1]\n  session: dev\n' >"$PROJECTS_CONFIG"
    "$REAL_TMUX" -S "$SOCK" has-session -t '=dev-other'
    run env PATH="$STUBS:$PATH" bash "$P/tmux/ssh.sh" --detached --force
    [ "$status" -eq 0 ]
    "$REAL_TMUX" -S "$SOCK" has-session -t '=dev-other'
}

@test "kill-logs.sh: kill-session target is exact" {
    stub tmux 'printf "%s\n" "$*" >>"'"$LOG"'"
[ "$1" = list-sessions ] && echo "log-workspace-ws"
exit 0'
    run env PATH="$STUBS:$PATH" bash "$P/logging/kill-logs.sh"
    [ "$status" -eq 0 ]
    grep -Fxq 'kill-session -t =log-workspace-ws' "$LOG"
}

@test "master.sh --force: kill-session target is exact" {
    stub_tmux
    run env PATH="$STUBS:$PATH" bash "$P/tmux/master.sh" --force --detached
    grep -Fxq 'kill-session -t =ws-dev' "$LOG"
}

@test "master.sh: running session + --detached inside \$TMUX does not switch-client" {
    stub_tmux
    run env PATH="$STUBS:$PATH" HAS=1 TMUX=/fake,1,0 bash "$P/tmux/master.sh" --detached
    [ "$status" -eq 0 ]
    run grep -c 'switch-client\|attach-session' "$LOG"
    [ "$output" = "0" ]
}

@test "master.sh: running session attaches with an exact target" {
    stub_tmux
    run env PATH="$STUBS:$PATH" HAS=1 bash "$P/tmux/master.sh"
    [ "$status" -eq 0 ]
    grep -Fxq 'has-session -t =ws-dev' "$LOG"
    grep -Fxq 'attach-session -t =ws-dev' "$LOG"
}

@test "master.sh: running session inside \$TMUX switches with an exact target" {
    stub_tmux
    run env PATH="$STUBS:$PATH" HAS=1 TMUX=/fake,1,0 bash "$P/tmux/master.sh"
    [ "$status" -eq 0 ]
    grep -Fxq 'switch-client -t =ws-dev' "$LOG"
}

@test "10-tmux check: unreadable config emits fail and never runs has-session" {
    stub_tmux
    printf 'tmux:\n  master_session: [unclosed\n' >"$PROJECTS_CONFIG"
    run env PATH="$STUBS:$PATH" bash "$P/health/checks.d/10-tmux.sh"
    [[ "$output" == *'"fail"'* ]]
    [[ "$output" == *"cannot read"* ]]
    run grep -c has-session "$LOG"
    [ "$output" = "0" ]
}

@test "10-tmux check: uses an exact target" {
    stub_tmux
    printf 'tmux:\n  master_session: dev\n' >"$PROJECTS_CONFIG"
    run env PATH="$STUBS:$PATH" HAS=1 bash "$P/health/checks.d/10-tmux.sh"
    [[ "$output" == *"running"* ]]
    grep -Fxq 'has-session -t =dev' "$LOG"
}
