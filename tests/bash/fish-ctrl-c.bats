#!/usr/bin/env bats
# Ctrl+C at the fish prompt must cancel (^C + fresh prompt line), not clear in
# place. The binds live in config.fish.tmpl right after fish_vi_key_bindings.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # fish creates ~/.config/fish and ~/.local/share/fish even with --no-config.
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
    printf '' >"$BATS_TEST_TMPDIR/c.toml"
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/c.toml" --source "$REPO_ROOT/home" \
        --override-data '{"chezmoi":{"os":"linux"},"name":"T","email":"t@e.t","signingKey":""}' \
        --file "$REPO_ROOT/home/dot_config/fish/config.fish.tmpl" >"$BATS_TEST_TMPDIR/config.fish"
    sed -n '/^# >>> ctrl-c cancel/,/^# <<< ctrl-c cancel/p' "$BATS_TEST_TMPDIR/config.fish" >"$BATS_TEST_TMPDIR/snippet.fish"
}

user_binds() { # $1 = key-bindings function; non-preset ctrl-c bind lines only
    fish --no-config -ic "$1; source $BATS_TEST_TMPDIR/snippet.fish; bind -M insert ctrl-c; bind -M default ctrl-c" |
        grep -v -- '--preset'
}

@test "the ctrl-c block is in config.fish directly after fish_vi_key_bindings" {
    [ -s "$BATS_TEST_TMPDIR/snippet.fish" ]
    fish -n "$BATS_TEST_TMPDIR/snippet.fish"
    run grep -A2 '^fish_vi_key_bindings$' "$BATS_TEST_TMPDIR/config.fish"
    [[ "$output" == *"# >>> ctrl-c cancel"* ]]
}

@test "vi mode: Ctrl+C cancels the command line in insert and default modes" {
    run user_binds fish_vi_key_bindings
    [ "$status" -eq 0 ]
    [[ "$output" == *"-M insert ctrl-c cancel-commandline"* ]]
    [[ "$output" == *"bind ctrl-c __app_configs_ctrl_c"* ]]
    [[ "$output" != *"clear-commandline"* ]]
}

@test "emacs mode: Ctrl+C never switches bind mode (no -m insert)" {
    run user_binds fish_default_key_bindings
    [ "$status" -eq 0 ]
    [[ "$output" == *"cancel-commandline"* ]]
    [[ "$output" != *"-m insert"* ]]
    [[ "$output" != *"repaint-mode"* ]]
}

# Run the handler with `commandline` stubbed to record its arguments.
ctrl_c_calls() { # $1 = value of $fish_key_bindings; prints calls then the mode
    fish --no-config -c "
        function commandline; echo \"commandline \$argv\"; end
        source $BATS_TEST_TMPDIR/snippet.fish
        set -g fish_key_bindings $1
        set -g fish_bind_mode default
        __app_configs_ctrl_c
        echo mode=\$fish_bind_mode"
}

@test "handler: vi bindings cancel, return to insert mode and repaint" {
    run ctrl_c_calls fish_vi_key_bindings
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "commandline -f cancel-commandline" ]
    [ "${lines[1]}" = "commandline -f repaint-mode" ]
    [ "${lines[2]}" = "mode=insert" ]
}

@test "handler: emacs bindings only cancel and keep the bind mode" {
    run ctrl_c_calls fish_default_key_bindings
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "commandline -f cancel-commandline" ]
    [ "${lines[1]}" = "mode=default" ]
    [ "${#lines[@]}" -eq 2 ]
}
