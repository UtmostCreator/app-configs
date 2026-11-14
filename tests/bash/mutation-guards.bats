#!/usr/bin/env bats
# The bats guard of every mutating ops script: under bats an apply run must
# stay inside the test's scratch directory. HOME alone is not enough: a test
# that points HOME at scratch but runs the real repository's script would
# still mutate that repository (and its host).
#
# The scripts run from a copy of ops/ that lives OUTSIDE $BATS_TEST_TMPDIR, so
# if a guard were missing the run could only reach PATH stubs, never the
# developer's repository.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    export CALLS="$BATS_TEST_TMPDIR/calls"; : >"$CALLS"
    export NIX_PATH_REFRESH=0

    OUTSIDE="${BATS_RUN_TMPDIR:-/tmp}/outside-repo-$$-$BATS_TEST_NUMBER"
    mkdir -p "$OUTSIDE/nix/vars" "$OUTSIDE/home/.chezmoidata"
    : >"$OUTSIDE/home/.chezmoidata/personal.yaml"
    cp -a "$REPO_ROOT/ops" "$OUTSIDE/ops"
    cp "$REPO_ROOT/nix/vars/default.nix" "$OUTSIDE/nix/vars/"

    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    for tool in nix nix-collect-garbage mise npm chezmoi home-manager lefthook \
        nixos-rebuild sudo curl darwin-rebuild; do
        printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >> "$CALLS"\nexit 0\n' "$tool" >"$STUBS/$tool"
        chmod +x "$STUBS/$tool"
    done
    # The login-user preflight asks `nix eval --raw -f <file> username`; answer
    # it from the file (read-only, not recorded as a call).
    cat >"$STUBS/nix" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == eval ]]; then
    sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$4"; exit 0
fi
printf 'nix %s\n' "$*" >> "$CALLS"
exit 0
STUB
    chmod +x "$STUBS/nix"
    NIX_USER="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    export USER="$NIX_USER"
}

teardown() { rm -rf "$OUTSIDE"; }

refused() {
    [ "$status" -eq 3 ]
    [[ "$output" == *"from a bats test"* ]]
    [ ! -s "$CALLS" ]
}

@test "install.sh refuses a real run when the repo is outside the test dir" {
    run env -u DRY_RUN PATH="$STUBS:$PATH" bash "$OUTSIDE/ops/install.sh"
    refused
}

@test "install.sh --dry-run is still allowed from an outside repo" {
    run env PATH="$STUBS:$PATH" HOST_PROFILE=linux-desktop bash "$OUTSIDE/ops/install.sh" --dry-run
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh --yes refuses an outside repo" {
    run env PATH="$STUBS:$PATH" HOST_PROFILE=linux-desktop bash "$OUTSIDE/ops/bootstrap.sh" --yes
    refused
}

@test "cleanup.sh --apply refuses a HOME outside the test dir" {
    # cleanup never writes the repository; what it mutates hangs off HOME.
    mkdir -p "$OUTSIDE/home"
    run env HOME="$OUTSIDE/home" PATH="$STUBS:$PATH" bash "$REPO_ROOT/ops/cleanup.sh" --apply --yes
    refused
}

@test "cleanup.sh without --apply is a report and still runs" {
    run env PATH="$STUBS:$PATH" bash "$OUTSIDE/ops/cleanup.sh"
    [[ "$output" != *"from a bats test"* ]]
}

@test "uninstall.sh --apply refuses an outside repo" {
    run env PATH="$STUBS:$PATH" bash "$OUTSIDE/ops/uninstall.sh" --apply --yes
    refused
}

@test "system-setup.sh --apply refuses an outside repo" {
    run env PATH="$STUBS:$PATH" bash "$OUTSIDE/ops/system-setup.sh" --apply
    refused
}

@test "a real HOME is refused even when the repo copy is inside the test dir" {
    mkdir -p "$BATS_TEST_TMPDIR/inside"
    cp -a "$REPO_ROOT/ops" "$BATS_TEST_TMPDIR/inside/ops"
    run env PATH="$STUBS:$PATH" HOME="$OUTSIDE" bash "$BATS_TEST_TMPDIR/inside/ops/cleanup.sh" --apply --yes
    refused
}
