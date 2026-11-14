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

@test "the chezmoi-managed rc templates source the loader themselves" {
    : >"$BATS_TEST_TMPDIR/c.toml"
    for t in dot_zshrc.tmpl dot_bashrc.tmpl; do
        out="$(chezmoi execute-template --config "$BATS_TEST_TMPDIR/c.toml" --source "$REPO_ROOT/home" \
            --override-data '{"name":"T","email":"t@e.t","signingKey":""}' --file "$REPO_ROOT/home/$t")"
        grep -qF '. "$HOME/.config/app-configs/ssh-agent.sh"' <<<"$out" || { echo "missing in $t"; return 1; }
    done
}

# --- T-0021: injection, ownership, ssh config, markers, args ----------------

BEGIN_M='# >>> app-configs ssh-agent >>>'
END_M='# <<< app-configs ssh-agent <<<'

# setup_run <shell-path> [args...]: run the installer against the temp HOME.
setup_run() {
    local sh="$1"; shift
    run env -u XDG_CONFIG_HOME USER=no-such-user-bats PATH="$STUBS:$PATH" SHELL="$sh" \
        bash "$SCRIPT" "$@"
}

# Fresh state: nothing pre-seeded, so the installer is the creator of files.
clean_home() {
    rm -rf "$HOME/.config" "$HOME/.zshrc" "$HOME/.ssh"
    mkdir -p "$HOME"
}

stub_uname() { printf '#!/bin/sh\necho %s\n' "$1" >"$STUBS/uname"; chmod +x "$STUBS/uname"; }

