#!/usr/bin/env bats
# Install selection (T-0042): the committed selection input, the profile
# files and the myConfig.groups option, checked from the evaluated flake. A
# fixture directory stands in for the local selection and is passed the way the
# scripts will pass it: --override-input selection path:<dir>. Nothing is built
# or activated.

bats_require_minimum_version 1.5.0

setup_file() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export REPO_ROOT
    command -v nix >/dev/null || return 0
    # One drvPath per (selection, host) pair, evaluated once per file; the
    # tests compare the recorded values.
    local h
    for h in linux-cli linux-desktop; do
        drv "$h" default >"$BATS_FILE_TMPDIR/drv-default-$h" 2>/dev/null || true
    done
    drv linux-cli empty >"$BATS_FILE_TMPDIR/drv-empty-linux-cli" 2>/dev/null || true
    drv linux-cli all-on-work >"$BATS_FILE_TMPDIR/drv-all-on-work-linux-cli" 2>/dev/null || true
    drv linux-desktop all-on-personal >"$BATS_FILE_TMPDIR/drv-all-on-personal-linux-desktop" 2>/dev/null || true
}

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIX="$BATS_TEST_DIRNAME/fixtures/selection"
    command -v nix >/dev/null || skip "nix not installed"
}

# sel <fixture>: the override arguments for one fixture ("default" = none).
sel() {
    if [ "$1" = default ]; then return 0; fi
    printf '%s\n' --override-input selection "path:$BATS_TEST_DIRNAME/fixtures/selection/$1"
}

# drv <host> <fixture>: activation drvPath.
drv() {
    local args=()
    mapfile -t args < <(sel "$2")
    timeout 600 nix eval --raw "path:$REPO_ROOT/nix#homeConfigurations.$1.activationPackage.drvPath" "${args[@]}" 2>/dev/null
}

# hmjson <host> <fixture> <attr under config>: evaluate to JSON.
hmjson() {
    local args=()
    mapfile -t args < <(sel "$2")
    timeout 600 nix eval --json "path:$REPO_ROOT/nix#homeConfigurations.$1.config.$3" "${args[@]}"
}

recorded() { cat "$BATS_FILE_TMPDIR/drv-$1" 2>/dev/null; }

@test "the committed selection file exists and is empty (no selection)" {
    [ -f "$REPO_ROOT/nix/selection/selection.toml" ]
    [ ! -s "$REPO_ROOT/nix/selection/selection.toml" ]
}

@test "each profile file is named for a profile and lists exactly the declared groups" {
    run --separate-stderr nix eval --json --impure --expr '
      let
        dir = builtins.getEnv "REPO_ROOT" + "/nix/profiles";
        read = n: (builtins.fromTOML (builtins.readFile (dir + "/${n}.toml"))).groups;
      in { work = builtins.attrNames (read "work"); personal = builtins.attrNames (read "personal"); }'
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '.work == ["go","media","security"] and .personal == ["go","media","security"]' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "default: every group is on" {
    run --separate-stderr hmjson linux-cli default myConfig.groups
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '. == {go: true, media: true, security: true}' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "empty selection file via override: identical drvPath to no override" {
    [ -n "$(recorded default-linux-cli)" ]
    [ "$(recorded empty-linux-cli)" = "$(recorded default-linux-cli)" ]
}

@test "all-on fixture (work): same drvPath as the default on linux-cli" {
    [ -n "$(recorded default-linux-cli)" ]
    [ "$(recorded all-on-work-linux-cli)" = "$(recorded default-linux-cli)" ]
}

@test "all-on fixture (personal): same drvPath as the default on linux-desktop" {
    [ -n "$(recorded default-linux-desktop)" ]
    [ "$(recorded all-on-personal-linux-desktop)" = "$(recorded default-linux-desktop)" ]
}

@test "a selection profile overrides the host profile" {
    run --separate-stderr hmjson linux-desktop profile-only-personal myConfig.profile
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = '"personal"' ]
    run --separate-stderr hmjson linux-desktop all-on-work myConfig.profile
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = '"work"' ]
}

@test "group deltas override the profile defaults" {
    run --separate-stderr hmjson linux-cli media-go-off myConfig.groups
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '. == {go: false, media: false, security: true}' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "an unknown group fails evaluation and names the key" {
    run hmjson linux-cli unknown-group myConfig.groups
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown group 'bogus'"* ]]
}

@test "an unknown profile fails evaluation and names the key" {
    run hmjson linux-cli unknown-profile myConfig.groups
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown profile 'nope'"* ]]
}

@test "groups without a profile fail evaluation and name the key" {
    run hmjson linux-cli groups-without-profile myConfig.groups
    [ "$status" -ne 0 ]
    [[ "$output" == *"'profile' is missing"* ]]
}
