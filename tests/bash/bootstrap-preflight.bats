#!/usr/bin/env bats
# ops/bootstrap.sh shares install.sh's preflight (ops/lib/preflight.sh): WSL1
# refusal, login-user check, personal.yaml seeding. And a dry run must not
# write chezmoi state or hide why a preview failed.
#
# Apply-mode runs use a scratch copy of the repo, a scratch HOME and PATH
# stubs for every tool, so nothing real is installed or switched.

# `! cmd` in the middle of a bats test does not fail it (set -e ignores a
# negated command), so assert absence explicitly.
refute_grep() { if grep -q "$@"; then echo "unexpected match: $*" >&2; return 1; fi; }

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    export CALLS="$BATS_TEST_TMPDIR/calls"; : >"$CALLS"
    export NIX_PATH_REFRESH=0
    NIX_USER="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    export USER="$NIX_USER"

    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    for tool in nix chezmoi mise home-manager lefthook curl darwin-rebuild; do
        cat >"$STUBS/$tool" <<STUB
#!/usr/bin/env bash
printf '%s %s\n' "$tool" "\$*" >> "\$CALLS"
if [[ "$tool" == chezmoi && "\${1:-}" == diff && "\${FAIL_DIFF:-0}" == 1 ]]; then
    echo "chezmoi: template error" >&2; exit 1
fi
exit 0
STUB
        chmod +x "$STUBS/$tool"
    done

    # A scratch repo copy with every helper stubbed, for apply-mode runs.
    FAKE="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FAKE/nix/vars" "$FAKE/home/.chezmoidata" "$FAKE/.git"
    cp -a "$REPO_ROOT/ops" "$FAKE/ops"
    cp "$REPO_ROOT/nix/vars/default.nix" "$FAKE/nix/vars/"
    : >"$FAKE/home/.chezmoidata/personal.yaml"
    for helper in snapshot-home.sh doctor.sh vscode-extensions.sh unix/ssh-agent-setup.sh; do
        printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE/ops/$helper"
    done
}

dry_run() { run env PATH="$STUBS:$PATH" HOST_PROFILE="${HOST_PROFILE:-linux-desktop}" bash "$REPO_ROOT/ops/bootstrap.sh" --dry-run; }
apply() { run env PATH="$STUBS:$PATH" HOST_PROFILE=linux-desktop bash "$FAKE/ops/bootstrap.sh" --yes; }

@test "a dry run never runs chezmoi init (it writes ~/.config/chezmoi)" {
    dry_run
    [ "$status" -eq 0 ]
    refute_grep '^chezmoi init' "$CALLS"
    [[ "$output" == *"would: chezmoi init"* ]]
}

@test "WSL1 is refused with the conversion command, before anything else" {
    printf 'Linux version 4.4.0-19041-Microsoft (Microsoft@Microsoft.com)\n' >"$BATS_TEST_TMPDIR/version"
    run env PATH="$STUBS:$PATH" HOST_PROFILE=wsl DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/version" \
        bash "$REPO_ROOT/ops/bootstrap.sh" --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"WSL1"* ]]
    [[ "$output" == *"wsl --set-version"* ]]
    [ ! -s "$CALLS" ]
}

@test "a login user that does not match the nix username is refused" {
    run env PATH="$STUBS:$PATH" USER=someone-else HOST_PROFILE=linux-desktop \
        bash "$REPO_ROOT/ops/bootstrap.sh" --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"someone-else"* ]]
    [[ "$output" == *"nix/vars/default.nix"* ]]
    [ ! -s "$CALLS" ]
}

@test "a dry run on a copy without personal.yaml names the seeding and writes nothing" {
    rm "$FAKE/home/.chezmoidata/personal.yaml"
    cp "$REPO_ROOT/home/personal.yaml.example" "$FAKE/home/"
    run env PATH="$STUBS:$PATH" HOST_PROFILE=linux-desktop bash "$FAKE/ops/bootstrap.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"seed-personal-yaml.sh"*"personal.yaml linux-desktop"* ]]
    [ ! -e "$FAKE/home/.chezmoidata/personal.yaml" ]
}

@test "an apply run seeds a missing personal.yaml" {
    rm "$FAKE/home/.chezmoidata/personal.yaml"
    cp "$REPO_ROOT/home/personal.yaml.example" "$FAKE/home/"
    apply
    [ "$status" -eq 0 ]
    [ -f "$FAKE/home/.chezmoidata/personal.yaml" ]
}

@test "apply initialises chezmoi and a failing diff stops before anything is applied" {
    FAIL_DIFF=1 apply
    [ "$status" -ne 0 ]
    grep -q "^chezmoi init --source=$FAKE" "$CALLS"
    refute_grep '^chezmoi apply' "$CALLS"
    refute_grep '^home-manager' "$CALLS"
}

@test "apply switches Home Manager with -b hm-bak" {
    apply
    [ "$status" -eq 0 ]
    grep -qx "home-manager switch -b hm-bak --flake $FAKE/nix#linux-desktop" "$CALLS"
}

@test "the dry-run preview of the switch carries -b hm-bak too" {
    dry_run
    [[ "$output" == *"home-manager switch -b hm-bak --flake $REPO_ROOT/nix#linux-desktop"* ]]
}
