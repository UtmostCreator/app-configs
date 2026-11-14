#!/usr/bin/env bats
# Daily-loop abbreviations (fish) and their zsh twins, mined from shell
# history. fish and zsh must offer the same names with the same expansions.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # fish creates ~/.config/fish and ~/.local/share/fish even with --no-config.
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
    FISH_FILE="$REPO_ROOT/home/dot_config/fish/conf.d/cli.fish"
    : >"$BATS_TEST_TMPDIR/c.toml"
}

fish_abbrs() { # name<TAB>expansion, sorted
    fish --no-config -c "source $FISH_FILE; for n in (abbr --list); printf '%s\t%s\n' \$n (abbr --show | string match -r -- \"^abbr -a -- \$n (.*)\\\$\" | tail -n1 | string trim -c \"'\"); end" | sort
}

zsh_aliases() { # same format, from the CLI block in the rendered .zshrc
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/c.toml" --source "$REPO_ROOT/home" \
        --override-data '{"chezmoi":{"os":"linux"},"name":"T","email":"t@e.t","signingKey":""}' \
        --file "$REPO_ROOT/home/dot_zshrc.tmpl" |
        sed -n '/^# >>> cli shortcuts/,/^# <<< cli shortcuts/p' |
        sed -nE "s/^alias ([^=]+)='(.*)'$/\1\t\2/p" | sort
}

@test "cli.fish parses and defines the history-backed abbreviations" {
    fish -n "$FISH_FILE"
    run fish_abbrs
    [ "$status" -eq 0 ]
    for want in $'gst\tgit st' $'gco\tgit co' $'gl\tgit pull' $'gp\tgit push' \
        $'gd\tgit diff' $'gau\tgit add -u' $'gaa\tgit add .' $'gai\tgit add -i' \
        $'gcmsg\tgit commit -m' $'pa\tphp artisan' $'pat\tphp artisan test' \
        $'nr\tnpm run' $'ni\tnpm install' $'ll\teza -lah --git' $'reload\texec fish' $'lg\tlazygit'; do
        grep -qxF "$want" <<<"$output" || { echo "missing: $want"; return 1; }
    done
}

@test "zsh offers the same shortcuts as fish (reload differs by shell)" {
    diff <(fish_abbrs | grep -v '^reload') <(zsh_aliases | grep -v '^reload')
    zsh_aliases | grep -qxF $'reload\texec zsh'
}

@test "abbreviation names do not shadow installed commands" {
    for n in $(fish_abbrs | cut -f1); do
        case "$n" in gti|it) continue ;; esac   # typo catchers, on purpose
        if command -v "$n" >/dev/null 2>&1; then echo "shadows: $n -> $(command -v "$n")"; return 1; fi
    done
}

@test "gi fixes the 'gi tst' slip and runs git" {
    stubs="$BATS_TEST_TMPDIR/bin"; mkdir -p "$stubs"
    cat >"$stubs/git" <<'SH'
#!/bin/sh
case "$1" in --list-cmds=*) printf '%s\n' st pull status tag; exit 0 ;; esac
echo "git $*"
SH
    chmod +x "$stubs/git"
    run env PATH="$stubs:$PATH" fish --no-config -c "source $FISH_FILE; gi tst; gi tpull --rebase; gi status; gi tag -l"
    [ "${lines[0]}" = "git st" ]
    [ "${lines[1]}" = "git pull --rebase" ]
    [ "${lines[2]}" = "git status" ]
    [ "${lines[3]}" = "git tag -l" ]
}

@test "patw reruns a focused artisan test on file changes via watchexec" {
    stubs="$BATS_TEST_TMPDIR/bin"; mkdir -p "$stubs"
    printf '#!/bin/sh\necho "watchexec $*"\n' >"$stubs/watchexec"; chmod +x "$stubs/watchexec"
    run env PATH="$stubs:$PATH" fish --no-config -c "source $FISH_FILE; patw UserTest"
    [ "$output" = "watchexec -e php -r -c -- php artisan test --filter=UserTest" ]
    run env PATH="$stubs:$PATH" fish --no-config -c "source $FISH_FILE; patw"
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: patw"* ]]
}

@test "zc jumps with zoxide, then starts the agent (default claude)" {
    stubs="$BATS_TEST_TMPDIR/bin"; mkdir -p "$stubs" "$BATS_TEST_TMPDIR/proj"
    for a in claude codex; do printf '#!/bin/sh\necho "%s in $(pwd) $*"\n' "$a" >"$stubs/$a"; chmod +x "$stubs/$a"; done
    run env PATH="$stubs:$PATH" fish --no-config -c "function z; cd $BATS_TEST_TMPDIR/proj; end; source $FISH_FILE; zc proj"
    [ "$output" = "claude in $BATS_TEST_TMPDIR/proj " ]
    run env PATH="$stubs:$PATH" fish --no-config -c "function z; cd $BATS_TEST_TMPDIR/proj; end; source $FISH_FILE; zc proj codex --resume"
    [ "$output" = "codex in $BATS_TEST_TMPDIR/proj --resume" ]
    run env PATH="$stubs:$PATH" fish --no-config -c "function z; return 1; end; source $FISH_FILE; zc nowhere"
    [ "$status" -ne 0 ]
}

@test "hms switches Home Manager for this host from the dotfiles flake" {
    stubs="$BATS_TEST_TMPDIR/bin"; mkdir -p "$stubs" "$BATS_TEST_TMPDIR/dots/ops"
    printf '#!/bin/sh\necho "home-manager $*"\n' >"$stubs/home-manager"; chmod +x "$stubs/home-manager"
    printf '#!/bin/sh\necho wsl\n' >"$BATS_TEST_TMPDIR/dots/ops/detect-host.sh"
    run env PATH="$stubs:$PATH" DOTFILES_DIR="$BATS_TEST_TMPDIR/dots" fish --no-config -c "source $FISH_FILE; hms --show-trace"
    [ "$output" = "home-manager switch -b hm-bak --flake $BATS_TEST_TMPDIR/dots/nix#wsl --show-trace" ]
}
