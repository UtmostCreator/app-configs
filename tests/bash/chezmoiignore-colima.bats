#!/usr/bin/env bats
# Tests for home/.chezmoiignore: ~/.colima (home/dot_colima) is Colima's
# config, and Colima is macOS-only (nix/modules/home/dev.nix, T-0038). Linux
# and WSL2 use a native or host Docker daemon, so the file must not deploy there.
#
# Run:  bats tests/bash/chezmoiignore-colima.bats

setup() {
    command -v chezmoi >/dev/null || skip "chezmoi not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    IGNORE="$REPO_ROOT/home/.chezmoiignore"
    CONFIG="$BATS_TEST_TMPDIR/chezmoi.toml"
    : >"$CONFIG"
    mkdir -p "$BATS_TEST_TMPDIR/source"
}

render() {
    local data
    data=$(printf '{"name":"Test","email":"test@example.com","signingKey":"","hostProfile":"%s","gui":%s,"chezmoi":{"os":"%s"}}' \
        "$2" "$3" "$1")
    chezmoi execute-template --config "$CONFIG" --source "$BATS_TEST_TMPDIR/source" \
        --override-data "$data" <"$IGNORE"
}

has() { grep -qxF -- "$1" <<<"$output"; }

@test "colima ignore: Linux desktop, Linux CLI and WSL2 skip ~/.colima" {
    for p in "linux-desktop true" "linux-cli false" "wsl false"; do
        set -- $p
        run render linux "$1" "$2"
        [ "$status" -eq 0 ]
        has ".colima"
        has ".colima/**"
    done
}

@test "colima ignore: macOS deploys ~/.colima" {
    run render darwin macos true
    [ "$status" -eq 0 ]
    rendered="$output"
    run grep -cxF -e ".colima" -e ".colima/**" <<<"$rendered"
    [ "$output" = 0 ]
}
