#!/usr/bin/env bats
# The ws-* workspace commands must exist in fish (the login shell), not only
# in zsh, and both shells must point at the same scripts.
#
# Run:  bats tests/bash/ws-shell-parity.bats

bats_require_minimum_version 1.5.0

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

# name<TAB>command for every ws command that runs a bash script, with the
# directory variables spelled out so the two shells compare equal.
zsh_targets() {
    sed -nE 's/^alias ([a-z-]+)="bash ([^"]+)"$/\1\t\2/p' "$ZSH_TMPL" |
        sed -E 's#\$WS_(HEALTH|LOGGING)_DIR#$WS_PROJECTS_DIR/\L\1#' | sort
}

fish_targets() {
    awk '/^function [a-z-]+/ { name = $2; next }
         name != "" && /^ *bash / { sub(/^ *bash /, ""); gsub(/"/, ""); sub(/ *\$argv$/, ""); print name "\t" $0; name = "" }' "$FISH_TMPL" | sort
}

@test "each ws command runs the same script in fish and zsh" {
    run diff <(zsh_targets) <(fish_targets)
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [ "$(zsh_targets | wc -l)" -ge 15 ]
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

@test "log-errors delegates to restsift (res log-errors) in fish and zsh" {
    command -v fish >/dev/null 2>&1 || skip "fish not installed"
    stubs="$BATS_TEST_TMPDIR/bin"; mkdir -p "$stubs"
    printf '#!/bin/sh\necho "res $*"\n' >"$stubs/res"; chmod +x "$stubs/res"
    rendered="$BATS_TEST_TMPDIR/ws.fish"
    chezmoi execute-template --source "$REPO_ROOT/home" --file "$FISH_TMPL" >"$rendered"
    run env PATH="$stubs:$PATH" fish --no-config -c "source $rendered; log-errors --level error app.log"
    [ "$status" -eq 0 ]
    [ "$output" = "res log-errors --level error app.log" ]
    grep -qE "^alias log-errors=['\"]res log-errors['\"]" <(chezmoi execute-template --source "$REPO_ROOT/home" --file "$ZSH_TMPL")
}

@test "log-errors without restsift says where it lives" {
    command -v fish >/dev/null 2>&1 || skip "fish not installed"
    rendered="$BATS_TEST_TMPDIR/ws.fish"
    chezmoi execute-template --source "$REPO_ROOT/home" --file "$FISH_TMPL" >"$rendered"
    run -127 env PATH="$(dirname "$(command -v fish)")" fish --no-config -c "source $rendered; log-errors x.log"
    [[ "$output" == *"restsift"* ]]
}
