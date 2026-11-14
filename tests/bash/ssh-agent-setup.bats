#!/usr/bin/env bats
# ops/unix/ssh-agent-setup.sh must never write to files chezmoi manages:
# that made sys-update refuse to run ("hand-edited managed file") and
# overwrote the managed fish snippet during an install.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/unix/ssh-agent-setup.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.config/fish/conf.d" "$HOME/.config/app-configs" "$HOME/.ssh"
    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    printf '#!/bin/sh\nexit 0\n' >"$STUBS/keychain"; chmod +x "$STUBS/keychain"
    echo '# managed zshrc' >"$HOME/.zshrc"
    echo '# managed fish snippet' >"$HOME/.config/fish/conf.d/ssh-agent.fish"
    echo '# managed loader' >"$HOME/.config/app-configs/ssh-agent.sh"
}

chezmoi_manages() { # chezmoi_manages yes|no
    if [ "$1" = yes ]; then
        printf '#!/bin/sh\n[ "$1" = source-path ] && exit 0\nexit 1\n' >"$STUBS/chezmoi"
    else
        printf '#!/bin/sh\nexit 1\n' >"$STUBS/chezmoi"
    fi
    chmod +x "$STUBS/chezmoi"
}

@test "zsh: a chezmoi-managed ~/.zshrc and loader are left untouched" {
    chezmoi_manages yes
    run env USER=no-such-user-bats PATH="$STUBS:$PATH" SHELL=/bin/zsh bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.zshrc")" = "# managed zshrc" ]
    [ "$(cat "$HOME/.config/app-configs/ssh-agent.sh")" = "# managed loader" ]
    [[ "$output" == *"managed by chezmoi"* ]]
}

@test "fish: a chezmoi-managed conf.d snippet is not overwritten" {
    chezmoi_manages yes
    run env USER=no-such-user-bats PATH="$STUBS:$PATH" SHELL=/usr/bin/fish bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/fish/conf.d/ssh-agent.fish")" = "# managed fish snippet" ]
}

@test "--remove never deletes or edits chezmoi-managed files" {
    chezmoi_manages yes
    run env USER=no-such-user-bats PATH="$STUBS:$PATH" SHELL=/bin/zsh bash "$SCRIPT" --remove
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/fish/conf.d/ssh-agent.fish" ]
    [ "$(cat "$HOME/.zshrc")" = "# managed zshrc" ]
}

@test "without chezmoi ownership the rc is still wired (unchanged behaviour)" {
    chezmoi_manages no
    run env USER=no-such-user-bats PATH="$STUBS:$PATH" SHELL=/bin/zsh bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q '>>> app-configs ssh-agent >>>' "$HOME/.zshrc"
}

@test "--help prints usage and changes nothing" {
    chezmoi_manages no
    rm -f "$HOME/.zshrc"
    run env PATH="$STUBS:$PATH" SHELL=/bin/zsh bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [ ! -e "$HOME/.zshrc" ]
    [ "$(cat "$HOME/.config/app-configs/ssh-agent.sh")" = "# managed loader" ]
}

@test "unknown arguments (--dry-run, typos) exit 2 and change nothing" {
    chezmoi_manages no
    rm -f "$HOME/.zshrc"
    for a in --dry-run --remvoe foo; do
        run env PATH="$STUBS:$PATH" SHELL=/bin/zsh bash "$SCRIPT" "$a"
        [ "$status" -eq 2 ]
        [ ! -e "$HOME/.zshrc" ]
    done
    run env PATH="$STUBS:$PATH" SHELL=/bin/zsh bash "$SCRIPT" --remove extra
    [ "$status" -eq 2 ]
}

@test "--remove never deletes a chezmoi-managed loader even when the rc is not managed" {
    printf '#!/bin/sh\n[ "$2" = "%s" ] && exit 0\nexit 1\n' "$HOME/.config/app-configs/ssh-agent.sh" >"$STUBS/chezmoi"
    chmod +x "$STUBS/chezmoi"
    printf '# >>> app-configs ssh-agent >>>\nx\n# <<< app-configs ssh-agent <<<\n' >"$HOME/.zshrc"
    run env PATH="$STUBS:$PATH" SHELL=/bin/zsh bash "$SCRIPT" --remove
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/app-configs/ssh-agent.sh" ]
    ! grep -q '>>> app-configs' "$HOME/.zshrc"
}

@test "an unset USER does not abort the installer" {
    chezmoi_manages yes
    run env -u USER PATH="$STUBS:$PATH" SHELL=/bin/zsh bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "the chezmoi-managed rc templates source the loader themselves" {
    : >"$BATS_TEST_TMPDIR/c.toml"
    for t in dot_zshrc.tmpl dot_bashrc.tmpl; do
        out="$(chezmoi execute-template --config "$BATS_TEST_TMPDIR/c.toml" --source "$REPO_ROOT/home" \
            --override-data '{"name":"T","email":"t@e.t","signingKey":""}' --file "$REPO_ROOT/home/$t")"
        grep -qF '. "$HOME/.config/app-configs/ssh-agent.sh"' <<<"$out" || { echo "missing in $t"; return 1; }
    done
}
