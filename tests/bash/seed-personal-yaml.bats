#!/usr/bin/env bats
# ops/seed-personal-yaml.sh writes the first personal.yaml from the example,
# with hostProfile and gui matching the detected host instead of the example's.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/seed-personal-yaml.sh"
    EXAMPLE="$REPO_ROOT/home/personal.yaml.example"
    DEST="$BATS_TEST_TMPDIR/personal.yaml"
}

value() { yq -r ".$1" "$DEST"; }

@test "macos seeds hostProfile=macos and gui=true" {
    run bash "$SCRIPT" "$EXAMPLE" "$DEST" macos
    [ "$status" -eq 0 ]
    [ "$(value hostProfile)" = "macos" ]
    [ "$(value gui)" = "true" ]
}

@test "linux-desktop seeds gui=true" {
    bash "$SCRIPT" "$EXAMPLE" "$DEST" linux-desktop
    [ "$(value hostProfile)" = "linux-desktop" ]
    [ "$(value gui)" = "true" ]
}

@test "wsl and linux-cli seed gui=false" {
    for p in wsl linux-cli; do
        rm -f "$DEST"
        bash "$SCRIPT" "$EXAMPLE" "$DEST" "$p"
        [ "$(value hostProfile)" = "$p" ]
        [ "$(value gui)" = "false" ]
    done
}

@test "other keys and comments are kept from the example" {
    bash "$SCRIPT" "$EXAMPLE" "$DEST" macos
    [ "$(value name)" = "Your Full Name" ]
    [ "$(value useGitDelta)" = "true" ]
    grep -q '^# Host profile selector' "$DEST"
}

@test "an existing personal.yaml is never overwritten" {
    printf 'name: Real\nhostProfile: "linux-cli"\n' >"$DEST"
    run bash "$SCRIPT" "$EXAMPLE" "$DEST" macos
    [ "$status" -eq 0 ]
    [ "$(value name)" = "Real" ]
    [ "$(value hostProfile)" = "linux-cli" ]
}

@test "unknown profile fails without writing" {
    run bash "$SCRIPT" "$EXAMPLE" "$DEST" windows
    [ "$status" -ne 0 ]
    [ ! -e "$DEST" ]
}
