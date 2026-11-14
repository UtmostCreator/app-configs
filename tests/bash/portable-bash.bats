#!/usr/bin/env bats
# ops/install.sh runs vscode-extensions.sh and syncthing-obsidian-stignore.sh
# with /bin/bash 3.2 on a fresh Mac. Bash 4 features (${var,,}, declare -A)
# die there with "bad substitution" / "invalid option", so they are banned
# statically; the behaviour they provided is tested functionally.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset TMUX
}

@test "macOS-run scripts use no bash 4 features" {
    local f
    for f in ops/vscode-extensions.sh ops/syncthing-obsidian-stignore.sh; do
        if grep -nE '\$\{[A-Za-z_]+(,,|\^\^)' "$REPO_ROOT/$f"; then echo "$f: case-modifying expansion"; return 1; fi
        if grep -nE '(declare|local|typeset) -A|mapfile|readarray' "$REPO_ROOT/$f"; then echo "$f: bash 4 builtin"; return 1; fi
    done
}

@test "vscode-extensions matches installed extensions case-insensitively" {
    local bin="$BATS_TEST_TMPDIR/bin"; mkdir -p "$bin"
    printf '#!/bin/sh\necho Anthropic.Claude-Code\n' >"$bin/code"; chmod +x "$bin/code"
    run env PATH="$bin:$PATH" bash "$REPO_ROOT/ops/vscode-extensions.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"anthropic.claude-code"* ]]
    [[ "$output" == *"would install"* ]]
}

make_folder() {
    FOLDER="$BATS_TEST_TMPDIR/vault"
    mkdir -p "$FOLDER/.stfolder"
    printf 'x' >"$FOLDER/note.sync-conflict-20240101-000000-ABCDEFG.md"
}

@test "syncthing script finds the macOS config path" {
    command -v python3 >/dev/null || skip "python3 not installed"
    make_folder
    mkdir -p "$HOME/Library/Application Support/Syncthing"
    printf '<configuration><folder id="a" path="%s"/></configuration>\n' "$FOLDER" \
        >"$HOME/Library/Application Support/Syncthing/config.xml"
    run bash "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Folder:        $FOLDER"* ]]
}

@test "syncthing script counts a conflict file matched by several patterns once" {
    make_folder
    run bash "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh" --folder "$FOLDER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Conflict files: 1 found"* ]]
}
