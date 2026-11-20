#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    source "$REPO_ROOT/tests/lib/isolation.sh"
    GUARD="$BATS_TEST_TMPDIR/guard"
    isolation_guard_make "$GUARD" brew mas softwareupdate darwin-rebuild nixos-rebuild launchctl
}

@test "the guard blocks every guarded command with exit 97 and names it" {
    for name in brew mas softwareupdate darwin-rebuild nixos-rebuild launchctl; do
        run env PATH="$GUARD:$PATH" "$name" install thing
        [ "$status" -eq 97 ]
        [[ "$output" == *"blocked real $name install thing"* ]]
    done
}

@test "the guard blocks brew update and upgrade and creates nothing" {
    cd "$BATS_TEST_TMPDIR"
    before="$(ls -A | LC_ALL=C sort | tr '\n' ,)"
    run env PATH="$GUARD:$PATH" brew update
    [ "$status" -eq 97 ]
    run env PATH="$GUARD:$PATH" brew upgrade --formula
    [ "$status" -eq 97 ]
    [ "$(ls -A | LC_ALL=C sort | tr '\n' ,)" = "$before" ]
}

@test "subprocesses inherit the guard" {
    printf '#!/bin/sh\nbrew update\n' >"$BATS_TEST_TMPDIR/child.sh"
    chmod +x "$BATS_TEST_TMPDIR/child.sh"
    run env PATH="$GUARD:$PATH" bash -c "$BATS_TEST_TMPDIR/child.sh"
    [ "$status" -eq 97 ]
    run env PATH="$GUARD:$PATH" sh -c 'env brew update'
    [ "$status" -eq 97 ]
    run env PATH="$GUARD:$PATH" bash -c 'echo go | xargs brew update'
    [ "$status" -ne 0 ]
}

@test "a test's own stub still wins over the guard" {
    mkdir "$BATS_TEST_TMPDIR/stubs"
    printf '#!/bin/sh\necho stubbed "$@"\n' >"$BATS_TEST_TMPDIR/stubs/brew"
    chmod +x "$BATS_TEST_TMPDIR/stubs/brew"
    run env PATH="$BATS_TEST_TMPDIR/stubs:$GUARD:$PATH" brew update
    [ "$status" -eq 0 ]
    [ "$output" = "stubbed update" ]
}

@test "the guard only stubs commands the host really has, unless it is told which" {
    run bash -c 'source "$1"; d="$2"; ISOLATION_GUARDED_COMMANDS=(definitely-not-a-real-command-xyz); isolation_guard_make "$d"; ls "$d" | wc -l | tr -d " "' _ "$REPO_ROOT/tests/lib/isolation.sh" "$BATS_TEST_TMPDIR/empty-guard"
    [ "$output" = 0 ]
}

@test "the fingerprint is read-only and stable between two reads" {
    first="$(isolation_fingerprint "$REPO_ROOT")"
    second="$(isolation_fingerprint "$REPO_ROOT")"
    [ "$first" = "$second" ]
    [[ "$first" == *"repo-head "* ]]
}

@test "the fingerprint changes when a Homebrew-style Cellar changes" {
    prefix="$BATS_TEST_TMPDIR/prefix"
    mkdir -p "$prefix/Cellar/tool/1.0" "$prefix/bin"
    export ISOLATION_BREW_PREFIX="$prefix"
    before="$(isolation_fingerprint "$REPO_ROOT")"
    mkdir -p "$prefix/Cellar/tool/2.0"
    after="$(isolation_fingerprint "$REPO_ROOT")"
    [ "$before" != "$after" ]
}

@test "the runner exports the isolation controls and a scratch HOME" {
    [ "${APP_CONFIGS_TEST_MODE:-}" = isolated ] || skip "run through ops/run-bats.sh"
    [[ "$HOME" == "$TMPDIR"/* || "$HOME" == */run-bats.*/home ]]
    [[ "$PATH" == */guard-bin:* ]]
}

@test "the runner's sandbox refuses absolute-path writes to the real HOME" {
    [ "${APP_CONFIGS_TEST_SANDBOXED:-0}" = 1 ] || skip "macOS sandbox only"
    probe="$APP_CONFIGS_TEST_REAL_HOME/.app-configs-sandbox-probe"
    run mkdir "$probe"
    if [ -d "$probe" ]; then rmdir "$probe"; fi
    [ "$status" -ne 0 ]
}

@test "the runner's sandbox refuses to execute sudo by absolute path" {
    [ "${APP_CONFIGS_TEST_SANDBOXED:-0}" = 1 ] || skip "macOS sandbox only"
    run /usr/bin/sudo -n true
    [ "$status" -ne 0 ]
    [[ "$output" == *"not permitted"* || "$output" == *"Operation not"* ]]
}
