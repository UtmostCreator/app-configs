#!/usr/bin/env bats
# ops/doctor.sh: --preflight checks only what must exist before installation;
# the default mode is the repo/developer health check. Errors go to stderr.

bats_require_minimum_version 1.5.0

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    DOCTOR="$REPO_ROOT/ops/doctor.sh"
    # PATH with only the bare prerequisites: no rg, jq, yq, just, scanners.
    BARE="$BATS_TEST_TMPDIR/bare"
    mkdir -p "$BARE"
    for t in bash git curl dirname; do ln -s "$(command -v "$t")" "$BARE/$t"; done
}

@test "preflight passes without rg, jq, yq or a scanner" {
    PATH="$BARE" run bash "$DOCTOR" --preflight
    [ "$status" -eq 0 ]
    [[ "$output" != *"'rg'"* ]]
    [[ "$output" != *"Optional binaries"* ]]
    [[ "$output" != *"Secret scanner"* ]]
}

@test "preflight fails and counts errors on stderr when curl is missing" {
    rm "$BARE/curl"
    PATH="$BARE" run --separate-stderr bash "$DOCTOR" --preflight
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"[ERROR] binary 'curl' missing"* ]]
    [[ "$stderr" == *"1 error(s)"* ]]
    [[ "$output" != *"[ERROR]"* ]]
}

@test "preflight fails when a core repo file is missing" {
    fake="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$fake/ops"; cp "$DOCTOR" "$fake/ops/doctor.sh"
    PATH="$BARE" run --separate-stderr bash "$fake/ops/doctor.sh" --preflight
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"file 'README.md' missing"* ]]
}

@test "default mode does not require rg" {
    PATH="$BARE" run --separate-stderr bash "$DOCTOR"
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"'rg'"* ]]
}

@test "default mode no longer mentions justfile" {
    run bash "$DOCTOR"
    [[ "$output" != *[Jj]ustfile* ]]
    [[ "$output" != *"'just'"* ]]
}

@test "default mode does not warn about jq/yq (readiness owns them)" {
    PATH="$BARE" run bash "$DOCTOR"
    [[ "$output" != *"'jq'"* ]]
    [[ "$output" != *"'yq'"* ]]
}

@test "unknown argument is rejected on stderr with exit 2" {
    run --separate-stderr bash "$DOCTOR" --bogus
    [ "$status" -eq 64 ]
    [[ "$stderr" == *"unknown argument"* ]]
    [ -z "$output" ]
}
