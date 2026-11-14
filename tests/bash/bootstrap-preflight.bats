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
    # A caller's NIX_CONFIG (ops/ci-local.sh exports one) would enable
    # nix-command in the stub and hide whether the lib exports it itself.
    unset NIX_CONFIG
    NIX_USER="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    export USER="$NIX_USER"

    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    for tool in nix chezmoi mise home-manager lefthook curl darwin-rebuild; do
        cat >"$STUBS/$tool" <<STUB
#!/usr/bin/env bash
# The login-user preflight reads the username with \`nix eval --raw -f <file> username\`
# after \`nix show-config\` (both read-only, so they are answered here and not
# recorded as calls). Like a real Nix, eval needs nix-command: from
# NIX_STUB_FEATURES (what show-config reports, default both) or NIX_CONFIG.
if [[ "$tool" == nix && "\${1:-}" == show-config ]]; then
    printf 'experimental-features = %s\\n' "\${NIX_STUB_FEATURES-nix-command flakes}"; exit 0
fi
if [[ "$tool" == nix && "\${1:-}" == eval ]]; then
    case "\${NIX_STUB_FEATURES-nix-command flakes} \${NIX_CONFIG:-}" in
        *nix-command*) ;;
        *) echo "error: experimental Nix feature 'nix-command' is disabled" >&2; exit 1 ;;
    esac
    sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\\1/p' "\$4"; exit 0
fi
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

@test "bootstrap enables nix-command for its username eval on a Nix that lacks it" {
    # show-config reports no features and eval refuses without nix-command, as a
    # real Nix does. Bootstrap must turn the features on for this run (not
    # edit nix.conf) before it asks for the username.
    run env PATH="$STUBS:$PATH" NIX_STUB_FEATURES="" HOST_PROFILE=linux-desktop \
        bash "$REPO_ROOT/ops/bootstrap.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"nix-command and flakes are not both enabled"* ]]
    [[ "$output" != *"nix eval failed"* ]]
}

# ── no Nix yet (fresh machine): the sed fallback of the login-user check ─────

# nonix_path: a PATH of symlinks to basic tools only, never a real nix.
nonix_path() {
    NONIX="$BATS_TEST_TMPDIR/nonix"; mkdir -p "$NONIX"
    local t p
    for t in bash env git curl sed awk cat dirname head tail find xargs stat sort grep \
        uname mkdir tee tr rm cp chmod ls readlink basename sleep date wc cut id mktemp ln; do
        p="$(command -v "$t" 2>/dev/null)" || continue
        ln -sf "$p" "$NONIX/$t"
    done
    ! PATH="$NONIX" command -v nix >/dev/null 2>&1 || { echo "nix leaked into the test PATH" >&2; return 1; }
}

# host_checks <mode-args...>: call the shared preflight with the real repo and
# a mismatched login user, under the no-nix PATH.
host_checks() {
    nonix_path
    run env PATH="$NONIX" USER=someone-else REPO="$REPO_ROOT" "$NONIX/bash" -c '
        fail() { printf "FAIL: %s\n" "$*" >&2; exit 1; }
        warn() { printf "WARN: %s\n" "$*" >&2; }
        source "$REPO/ops/lib/preflight.sh"
        preflight_host_checks "$REPO" linux-desktop "$@"
        echo "returned 0"' _ "$@"
}

@test "without nix, bootstrap refuses a login user that does not match the nix username" {
    nonix_path
    run env PATH="$NONIX" USER=someone-else HOST_PROFILE=linux-desktop \
        bash "$REPO_ROOT/ops/bootstrap.sh" --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"login user 'someone-else' does not match username '$NIX_USER'"* ]]
    [[ "$output" != *"would: nix profile install"* ]]
}

@test "without nix, the default mode of preflight_host_checks fails on a user mismatch" {
    host_checks
    [ "$status" -ne 0 ]
    [[ "$output" == *"FAIL: login user 'someone-else' does not match username '$NIX_USER'"* ]]
    [[ "$output" != *"returned 0"* ]]
}

@test "without nix, fail mode fails and warn mode only warns" {
    host_checks fail
    [ "$status" -ne 0 ]
    [[ "$output" == *"FAIL: login user 'someone-else' does not match"* ]]
    host_checks warn
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN: login user 'someone-else' differs from username '$NIX_USER'"* ]]
    [[ "$output" == *"returned 0"* ]]
    [[ "$output" != *"FAIL:"* ]]
}

@test "without nix, a matching login user passes silently in both modes" {
    nonix_path
    for mode in fail warn; do
        run env PATH="$NONIX" USER="$NIX_USER" REPO="$REPO_ROOT" "$NONIX/bash" -c '
            fail() { printf "FAIL: %s\n" "$*" >&2; exit 1; }
            warn() { printf "WARN: %s\n" "$*" >&2; }
            source "$REPO/ops/lib/preflight.sh"
            preflight_host_checks "$REPO" linux-desktop "$1"; echo returned 0' _ "$mode"
        [ "$status" -eq 0 ]
        [[ "$output" == "returned 0" ]]
    done
}

@test "an unexpected preflight_host_checks mode fails closed, before any check" {
    host_checks warm
    [ "$status" -ne 0 ]
    [[ "$output" == *"FAIL: preflight_host_checks: unknown mode 'warm'"* ]]
    # Also with a matching user: a typo in MODE is a caller bug, not a pass.
    nonix_path
    run env PATH="$NONIX" USER="$NIX_USER" REPO="$REPO_ROOT" "$NONIX/bash" -c '
        fail() { printf "FAIL: %s\n" "$*" >&2; exit 1; }
        warn() { :; }
        source "$REPO/ops/lib/preflight.sh"
        preflight_host_checks "$REPO" linux-desktop warm; echo returned 0'
    [ "$status" -ne 0 ]
    [[ "$output" != *"returned 0"* ]]
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
