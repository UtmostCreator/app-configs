#!/usr/bin/env bats
# Tests for home/.chezmoiignore: which hosts receive the Linux VS Code user
# settings at ~/.config/Code. Only a Linux desktop runs a Linux VS Code. macOS
# reads ~/Library/Application Support/Code, and on WSL2 the Windows VS Code
# reads %APPDATA% while the Remote-WSL server reads ~/.vscode-server, so
# ~/.config/Code would be dead files there.
#
# Run:  bats tests/bash/chezmoiignore-vscode.bats

setup() {
    command -v chezmoi >/dev/null || skip "chezmoi not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    IGNORE="$REPO_ROOT/home/.chezmoiignore"
    [ -f "$IGNORE" ]

    # An empty config and source dir keep the user's real chezmoi state out.
    CONFIG="$BATS_TEST_TMPDIR/chezmoi.toml"
    : >"$CONFIG"
    mkdir -p "$BATS_TEST_TMPDIR/source"
}

# render <os> <hostProfile> <gui>: print the rendered ignore list.
render() {
    local data
    data=$(printf '{"name":"Test","email":"test@example.com","signingKey":"","hostProfile":"%s","gui":%s,"chezmoi":{"os":"%s"}}' \
        "$2" "$3" "$1")
    chezmoi execute-template \
        --config "$CONFIG" \
        --source "$BATS_TEST_TMPDIR/source" \
        --override-data "$data" <"$IGNORE"
}

# has / lacks <pattern>: the rendered $output does / does not list the exact
# ignore line.
has() { grep -qxF -- "$1" <<<"$output"; }
lacks() {
    if grep -qxF -- "$1" <<<"$output"; then
        echo "unexpected ignore line: $1" >&2
        return 1
    fi
}

@test "wsl ignores ~/.config/Code (Remote-WSL never reads it)" {
    run render linux wsl false
    [ "$status" -eq 0 ]
    has '.config/Code'
    has '.config/Code/**'
}

@test "linux-desktop keeps ~/.config/Code (native Linux VS Code)" {
    run render linux linux-desktop true
    [ "$status" -eq 0 ]
    lacks '.config/Code'
    lacks '.config/Code/**'
}

@test "macos ignores ~/.config/Code (uses Library/Application Support)" {
    run render darwin macos true
    [ "$status" -eq 0 ]
    has '.config/Code'
    lacks 'Library/Application Support/Code'
}
