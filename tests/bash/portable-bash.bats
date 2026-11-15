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

# ops/install.sh and the selection libraries it sources run on a fresh Mac under
# /bin/bash 3.2 (the review of T5 found mapfile there).
@test "install.sh, selection.sh, selection-facts.sh and selection-preview.sh use no bash 4 features" {
    local f
    for f in ops/install.sh ops/lib/selection.sh ops/lib/selection-facts.sh ops/lib/selection-preview.sh; do
        if grep -nE '\$\{[A-Za-z_]+(,,|\^\^)' "$REPO_ROOT/$f"; then echo "$f: case-modifying expansion"; return 1; fi
        if grep -nE '(declare|local|typeset) +-[A-Za-z]*[An]|(^|[^[:alnum:]_])(mapfile|readarray)([^[:alnum:]_]|$)' "$REPO_ROOT/$f"; then echo "$f: bash 4 builtin"; return 1; fi
        if grep -nE '&>>|\|&' "$REPO_ROOT/$f"; then echo "$f: bash 4 redirection"; return 1; fi
        # $'..' inside ${..} is not expanded under double quotes before bash 4.4
        if grep -nE "\\$\{[^}]*\\$'" "$REPO_ROOT/$f"; then echo "$f: ANSI-C quote inside a parameter expansion"; return 1; fi
        if grep -nE 'printf -v [A-Za-z_]+\[' "$REPO_ROOT/$f"; then echo "$f: printf -v into an array element"; return 1; fi
    done
}

@test "the selection libraries work with mapfile and readarray disabled" {
    run env HOME="$HOME" bash -c '
        enable -n mapfile readarray
        set -euo pipefail
        source "$1/ops/lib/selection.sh"
        source "$1/ops/lib/selection-facts.sh"
        source "$1/ops/lib/selection-preview.sh"
        SELECTION_REPO_ROOT="$1"
        selection_valid_profile work
        if selection_valid_profile nope; then echo "accepted nope"; exit 1; fi
        selection_group_defaults personal | sort | tr "\n" " "
        printf "\n"
        selection_write "$2/sel" work media=false
        cat "$2/sel/selection.toml"' _ "$REPO_ROOT" "$BATS_TEST_TMPDIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"go"*"media"*"security"* ]]
    [[ "$output" == *"media = false"* ]]
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
