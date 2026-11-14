#!/usr/bin/env bats
# ops/install.sh preflight: stop early when the login user does not match the
# Nix username, instead of failing deep inside home-manager switch.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # Never let install.sh see the real HOME, even if DRY_RUN were lost.
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
}

@test "mismatched user fails before anything is installed" {
    run env USER=someone-else DRY_RUN=1 HOST_PROFILE=wsl bash "$REPO_ROOT/ops/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"someone-else"* ]]
    [[ "$output" == *"nix/vars/default.nix"* ]]
    [[ "$output" != *"── Nix ──"* ]]
}

@test "matching user passes the username check" {
    expected="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    run env USER="$expected" DRY_RUN=1 HOST_PROFILE=wsl bash "$REPO_ROOT/ops/install.sh"
    # A crash would also print no "does not match": require a real dry run.
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:  dry-run"* ]]
    [[ "$output" != *"does not match"* ]]
}

@test "WSL1 kernel is refused with the conversion command" {
    printf 'Linux version 4.4.0-19041-Microsoft (Microsoft@Microsoft.com) (gcc version 5.4.0) #1237-Microsoft\n' \
        >"$BATS_TEST_TMPDIR/version"
    expected="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    run env USER="$expected" DRY_RUN=1 HOST_PROFILE=wsl \
        DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/version" bash "$REPO_ROOT/ops/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"WSL1"* ]]
    [[ "$output" == *"wsl --set-version"* ]]
    [[ "$output" != *"── Nix ──"* ]]
}

@test "WSL2 kernel passes the WSL version check" {
    printf 'Linux version 6.6.87.2-microsoft-standard-WSL2 (root@host) #1 SMP\n' >"$BATS_TEST_TMPDIR/version"
    expected="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    run env USER="$expected" DRY_RUN=1 HOST_PROFILE=wsl \
        DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/version" bash "$REPO_ROOT/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:  dry-run"* ]]
    [[ "$output" != *"WSL1"* ]]
}

@test "--dry-run is honoured (sys-install passes its args through)" {
    expected="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    run env -u DRY_RUN USER="$expected" HOST_PROFILE=wsl bash "$REPO_ROOT/ops/install.sh" --dry-run
    [[ "$output" == *"Mode:  dry-run"* ]]
    [[ "$output" == *"[install:dry-run] would run"* ]]
}

@test "--help prints usage and changes nothing" {
    run bash "$REPO_ROOT/ops/install.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" != *"Preflight"* ]]
}

@test "unknown arguments stop before anything runs" {
    run bash "$REPO_ROOT/ops/install.sh" --apply
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown argument: --apply"* ]]
    [[ "$output" != *"Preflight"* ]]
}

@test "under bats a real install against the real HOME is refused" {
    # A HOME outside this test's scratch dir stands in for the real one
    # (run-bats.sh gives the whole suite a scratch HOME).
    outside="${BATS_RUN_TMPDIR:-/tmp}/outside-home-$$"
    run env -u DRY_RUN HOME="$outside" bash "$REPO_ROOT/ops/install.sh"
    [ "$status" -eq 3 ]
    [ ! -e "$outside" ]   # nothing was created there
    [[ "$output" == *"refusing a real install from a bats test"* ]]
    [[ "$output" != *"Preflight"* ]]
}
