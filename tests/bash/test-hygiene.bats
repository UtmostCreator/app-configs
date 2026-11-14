#!/usr/bin/env bats
# Guards on the test suite itself.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCAN="$REPO_ROOT/tests/lib/find-dead-bang-asserts.py"
}

@test "no bats test has a '! cmd' assertion that can never fail" {
    run python3 -I "$SCAN" "$REPO_ROOT"/tests/bash/*.bats "$REPO_ROOT"/ops/projects/logging/test/*.bats
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "the scanner catches a mid-test bang and accepts a final one" {
    f="$BATS_TEST_TMPDIR/x.bats"
    printf '@test "a" {\n    ! false\n    true\n}\n@test "b" {\n    true\n    ! false\n}\n' >"$f"
    run python3 -I "$SCAN" "$f"
    [ "$status" -eq 1 ]
    [[ "$output" == *"x.bats:2: ! false"* ]]
    [[ "$output" != *"x.bats:7"* ]]
}

@test "logging tests never touch the tmux server you run them from" {
    command -v tmux >/dev/null || { echo "tmux missing"; return 1; }
    sock="$BATS_TEST_TMPDIR/real-tmux.sock"
    tmux -S "$sock" new-session -d -s mine 'sleep 600'
    # Inside tmux, TMUX names the client's server socket.
    run env TMUX="$sock,99999,0" TMUX_PANE=%0 bats -f 'invalid arguments' \
        "$REPO_ROOT/ops/projects/logging/test/log-workspace.bats"
    alive=0; tmux -S "$sock" has-session -t mine 2>/dev/null && alive=1
    tmux -S "$sock" kill-server 2>/dev/null || true
    [ "$alive" -eq 1 ] || { echo "the test run killed the caller's tmux server"; return 1; }
}
