#!/usr/bin/env bats
# ops/install.sh preflight: stop early when the login user does not match the
# Nix username, instead of failing deep inside home-manager switch.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # Never let install.sh see the real HOME, even if DRY_RUN were lost.
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    # Isolate from the host: no inherited WSL env or WSL filesystem markers.
    unset WSL_DISTRO_NAME
    export DETECT_HOST_WSL_RUN="$BATS_TEST_TMPDIR/no-wsl-run" DETECT_HOST_WSL_INTEROP="$BATS_TEST_TMPDIR/no-wsl-interop"
}

@test "mismatched user fails before anything is installed" {
    run env USER=someone-else DRY_RUN=1 HOST_PROFILE=wsl bash "$REPO_ROOT/ops/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"someone-else"* ]]
    [[ "$output" == *"nix/vars/default.nix"* ]]
    [[ "$output" != *"── Nix ──"* ]]
}

@test "matching user passes the username check" {
    expected="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    run env USER="$expected" DRY_RUN=1 HOST_PROFILE=wsl bash "$REPO_ROOT/ops/install.sh"
    # A crash would also print no "does not match": require a real dry run.
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:  dry-run"* ]]
    [[ "$output" != *"does not match"* ]]
}

@test "WSL1 kernel is refused with the conversion command" {
    printf 'Linux version 4.4.0-19041-Microsoft (Microsoft@Microsoft.com) (gcc version 5.4.0) #1237-Microsoft\n' \
        >"$BATS_TEST_TMPDIR/version"
    expected="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    run env USER="$expected" DRY_RUN=1 HOST_PROFILE=wsl \
        DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/version" DETECT_HOST_OSRELEASE="$BATS_TEST_TMPDIR/no-osrelease" bash "$REPO_ROOT/ops/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"WSL1"* ]]
    [[ "$output" == *"wsl --set-version"* ]]
    [[ "$output" != *"── Nix ──"* ]]
}

@test "WSL2 kernel passes the WSL version check" {
    printf 'Linux version 6.6.87.2-microsoft-standard-WSL2 (root@host) #1 SMP\n' >"$BATS_TEST_TMPDIR/version"
    expected="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    run env USER="$expected" DRY_RUN=1 HOST_PROFILE=wsl \
        DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/version" DETECT_HOST_OSRELEASE="$BATS_TEST_TMPDIR/no-osrelease" bash "$REPO_ROOT/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:  dry-run"* ]]
    [[ "$output" != *"WSL1"* ]]
}

@test "--dry-run is honoured (sys-install passes its args through)" {
    expected="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    run env -u DRY_RUN USER="$expected" HOST_PROFILE=wsl bash "$REPO_ROOT/ops/install.sh" --dry-run
    [[ "$output" == *"Mode:  dry-run"* ]]
    [[ "$output" == *"[install:dry-run] would run"* ]]
}

@test "--help prints usage and changes nothing" {
    run bash "$REPO_ROOT/ops/install.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" != *"Preflight"* ]]
}

@test "unknown arguments stop before anything runs" {
    run bash "$REPO_ROOT/ops/install.sh" --apply
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown argument: --apply"* ]]
    [[ "$output" != *"Preflight"* ]]
}

@test "under bats a real install against the real HOME is refused" {
    # A HOME outside this test's scratch dir stands in for the real one
    # (run-bats.sh gives the whole suite a scratch HOME).
    outside="${BATS_RUN_TMPDIR:-/tmp}/outside-home-$$"
    run env -u DRY_RUN HOME="$outside" bash "$REPO_ROOT/ops/install.sh"
    [ "$status" -eq 3 ]
    [ ! -e "$outside" ]   # nothing was created there
    [[ "$output" == *"refusing a real install from a bats test"* ]]
    [[ "$output" != *"Preflight"* ]]
}

# ── username diagnostic and lefthook quoting ────────────────────────────────
# These run install.sh from a scratch repo copy. Every tool it calls is a PATH
# stub and every ops/ helper is a stub script, so nothing real is installed.

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$1"
    chmod +x "$1"
}

