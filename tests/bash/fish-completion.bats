#!/usr/bin/env bats
# Interactive fish completion: Tab must list candidates (folders in the
# current directory and the workspace), not accept an old history suggestion.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # Interactive fish (-i) writes fish_variables and history under HOME.
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    : >"$BATS_TEST_TMPDIR/c.toml"
    CFG="$BATS_TEST_TMPDIR/config.fish"
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/c.toml" --source "$REPO_ROOT/home" \
        --override-data '{"chezmoi":{"os":"linux"},"name":"T","email":"t@e.t","signingKey":""}' \
        --file "$REPO_ROOT/home/dot_config/fish/config.fish.tmpl" >"$CFG"
    # The editing block only: vi mode and its key bindings.
    sed -n '/^# ─── Editing mode/,/^# ─── /p' "$CFG" | sed '$d' >"$BATS_TEST_TMPDIR/keys.fish"
}

binding() { # binding <mode> <key> -> the command bound to it
    # vi mode prints cursor-shape escapes (ESC[6 q); strip them first.
    fish --no-config -i -c "source $BATS_TEST_TMPDIR/keys.fish; bind -M $1 $2" 2>/dev/null |
        sed $'s/\x1b\\[[0-9]* q//g' | grep -v -- '--preset' | grep -E "^bind( -M $1)? $2 " | tail -n1 | sed -E "s/^bind( -M $1)? $2 //"
}

@test "Tab in insert mode completes (lists folders), it does not accept history" {
    [ "$(binding insert tab)" = "complete" ]
}

@test "suggestions stay one key away: Right, End and Ctrl-F accept them" {
    [ "$(binding insert right)" = "forward-char" ]
    [[ "$(binding insert end)" == "accept-autosuggestion"* ]]
    [ "$(binding insert ctrl-f)" = "accept-autosuggestion" ]
}

@test "CDPATH offers workspace folders but is not exported to scripts" {
    grep -qx 'set -g CDPATH . $HOME/Projects' "$CFG"
    if grep -qE 'set -gx CDPATH|set -Ux CDPATH|export CDPATH' "$CFG"; then echo 'assertion failed: expected no match' >&2; return 1; fi
    home="$BATS_TEST_TMPDIR/home"; mkdir -p "$home/Projects/app-alpha" "$BATS_TEST_TMPDIR/elsewhere"
    run env HOME="$home" fish --no-config -c "cd $BATS_TEST_TMPDIR/elsewhere; set -g CDPATH . \$HOME/Projects; complete -C 'cd app-al'"
    [[ "$output" == *"app-alpha/"* ]]
}

@test "rendered config silences the default fish greeting" {
    # Real startup path: config.fish in a scratch HOME, interactive fish.
    mkdir -p "$HOME/.config/fish"; cp "$CFG" "$HOME/.config/fish/config.fish"
    run env HOME="$HOME" XDG_CONFIG_HOME="$HOME/.config" \
        XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache" \
        fish -i -c 'set -q fish_greeting; and echo "defined[$fish_greeting]"'
    # Unset and empty both expand to nothing; only a defined-empty variable
    # stops fish from printing its stock greeting.
    [[ "$output" == *"defined[]"* ]]
}
