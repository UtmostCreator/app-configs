#!/usr/bin/env bats
# fish and zsh configs render cleanly for both macOS and Linux/WSL2: macOS
# keeps its Herd/Homebrew paths, Linux gets none of them but keeps the
# shared 1Password integrations.

setup_file() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    if ! command -v zsh >/dev/null 2>&1; then
        local p
        p="$(nix build --no-link --print-out-paths \
            "path:$REPO_ROOT/nix#homeConfigurations.wsl.pkgs.zsh.out" 2>/dev/null | head -n1)"
        [ -n "$p" ] && export BATS_ZSH="$p/bin/zsh"
    else
        export BATS_ZSH="$(command -v zsh)"
    fi
}

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # fish creates ~/.config/fish and ~/.local/share/fish even with --no-config.
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
    : >"$BATS_TEST_TMPDIR/chezmoi.toml"
}

render() { # render <os> <template> -> path of rendered file
    local out="$BATS_TEST_TMPDIR/$1-$(basename "$2" .tmpl)"
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/chezmoi.toml" \
        --source "$REPO_ROOT/home" \
        --override-data "{\"chezmoi\":{\"os\":\"$1\"},\"name\":\"T\",\"email\":\"t@example.test\",\"signingKey\":\"\"}" \
        --file "$REPO_ROOT/home/$2" >"$out"
    echo "$out"
}

macos_only='Library/Application Support|/Applications/Herd|/opt/homebrew'

@test "fish (linux): parses, no macOS paths, keeps 1Password helpers" {
    f="$(render linux dot_config/fish/config.fish.tmpl)"
    fish -n "$f"
    ! grep -Eq "$macos_only" "$f"
    grep -q "op item get 'GitHub NPM Token'" "$f"
    run fish --no-config -c "source (sed -n '/^function composer/,/^end/p' $f | psub); and source (sed -n '/^function op-refresh/,/^end/p' $f | psub); and functions -q composer op-refresh; and echo ok"
    [ "$output" = "ok" ]
}

@test "fish (darwin): parses and keeps Herd composer" {
    f="$(render darwin dot_config/fish/config.fish.tmpl)"
    fish -n "$f"
    grep -q 'Herd/bin/composer' "$f"
    grep -q 'fish_add_path -g /opt/homebrew/opt/mysql-client/bin' "$f"
}

@test "fish composer on linux without op runs Nix composer directly" {
    f="$(render linux dot_config/fish/config.fish.tmpl)"
    stubs="$BATS_TEST_TMPDIR/bin"; mkdir -p "$stubs"
    printf '#!/bin/sh\necho "composer:$*"\n' >"$stubs/composer"; chmod +x "$stubs/composer"
    sed -n '/^function composer/,/^end/p' "$f" >"$BATS_TEST_TMPDIR/composer.fish"
    # PATH has only the stub and fish: no op, so the wrapper must not use it.
    run env PATH="$stubs:$(dirname "$(command -v fish)")" HOME="$BATS_TEST_TMPDIR" \
        "$(command -v fish)" --no-config -c "source $BATS_TEST_TMPDIR/composer.fish; composer install --no-dev"
    [ "$status" -eq 0 ]
    [ "$output" = "composer:install --no-dev" ]
}

@test "zsh (linux): parses, no macOS paths, Nix plugins and oh-my-zsh guarded" {
    [ -n "${BATS_ZSH:-}" ] || skip "zsh unavailable"
    f="$(render linux dot_zshrc.tmpl)"
    "$BATS_ZSH" -n "$f"
    ! grep -Eq "$macos_only" "$f"
    ! grep -q '^brewup()' "$f"
    grep -q 'zsh-syntax-highlighting.zsh' "$f"
    grep -q '\[ -r "$ZSH/oh-my-zsh.sh" \]' "$f"
}

@test "zsh (linux): starts with no errors in a bare home" {
    [ -n "${BATS_ZSH:-}" ] || skip "zsh unavailable"
    f="$(render linux dot_zshrc.tmpl)"
    run env -i HOME="$BATS_TEST_TMPDIR" PATH="/usr/bin:/bin" TERM=dumb \
        "$BATS_ZSH" -c "source $f" 2>&1
    [ -z "$output" ]
}

@test "zsh (darwin): keeps Herd and Homebrew" {
    [ -n "${BATS_ZSH:-}" ] || skip "zsh unavailable"
    f="$(render darwin dot_zshrc.tmpl)"
    "$BATS_ZSH" -n "$f"
    grep -q 'Herd/bin' "$f"
    grep -q '^brewup()' "$f"
}

@test "zprofile: brew shellenv only on macOS" {
    grep -q 'brew shellenv' "$(render darwin dot_zprofile.tmpl)"
    ! grep -q 'brew' "$(render linux dot_zprofile.tmpl)"
}
