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

binding() { # binding <mode> <key> -> the command bound to it (editing block only)
    # vi mode prints cursor-shape escapes (ESC[6 q); strip them first.
    fish --no-config -i -c "source $BATS_TEST_TMPDIR/keys.fish; bind -M $1 $2" 2>/dev/null |
        sed $'s/\x1b\\[[0-9]* q//g' | grep -v -- '--preset' | grep -E "^bind( -M $1)? $2 " | tail -n1 | sed -E "s/^bind( -M $1)? $2 //"
}

# Stubs whose output mimics `fzf --fish` (defines fzf_complete, binds Ctrl-T and
# Alt-C) and `atuin init fish` (binds Ctrl-R). $1 = "fzf" adds the fzf stub.
stub_tools() {
    # The only PATH of run_fish: fish itself plus the stubs, so a real fzf on
    # this machine can never leak in.
    local bin="$BATS_TEST_TMPDIR/bin"; mkdir -p "$bin"; ln -sf "$(command -v fish)" "$bin/fish"
    printf '#!/bin/sh\necho "bind -M insert ctrl-r _atuin_search"\n' >"$bin/atuin"
    if [ "$1" = fzf ]; then
        printf '#!/bin/sh\necho "function fzf_complete; end"\necho "bind -M insert ctrl-t fzf-file-widget"\necho "bind -M insert alt-c fzf-cd-widget"\n' >"$bin/fzf"
    fi
    chmod +x "$bin/atuin"; if [ -e "$bin/fzf" ]; then chmod +x "$bin/fzf"; fi
}

# Run fish -i with the whole rendered config and only the stubs on PATH.
run_fish() { # run_fish <fish -c script>
    mkdir -p "$HOME/.config/fish"; cp "$CFG" "$HOME/.config/fish/config.fish"
    env XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" \
        XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache" \
        PATH="$BATS_TEST_TMPDIR/bin" \
        "$BATS_TEST_TMPDIR/bin/fish" -i -c "$1" 2>/dev/null | sed $'s/\x1b\\[[0-9]* q//g'
}

full_binding() { # full_binding <key> -> insert-mode bind after the whole rendered config
    run_fish "bind -M insert $1" | grep -v -- '--preset' | grep -E "^bind( -M insert)? $1 " |
        tail -n1 | sed -E "s/^bind( -M insert)? $1 //"
}

@test "Tab in insert mode is plain completion in the editing block (the fzf-less fallback)" {
    [ "$(binding insert tab)" = "complete" ]
}

@test "Tab opens the fzf menu (fzf_complete, same as Shift-Tab) when fzf --fish defines it" {
    stub_tools fzf
    [ "$(full_binding tab)" = "fzf_complete" ]
}

@test "Tab stays plain completion without fzf" {
    stub_tools none
    [ "$(full_binding tab)" = "complete" ]
}

@test "the fzf Tab menu inserts a single candidate directly (--select-1) unless the user set options" {
    stub_tools fzf
    [[ "$(run_fish 'echo "opts[$FZF_COMPLETION_OPTS]"')" == *"opts[--select-1]"* ]]
    FZF_COMPLETION_OPTS="--exact" run_fish 'echo "opts[$FZF_COMPLETION_OPTS]"' >"$BATS_TEST_TMPDIR/o"
    [[ "$(cat "$BATS_TEST_TMPDIR/o")" == *"opts[--exact]"* ]]
}

@test "with the fzf Tab menu, Ctrl-T, Alt-C, Ctrl-R, Right and Ctrl-C keep their owners (rendered config)" {
    stub_tools fzf
    [ "$(full_binding ctrl-t)" = "fzf-file-widget" ]
    [ "$(full_binding alt-c)" = "fzf-cd-widget" ]
    [ "$(full_binding ctrl-r)" = "_atuin_search" ]
    [ "$(full_binding right)" = "forward-char" ]
    [ "$(full_binding ctrl-c)" = "cancel-commandline" ]
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
    # config.fish runs `op whoami`; the real 1Password CLI forks an `op daemon`
    # that outlives the test. A failing `op` first on PATH keeps it out.
    local bin="$BATS_TEST_TMPDIR/opbin"; mkdir -p "$bin"
    printf '#!/bin/sh\necho "$*" >>"%s/op.calls"\nexit 1\n' "$BATS_TEST_TMPDIR" >"$bin/op"; chmod +x "$bin/op"
    run env HOME="$HOME" PATH="$bin:$PATH" XDG_CONFIG_HOME="$HOME/.config" \
        XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache" \
        fish -i -c 'set -q fish_greeting; and echo "defined[$fish_greeting]"'
    # Unset and empty both expand to nothing; only a defined-empty variable
    # stops fish from printing its stock greeting.
    [[ "$output" == *"defined[]"* ]]
    # The config did reach `op`, only the stub answered, and no real `op`
    # (daemon) was started with this test's HOME.
    grep -qx 'whoami' "$BATS_TEST_TMPDIR/op.calls"
    local pid
    for pid in $(pgrep -x op || true); do
        if tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | grep -qxF "HOME=$HOME"; then
            echo "leaked op pid $pid" >&2; return 1
        fi
    done
}
