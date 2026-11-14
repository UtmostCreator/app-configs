#!/usr/bin/env bats
# ops/install.sh: a failing VS Code extension install (ops/vscode-extensions.sh
# runs under set -e and stops at the first bad extension) must only warn, so
# lefthook and doctor still run.
#
# install.sh runs in apply mode against a scratch repo copy. Every tool it
# calls (nix, chezmoi, home-manager, mise, lefthook) is a PATH stub and every
# ops/ helper it calls is a stub script, so nothing real is installed.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # install.sh prepends the Nix default profile to PATH (and sources its
    # profile scripts); a real nix there would shadow the stub and run against
    # the scratch repo. NIX_PATH_REFRESH=0 turns that off for the test, so it
    # runs on hosts that do have a system Nix (CI runners always do).
    export NIX_PATH_REFRESH=0

    FAKE="$BATS_TEST_TMPDIR/repo"
    STUBS="$BATS_TEST_TMPDIR/bin"
    export HOME="$BATS_TEST_TMPDIR/home"
    MARKS="$BATS_TEST_TMPDIR/marks"
    mkdir -p "$FAKE/ops" "$FAKE/nix/vars" "$FAKE/home/.chezmoidata" \
        "$FAKE/.git" "$STUBS" "$HOME" "$MARKS"

    cp "$REPO_ROOT/ops/install.sh" "$FAKE/ops/install.sh"
    cp -a "$REPO_ROOT/ops/lib" "$FAKE/ops/lib"
    cp "$REPO_ROOT/nix/vars/default.nix" "$FAKE/nix/vars/default.nix"
    : >"$FAKE/home/.chezmoidata/personal.yaml"
    NIX_USER="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$FAKE/nix/vars/default.nix")"

    for tool in nix chezmoi home-manager mise; do
        stub "$STUBS/$tool" 'exit 0'
    done
    stub "$STUBS/lefthook" "touch '$MARKS/lefthook'"
    stub "$FAKE/ops/snapshot-home.sh" 'exit 0'
    stub "$FAKE/ops/doctor.sh" "touch '$MARKS/doctor'"
    stub "$FAKE/ops/detect-timezone.sh" 'echo Europe/London'
    stub "$FAKE/ops/vscode-extensions.sh" 'echo "extension install failed" >&2; exit 1'
}

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$1"
    chmod +x "$1"
}

@test "a failed VS Code extension install warns and the install continues" {
    run env USER="$NIX_USER" HOME="$HOME" PATH="$STUBS:$PATH" \
        HOST_PROFILE=linux-desktop bash "$FAKE/ops/install.sh"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[install:warn]"*"VS Code extension"* ]]
    [ -f "$MARKS/lefthook" ]
    [ -f "$MARKS/doctor" ]
}