@test "fish: APP_CONFIGS_SSH_KEYS is passed as data, not executed as fish code" {
    command -v fish >/dev/null || skip "fish not installed"
    chezmoi_manages no
    clean_home
    APP_CONFIGS_SSH_KEYS="a; touch $BATS_TEST_TMPDIR/pwned" setup_run /usr/bin/fish
    [ "$status" -eq 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
}

@test "fish: multiple keys become a universal list" {
    command -v fish >/dev/null || skip "fish not installed"
    chezmoi_manages no
    clean_home
    APP_CONFIGS_SSH_KEYS="id_a  id_b" setup_run /usr/bin/fish
    [ "$status" -eq 0 ]
    run env -u XDG_CONFIG_HOME fish -c 'count $APP_CONFIGS_SSH_KEYS; echo $APP_CONFIGS_SSH_KEYS[2]'
    [ "${lines[0]}" = "2" ]
    [ "${lines[1]}" = "id_b" ]
}

@test "fish: a failing fish is reported, not swallowed" {
    chezmoi_manages no
    clean_home
    printf '#!/bin/sh\nexit 1\n' >"$STUBS/fish"; chmod +x "$STUBS/fish"
    APP_CONFIGS_SSH_KEYS="id_a" setup_run /usr/bin/fish
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "--remove keeps a chezmoi-managed loader when the rc is unmanaged" {
    printf '#!/bin/sh\ncase "$2" in *ssh-agent.sh) exit 0;; esac\nexit 1\n' >"$STUBS/chezmoi"
    chmod +x "$STUBS/chezmoi"
    setup_run /bin/zsh
    [ "$status" -eq 0 ]
    grep -qF "$BEGIN_M" "$HOME/.zshrc"
    setup_run /bin/zsh --remove
    [ "$status" -eq 0 ]
    run grep -qF "$BEGIN_M" "$HOME/.zshrc"
    [ "$status" -eq 1 ]
    [ "$(cat "$HOME/.config/app-configs/ssh-agent.sh")" = "# managed loader" ]
}

@test "--remove deletes the loader and fish snippet the installer created" {
    chezmoi_manages no
    clean_home
    setup_run /bin/zsh
    [ -f "$HOME/.config/app-configs/ssh-agent.sh" ]
    setup_run /usr/bin/fish
    [ -f "$HOME/.config/fish/conf.d/ssh-agent.fish" ]
    setup_run /bin/zsh --remove
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/app-configs/ssh-agent.sh" ]
    [ ! -e "$HOME/.config/fish/conf.d/ssh-agent.fish" ]
}

@test "--remove keeps an unmanaged loader or fish snippet the user wrote" {
    chezmoi_manages no
    # setup() seeded user-written content that differs from the repo snippets
    setup_run /bin/zsh --remove
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/app-configs/ssh-agent.sh")" = "# managed loader" ]
    [ "$(cat "$HOME/.config/fish/conf.d/ssh-agent.fish")" = "# managed fish snippet" ]
}

@test "rc source line uses \$HOME, not an absolute home path" {
    chezmoi_manages no
    clean_home
    setup_run /bin/zsh
    [ "$status" -eq 0 ]
    grep -qF '. "$HOME/.config/app-configs/ssh-agent.sh"' "$HOME/.zshrc"
    run grep -qF "$HOME" "$HOME/.zshrc"
    [ "$status" -eq 1 ]
}

@test "macOS: IgnoreUnknown precedes UseKeychain inside a managed block" {
    chezmoi_manages no
    stub_uname Darwin
    clean_home
    setup_run /bin/zsh
    [ "$status" -eq 0 ]
    cfg="$HOME/.ssh/config"
    iu="$(grep -n 'IgnoreUnknown UseKeychain' "$cfg" | cut -d: -f1)"
    uk="$(grep -n '^ *UseKeychain yes' "$cfg" | cut -d: -f1)"
    [ -n "$iu" ] && [ -n "$uk" ] && [ "$iu" -lt "$uk" ]
    [ "$(stat -c %a "$cfg")" = "600" ]
    # re-run is idempotent: still one block
    setup_run /bin/zsh
    [ "$(grep -cF "$BEGIN_M" "$cfg")" = 1 ]
}

@test "macOS: a user UseKeychain line elsewhere does not suppress the managed block" {
    chezmoi_manages no
    stub_uname Darwin
    clean_home
    mkdir -p "$HOME/.ssh"
    printf 'Host x\n    UseKeychain yes\n' >"$HOME/.ssh/config"
    setup_run /bin/zsh
    [ "$status" -eq 0 ]
    grep -qF "$BEGIN_M" "$HOME/.ssh/config"
    head -n 2 "$HOME/.ssh/config" | grep -q 'UseKeychain yes'
}

@test "macOS: --remove strips only the managed block and keeps the file mode" {
    chezmoi_manages no
    stub_uname Darwin
    clean_home
    mkdir -p "$HOME/.ssh"
    printf 'Host x\n    User me\n' >"$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    setup_run /bin/zsh
    setup_run /bin/zsh --remove
    [ "$status" -eq 0 ]
    [ "$(stat -c %a "$HOME/.ssh/config")" = "600" ]
    [ "$(sed '/^$/d' "$HOME/.ssh/config")" = "$(printf 'Host x\n    User me')" ]
}

@test "macOS: an existing config's mode is not changed by install" {
    chezmoi_manages no
    stub_uname Darwin
    clean_home
    mkdir -p "$HOME/.ssh"
    printf 'Host x\n' >"$HOME/.ssh/config"
    chmod 640 "$HOME/.ssh/config"
    setup_run /bin/zsh
    [ "$(stat -c %a "$HOME/.ssh/config")" = "640" ]
}

@test "rc: a missing end marker aborts and leaves the file untouched" {
    chezmoi_manages no
    printf 'before\n%s\nexport A=1\nafter-the-block\n' "$BEGIN_M" >"$HOME/.zshrc"
    cp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/orig"
    setup_run /bin/zsh --remove
    [ "$status" -ne 0 ]
    cmp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/orig"
    setup_run /bin/zsh
    [ "$status" -ne 0 ]
    cmp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/orig"
}

@test "rc: duplicate, nested and stray-end markers abort without changes" {
    chezmoi_manages no
    local cases=(
        "$BEGIN_M|$END_M|$BEGIN_M|$END_M"
        "$BEGIN_M|$BEGIN_M|$END_M|$END_M"
        "keep|$END_M|keep2"
    )
    local c
    for c in "${cases[@]}"; do
        printf '%s\n' "${c//|/$'\n'}" >"$HOME/.zshrc"
        cp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/orig"
        setup_run /bin/zsh --remove
        [ "$status" -ne 0 ] || { echo "accepted: $c"; return 1; }
        cmp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/orig"
    done
}

@test "macOS: a broken marker pair in ~/.ssh/config aborts without changes" {
    chezmoi_manages no
    stub_uname Darwin
    mkdir -p "$HOME/.ssh"
    printf 'Host x\n%s\nHost *\n    User me\n' "$BEGIN_M" >"$HOME/.ssh/config"
    cp "$HOME/.ssh/config" "$BATS_TEST_TMPDIR/orig"
    setup_run /bin/zsh --remove
    [ "$status" -ne 0 ]
    cmp "$HOME/.ssh/config" "$BATS_TEST_TMPDIR/orig"
}

@test "unknown arguments are rejected and change nothing" {
    chezmoi_manages no
    clean_home
    setup_run /bin/zsh --remvoe
    [ "$status" -eq 2 ]
    [ ! -e "$HOME/.zshrc" ]
    setup_run /bin/zsh --remove extra
    [ "$status" -eq 2 ]
}
