#!/usr/bin/env bats
# ops/readiness.sh owns installed-state checks: nix, chezmoi, mise,
# home-manager, lefthook, jq, yq and a secret scanner (fail-closed, like the
# pre-commit hook).

bats_require_minimum_version 1.5.0

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/readiness.sh"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    S="$BATS_TEST_TMPDIR/bin"; mkdir -p "$S"
    for t in bash cat grep sed head cut wc dirname uname git tr; do
        ln -s "$(command -v "$t")" "$S/$t"
    done
    unset APP_CONFIGS_ALLOW_MISSING_SCANNER
    export HOST_PROFILE=linux-cli USER=tester
}

stub() { printf '#!/bin/sh\nexit 0\n' >"$S/$1"; chmod +x "$S/$1"; }

@test "missing jq and yq are required failures" {
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[MISS] jq missing"* ]]
    [[ "$output" == *"[MISS] yq missing"* ]]
}

@test "missing secret scanner is a failure matching the pre-commit policy" {
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[MISS] no secret scanner"* ]]
}

@test "scanner present passes; APP_CONFIGS_ALLOW_MISSING_SCANNER downgrades" {
    stub gitleaks
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[OK]   gitleaks"* ]]
    rm "$S/gitleaks"
    APP_CONFIGS_ALLOW_MISSING_SCANNER=1 PATH="$S" run bash "$SCRIPT"
    [[ "$output" != *"[MISS] no secret scanner"* ]]
    [[ "$output" == *"[TODO] no secret scanner"* ]]
}

@test "unknown argument is rejected on stderr with exit 2" {
    run --separate-stderr bash "$SCRIPT" --bogus
    [ "$status" -eq 64 ]
    [[ "$stderr" == *"unknown argument"* ]]
}
