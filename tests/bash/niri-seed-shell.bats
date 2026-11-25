#!/usr/bin/env bats

setup() {
    [[ $EUID -ne 0 ]] || skip 'shell seeding requires an ordinary account'
    repo=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
    seed="$repo/nix/hosts/linux-niri/scripts/seed-shell.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -m 700 "$HOME"
    mkdir -m 700 "$BATS_TEST_TMPDIR/kit" "$BATS_TEST_TMPDIR/bin"
    bundle="$BATS_TEST_TMPDIR/kit/install.bundle"
    # The tests run without root. Model the two installation-owned objects;
    # all other tools and filesystem operations use the real fixture.
    export TRUSTED_KIT="$BATS_TEST_TMPDIR/kit" REAL_STAT
    REAL_STAT=$(command -v stat)
    cat > "$BATS_TEST_TMPDIR/bin/stat" <<'STUB'
#!/usr/bin/env bash
if [[ $1 == -c && $2 == '%u %a' && $3 == -- && ( $4 == "$TRUSTED_KIT" || $4 == "$TRUSTED_KIT/install.bundle" ) ]]; then
    printf '%s 700\n' "${KIT_OWNER:-0}"
else
    exec "$REAL_STAT" "$@"
fi
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/stat"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    fixture="$BATS_TEST_TMPDIR/source"
    git -c init.defaultBranch=main init -q "$fixture"
    inputs=(home/dot_bashrc.tmpl home/dot_config/app-configs/ssh-agent.sh home/dot_config/fish/conf.d/ssh-agent.fish)
    for source in "${inputs[@]}"; do
        mkdir -p "$fixture/${source%/*}"
        cp "$repo/$source" "$fixture/$source"
    done
    git -C "$fixture" add home
    git -C "$fixture" -c user.name=Fixture -c user.email=fixture@localhost commit -qm baseline
    git -C "$fixture" bundle create "$bundle" refs/heads/main
    revision=$(git -C "$fixture" rev-parse HEAD)
}

@test "old installation kit with HEAD-only ref is accepted" {
    git -C "$fixture" bundle create "$bundle" HEAD
    run bash "$seed" "$bundle" "$revision"
    echo "$output"
    [ "$status" -eq 0 ]
    [ -s "$HOME/.bashrc" ]
}

@test "user-controlled bundle cannot supply shell startup code" {
    run env KIT_OWNER=1000 bash "$seed" "$bundle" "$revision"
    [ "$status" -ne 0 ]
    [[ "$output" == *"must be root-owned"* ]]
    [ ! -e "$HOME/.config" ]
}

@test "fresh home receives canonical shell loaders and re-run preserves edits" {
    run bash "$seed" "$bundle" "$revision"
    echo "$output"
    [ "$status" -eq 0 ]
    cmp "$fixture/home/dot_config/fish/conf.d/ssh-agent.fish" "$HOME/.config/fish/conf.d/ssh-agent.fish"
    cmp "$fixture/home/dot_config/app-configs/ssh-agent.sh" "$HOME/.config/app-configs/ssh-agent.sh"
    bash -n "$HOME/.bashrc"
    grep -q 'exec fish' "$HOME/.bashrc"
    [ ! -e "$HOME/.config/fish/config.fish" ]
    [ ! -e "$HOME/.ssh" ]
    printf 'keep\n' > "$HOME/.bashrc"
    run bash "$seed" "$bundle" "$revision"
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.bashrc")" = keep ]
    [ "$(stat -c %a "$HOME/.config/app-configs/ssh-agent.sh")" = 600 ]
}

@test "wrong revision cannot partially seed the home" {
    run bash "$seed" "$bundle" 0000000000000000000000000000000000000000
    [ "$status" -ne 0 ]
    [ ! -e "$HOME/.config" ]
    [ ! -e "$HOME/.bashrc" ]
}

@test "missing source in an older bundle is visible before publishing files" {
    git -C "$fixture" rm -q "${inputs[0]}"
    git -C "$fixture" -c user.name=Fixture -c user.email=fixture@localhost commit -qm incomplete
    git -C "$fixture" bundle create "$bundle" refs/heads/main
    revision=$(git -C "$fixture" rev-parse HEAD)
    run bash "$seed" "$bundle" "$revision"
    [ "$status" -ne 0 ]
    [[ "$output" == *"lacks a required shell source"* ]]
    [ ! -e "$HOME/.config" ]
}

@test "shell configuration parent symlink prevents all writes" {
    mkdir "$BATS_TEST_TMPDIR/other"
    mkdir "$HOME/.config"
    ln -s "$BATS_TEST_TMPDIR/other" "$HOME/.config/fish"
    run bash "$seed" "$bundle" "$revision"
    [ "$status" -ne 0 ]
    [ ! -e "$HOME/.bashrc" ]
    [ ! -e "$HOME/.config/app-configs" ]
    [ ! -e "$BATS_TEST_TMPDIR/other/conf.d" ]
}

@test "existing shell loader symlinks are left to their owner" {
    ln -s "$BATS_TEST_TMPDIR/never-create" "$HOME/.bashrc"
    run bash "$seed" "$bundle" "$revision"
    [ "$status" -eq 0 ]
    [ -L "$HOME/.bashrc" ]
    [ ! -e "$BATS_TEST_TMPDIR/never-create" ]
}
