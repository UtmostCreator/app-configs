#!/usr/bin/env bats
# The ws-* stop/restart/fix/kill-logs scripts take no arguments. `--help` must
# print usage and any other argument must exit 2, in both cases without
# touching tmux, processes or the network. tmux/pkill/etc. are PATH stubs that
# log every call; the logs must stay empty.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset TMUX TMUX_TMPDIR
    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    CALLS="$BATS_TEST_TMPDIR/calls"; : >"$CALLS"
    for t in tmux pkill kill lsof nohup docker colima herd open fzf jq curl; do
        printf '#!/bin/sh\necho "%s $*" >>"%s"\nexit 1\n' "$t" "$CALLS" >"$STUBS/$t"
        chmod +x "$STUBS/$t"
    done
    P="$REPO_ROOT/ops/projects"
}

SCRIPTS=(
    workspace/stop.sh
    workspace/restart.sh
    workspace/frontend/stop.sh
    workspace/frontend/restart.sh
    workspace/stack/stop.sh
    workspace/fix.sh
    logging/kill-logs.sh
)

@test "--help prints usage, exits 0 and acts on nothing" {
    local s
    for s in "${SCRIPTS[@]}"; do
        run env PATH="$STUBS:$PATH" bash "$P/$s" --help
        [ "$status" -eq 0 ] || { echo "$s: status $status"; return 1; }
        [[ "$output" == *"Usage"* ]] || { echo "$s: no usage: $output"; return 1; }
        [ ! -s "$CALLS" ] || { echo "$s called: $(cat "$CALLS")"; return 1; }
    done
}

@test "any argument exits 2 and acts on nothing" {
    local s a
    for s in "${SCRIPTS[@]}"; do
        for a in --dry-run foo -x; do
            run env PATH="$STUBS:$PATH" bash "$P/$s" "$a"
            [ "$status" -eq 2 ] || { echo "$s $a: status $status"; return 1; }
            [ ! -s "$CALLS" ] || { echo "$s $a called: $(cat "$CALLS")"; return 1; }
        done
    done
}

@test "master.sh: --force with a later bad argument does not kill the session" {
    run env PATH="$STUBS:$PATH" bash "$P/tmux/master.sh" --force --bogus
    [ "$status" -ne 0 ]
    ! grep -q 'kill-session' "$CALLS"
}

@test "master.sh: --help prints usage and acts on nothing" {
    run env PATH="$STUBS:$PATH" bash "$P/tmux/master.sh" --force --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [ ! -s "$CALLS" ]
}
