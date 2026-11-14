#!/usr/bin/env bats
# The ws-* workspace commands must exist in fish (the login shell), not only
# in zsh, and both shells must point at the same scripts.
#
# Run:  bats tests/bash/ws-shell-parity.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # fish creates ~/.config/fish and ~/.local/share/fish even with --no-config.
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
    ZSH_TMPL="$REPO_ROOT/home/dot_ws.zsh.tmpl"
    FISH_TMPL="$REPO_ROOT/home/dot_config/fish/conf.d/ws.fish.tmpl"
}

zsh_commands() {
    {
        sed -nE 's/^alias ([a-z-]+)=.*/\1/p' "$ZSH_TMPL"
        sed -nE 's/^([a-z-]+)\(\) *\{.*/\1/p' "$ZSH_TMPL"
    } | sort -u
}

fish_commands() {
    sed -nE 's/^function ([a-z-]+)( .*)?$/\1/p' "$FISH_TMPL" | sort -u
}

@test "fish defines every ws command zsh defines" {
    [ -f "$FISH_TMPL" ]
    run diff <(zsh_commands) <(fish_commands)
    [ "$status" -eq 0 ]
}

@test "rendered fish file parses and defines ws functions" {
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"
    command -v fish >/dev/null 2>&1 || skip "fish not installed"
    rendered="$BATS_TEST_TMPDIR/ws.fish"
    chezmoi execute-template --source "$REPO_ROOT/home" \
        --file "$FISH_TMPL" >"$rendered"
    fish -n "$rendered"
    run fish --no-config -c "source $rendered; functions -q ws ws-health ws-health-once log-errors; and echo ok"
    [ "$output" = "ok" ]
}

@test "health dashboard is a shared script, not a zsh-only function body" {
    [ -f "$REPO_ROOT/ops/projects/health/dashboard.sh" ]
    run bash -n "$REPO_ROOT/ops/projects/health/dashboard.sh"
    [ "$status" -eq 0 ]
    ! grep -q 'while true' "$ZSH_TMPL"
}
