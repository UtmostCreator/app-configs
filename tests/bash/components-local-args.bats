#!/usr/bin/env bats
# components-local.sh re-execs through `mise exec node@22` for real work. That
# re-exec used to run before argument parsing, so `--help` or a typo went
# through mise (and exited 1 when mise refused an untrusted checkout).
#
# Hermetic: `node` is a stub reporting Node 24 (so the re-exec condition holds
# on any host) and `mise` is a stub that records its argv. The script runs with
# a scratch HOME; nothing here reaches the real mise, npm or workspace.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/projects/workspace/components-local.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    unset WS_HERD_ROOT_DIR
    STUBS="$BATS_TEST_TMPDIR/bin"; CALLS="$BATS_TEST_TMPDIR/calls"
    mkdir -p "$HOME" "$STUBS"; : >"$CALLS"
    printf '#!/bin/sh\necho 24\n' >"$STUBS/node"
    printf '#!/bin/sh\necho "mise $*" >>"%s"\nexit 0\n' "$CALLS" >"$STUBS/mise"
    chmod +x "$STUBS/node" "$STUBS/mise"
}

run_script() { run env PATH="$STUBS:$PATH" bash "$SCRIPT" "$@"; }

@test "--help, -h and help print usage, exit 0 and never call mise" {
    local a
    for a in --help -h help; do
        run_script "$a"
        [ "$status" -eq 0 ] || { echo "$a: status $status"; return 1; }
        [[ "$output" == *"Usage:"* ]] || { echo "$a: no usage"; return 1; }
        [ ! -s "$CALLS" ] || { echo "$a called: $(cat "$CALLS")"; return 1; }
    done
}

@test "apply --help prints usage, exits 0 and never calls mise" {
    run_script apply --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [ ! -s "$CALLS" ]
}

@test "unknown command or option exits non-zero with usage and never calls mise" {
    local args
    for args in "--definitely-not-a-flag" "bogus" "apply --definitely-not-a-flag" \
        "refresh --bogus" "apply --component-test" "watch extra" \
        "rollback extra" "status extra" "rollback --bogus"; do
        run_script $args
        [ "$status" -ne 0 ] || { echo "$args: exited 0"; return 1; }
        [[ "$output" == *"sage"* || "$output" == *"Unknown"* || "$output" == *"Missing"* || "$output" == *"does not accept"* ]] \
            || { echo "$args: no message: $output"; return 1; }
        [ ! -s "$CALLS" ] || { echo "$args called: $(cat "$CALLS")"; return 1; }
    done
}

@test "a real operation on a non-22 Node still re-execs through mise exec node@22" {
    run_script status
    [ "$status" -eq 0 ]
    [[ "$(cat "$CALLS")" == "mise exec node@22 -- bash $SCRIPT status" ]] \
        || { echo "calls: $(cat "$CALLS")"; return 1; }
}

@test "apply with valid options still re-execs through mise exec node@22" {
    run_script apply --skip-test --keep-tarball
    [ "$status" -eq 0 ]
    [[ "$(cat "$CALLS")" == "mise exec node@22 -- bash $SCRIPT apply --skip-test --keep-tarball" ]] \
        || { echo "calls: $(cat "$CALLS")"; return 1; }
}

@test "every apply/refresh option still reaches the re-exec (guards the precheck option list)" {
    local args want
    for args in "apply --component-test x --skip-test --start-dev --keep-tarball" \
        "refresh --skip-test --start-dev" "refresh --component-test x" "rollback" "watch"; do
        : >"$CALLS"
        run_script $args
        [ "$status" -eq 0 ] || { echo "$args: status $status: $output"; return 1; }
        want="mise exec node@22 -- bash $SCRIPT $args"
        [[ "$(cat "$CALLS")" == "$want" ]] || { echo "$args: calls: $(cat "$CALLS")"; return 1; }
    done
}

@test "rollback --help and status --help print usage and reach neither mise nor the workflow" {
    # A sentinel npm stub: rollback_workflow calls require_command npm and then
    # stop_frontend_debug / npm ci. None of that may run for --help.
    printf '#!/bin/sh\necho "npm $*" >>"%s"\nexit 1\n' "$CALLS" >"$STUBS/npm"
    chmod +x "$STUBS/npm"
    local c a major
    # Node 24 would re-exec through mise; Node 22 goes straight to the workflow.
    for major in 24 22; do
      printf '#!/bin/sh\necho %s\n' "$major" >"$STUBS/node"
      for c in rollback status; do
        for a in --help -h help; do
            : >"$CALLS"
            run_script "$c" "$a"
            [ "$status" -eq 0 ] || { echo "$c $a: status $status"; return 1; }
            [[ "$output" == *"Usage:"* ]] || { echo "$c $a: no usage"; return 1; }
            [[ "$output" != *"Removing local package"* && "$output" != *"Active workflow"* \
                && "$output" != *"No active local"* && "$output" != *"No saved state"* ]] \
                || { echo "$c $a reached the workflow: $output"; return 1; }
            [ ! -s "$CALLS" ] || { echo "$c $a called: $(cat "$CALLS")"; return 1; }
        done
      done
    done
}

@test "plain rollback and status still re-exec" {
    local c
    for c in status rollback; do
        : >"$CALLS"
        run_script "$c"
        [ "$status" -eq 0 ] || { echo "$c: status $status"; return 1; }
        [[ "$(cat "$CALLS")" == "mise exec node@22 -- bash $SCRIPT $c" ]] \
            || { echo "$c: calls: $(cat "$CALLS")"; return 1; }
    done
}

@test "watch --help, -h and help print usage and reach neither mise nor the workflow" {
    printf '#!/bin/sh\necho "npm $*" >>"%s"\nexit 1\n' "$CALLS" >"$STUBS/npm"
    chmod +x "$STUBS/npm"
    local a major
    for major in 24 22; do
      printf '#!/bin/sh\necho %s\n' "$major" >"$STUBS/node"
      for a in --help -h help; do
          : >"$CALLS"
          run_script watch "$a"
          [ "$status" -eq 0 ] || { echo "watch $a: status $status: $output"; return 1; }
          [[ "$output" == *"Usage:"* ]] || { echo "watch $a: no usage"; return 1; }
          [ ! -s "$CALLS" ] || { echo "watch $a called: $(cat "$CALLS")"; return 1; }
      done
    done
}

@test "watch with any other option is still rejected without calling mise" {
    local args
    for args in "watch --foo" "watch -x" "watch --help extra" "watch extra"; do
        : >"$CALLS"
        run_script $args
        [ "$status" -ne 0 ] || { echo "$args: exited 0"; return 1; }
        [[ "$output" == *"watch does not accept options"* ]] || { echo "$args: $output"; return 1; }
        [ ! -s "$CALLS" ] || { echo "$args called: $(cat "$CALLS")"; return 1; }
    done
}
