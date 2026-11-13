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
