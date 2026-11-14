#!/usr/bin/env bats
# One owner per file (bug type 4, "writes to chezmoi-managed files / double
# ownership"). A script that rewrites a chezmoi-managed file makes sys-update
# refuse to run and the next `chezmoi apply` undoes the edit; Home Manager and
# chezmoi both writing one path fight on every update.
#
#   1. No script under ops/, scripts/, home/dot_local/bin or
#      nix/modules/home/scripts writes (>, >>, cp, install, mv, ln, tee,
#      sed -i, touch) to a chezmoi-managed path unless a chezmoi_managed /
#      `chezmoi source-path` check precedes the write.
#   2. nix/modules/home xdg.configFile / home.file targets never overlap
#      chezmoi targets.
#
# The managed list comes from the names in home/ (chezmoi source state), see
# tests/lib/find-managed-writes.py for the exact rules and limits: static
# analysis, literal and one-level-variable targets only.

load ../lib/contract

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCAN="$REPO_ROOT/tests/lib/find-managed-writes.py"
    ALLOW="$BATS_TEST_TMPDIR/allow.txt"
    ALLOW_NIX="$BATS_TEST_TMPDIR/allow-nix.txt"
    # file-glob | target-glob | reason. Each entry must still match something
    # (the two main tests run with --check-allow-used).
    cat >"$ALLOW" <<'EOF'
# run-bats.sh exports HOME=<scratch dir> before it writes the test identity,
# so $HOME/.gitconfig is never the user's chezmoi-managed file.
ops/run-bats.sh | .gitconfig | writes into the scratch HOME it just created
EOF
    cat >"$ALLOW_NIX" <<'EOF'
# Home Manager owns flameshot.ini on Linux; chezmoi ignores it there
# (home/.chezmoiignore, checked by the test below).
nix/modules/home/gui.nix | .config/flameshot/flameshot.ini | chezmoiignore excludes it on Linux
EOF
}

writes() { python3 -I "$SCAN" "$1" --allow "$ALLOW" "${@:2}"; }
overlaps() { python3 -I "$SCAN" "$1" --nix-overlap --allow "$ALLOW_NIX" "${@:2}"; }

@test "the managed list is derived from home/ (a wrong list would pass for the wrong reason)" {
    run python3 -I "$SCAN" "$REPO_ROOT" --list-managed
    [ "$status" -eq 0 ]
    for want in .bashrc .zshrc .gitconfig .claude/settings.json .config/fish/conf.d/ws.fish \
        .config/fish/conf.d/ssh-agent.fish .config/starship/starship.toml .local/bin/sys-update; do
        grep -qxF "$want" <<<"$output" || { echo "not managed: $want"; return 1; }
    done
    [[ "$output" != *chezmoi* ]]
    [[ "$output" != *.example* ]]
}

@test "no script writes to a chezmoi-managed path without a chezmoi_managed check" {
    run writes "$REPO_ROOT" --check-allow-used
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "nix xdg.configFile / home.file targets never overlap chezmoi targets" {
    run overlaps "$REPO_ROOT" --check-allow-used
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "the one allowlisted overlap is excluded from chezmoi on Linux" {
    grep -qxF '.config/flameshot' "$REPO_ROOT/home/.chezmoiignore" ||
        { echo "home/.chezmoiignore no longer ignores .config/flameshot"; return 1; }
}

@test "the ssh-agent installer, which checks chezmoi_managed before each write, passes" {
    run python3 -I "$SCAN" "$REPO_ROOT"
    [[ "$output" != *ssh-agent-setup* ]]
    grep -q 'install -m 0644' "$REPO_ROOT/ops/unix/ssh-agent-setup.sh"
}

# -- Seeded violations: the check must notice each of these ------------------

@test "seeded: an unguarded append to ~/.zshrc is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\necho "alias x=y" >> "$HOME/.zshrc"\n' >>"$copy/ops/cleanup.sh"
    run writes "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ops/cleanup.sh:"*".zshrc"* ]]
}

@test "seeded: cp, install and tee onto managed files are caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\ncp a "$HOME/.config/starship/starship.toml"\ninstall -m 0644 a "${XDG_CONFIG_HOME:-$HOME/.config}/atuin/config.toml"\nprintf x | tee ~/.tmux.conf\n' \
        >>"$copy/ops/doctor.sh"
    run writes "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *"-> .config/starship/starship.toml"* ]]
    [[ "$output" == *"-> .config/atuin/config.toml"* ]]
    [[ "$output" == *"-> .tmux.conf"* ]]
}

@test "seeded: a write through a variable and sed -i on a managed file are caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\nRC="$HOME/.bashrc"\nsed -i s/a/b/ "$RC"\nmv x.tmp "$RC"\n' >>"$copy/home/dot_local/bin/executable_rgc"
    run writes "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *"executable_rgc:"*"sed -i -> .bashrc"* ]]
    [[ "$output" == *"executable_rgc:"*"mv -> .bashrc"* ]]
}

@test "seeded: a write guarded by chezmoi_managed is accepted" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\nif ! chezmoi_managed "$HOME/.zshrc"; then\n  echo x >> "$HOME/.zshrc"\nfi\n' >>"$copy/ops/cleanup.sh"
    run writes "$copy"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "seeded: writes to unmanaged files are accepted" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\necho x >> "$HOME/.local/state/mything/log"\ncp a "$HOME/.config/mything/rc"\n' >>"$copy/ops/cleanup.sh"
    run writes "$copy"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "seeded: a Home Manager file on a chezmoi path is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\n  xdg.configFile."starship/starship.toml".text = "x";\n  home.file.".tmux.conf".text = "y";\n' >>"$copy/nix/modules/home/dev.nix"
    run overlaps "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nix writes .config/starship/starship.toml"* ]]
    [[ "$output" == *"nix writes .tmux.conf"* ]]
}