# make_repo <dir-name> [username]: scratch repo under the test tmpdir.
make_repo() {
    [ ! -x /nix/var/nix/profiles/default/bin/nix ] \
        || skip "a system Nix default profile would shadow the nix stub"
    FAKE="$BATS_TEST_TMPDIR/$1"
    STUBS="$BATS_TEST_TMPDIR/bin"
    LOG="$BATS_TEST_TMPDIR/lefthook.log"
    mkdir -p "$FAKE/ops" "$FAKE/nix/vars" "$FAKE/home/.chezmoidata" "$FAKE/.git" "$STUBS"
    cp "$REPO_ROOT/ops/install.sh" "$FAKE/ops/install.sh"
    cp -R "$REPO_ROOT/ops/lib" "$FAKE/ops/lib"
    printf '{\n  username = "%s";\n}\n' "${2:-utmostcreator}" >"$FAKE/nix/vars/default.nix"
    : >"$FAKE/home/.chezmoidata/personal.yaml"
    for tool in nix chezmoi home-manager mise; do stub "$STUBS/$tool" 'exit 0'; done
    stub "$STUBS/lefthook" "printf 'argv=%s cwd=%s\n' \"\$*\" \"\$PWD\" >>'$LOG'"
    for s in snapshot-home doctor; do stub "$FAKE/ops/$s.sh" 'exit 0'; done
    stub "$FAKE/ops/detect-timezone.sh" 'echo Europe/London'
}

@test "username mismatch message names the value from nix/vars/default.nix" {
    make_repo repo zed-user
    run env USER=someone-else DRY_RUN=1 HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"login user 'someone-else' does not match username 'zed-user' in nix/vars/default.nix"* ]]
    [[ "$output" == *"Log in as 'zed-user'"* ]]
    [[ "$output" != *"utmostcreator"* ]]
}

@test "lefthook install runs once in a repo path with spaces and an apostrophe" {
    make_repo "it's a repo"
    run env USER=utmostcreator PATH="$STUBS:$PATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    echo "$output"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$LOG")" -eq 1 ]
    [ "$(cat "$LOG")" = "argv=install cwd=$FAKE" ]
}

@test "a crafted repo path cannot inject commands into the lefthook step" {
    mkdir -p "$BATS_TEST_TMPDIR/work"
    make_repo "x';touch pwned-marker;'"
    cd "$BATS_TEST_TMPDIR/work"
    run env USER=utmostcreator PATH="$STUBS:$PATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    echo "$output"
    [ "$status" -eq 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/work/pwned-marker" ]
    [ "$(cat "$LOG")" = "argv=install cwd=$FAKE" ]
}

@test "dry-run does not invoke lefthook" {
    make_repo repo
    run env USER=utmostcreator DRY_RUN=1 PATH="$STUBS:$PATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: sh -c"*"lefthook install"* ]]
    [ ! -e "$LOG" ]
}

# ── DRY_RUN validation and the bats HOME guard ──────────────────────────────

@test "DRY_RUN other than 0 or 1 is rejected before anything runs" {
    make_repo repo
    run env USER=utmostcreator DRY_RUN=true PATH="$STUBS:$PATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"[install:error] DRY_RUN must be 0 or 1 (got: true)"* ]]
    [[ "$output" != *"Preflight"* ]]
    [ ! -e "$LOG" ]
}

@test "DRY_RUN=0 plus --dry-run is still a dry run" {
    make_repo repo
    run env USER=utmostcreator DRY_RUN=0 PATH="$STUBS:$PATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:  dry-run"* ]]
    [ ! -e "$LOG" ]
}

@test "the bats HOME guard rejects a sibling that only shares the scratch prefix" {
    make_repo repo
    outside="${BATS_TEST_TMPDIR}-evil"
    run env -u DRY_RUN HOME="$outside" USER=utmostcreator PATH="$STUBS:$PATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 3 ]
    [ ! -e "$outside" ]
    [ ! -e "$LOG" ]
    [[ "$output" == *"refusing a real install from a bats test"* ]]
}
