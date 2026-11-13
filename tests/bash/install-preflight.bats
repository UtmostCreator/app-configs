#!/usr/bin/env bats
# ops/install.sh preflight: stop early when the login user does not match the
# Nix username, instead of failing deep inside home-manager switch.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
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
    [[ "$output" != *"WSL1"* ]]
}
