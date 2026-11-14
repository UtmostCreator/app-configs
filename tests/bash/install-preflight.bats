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
    # install.sh asks Nix for the username; the test never runs the real nix.
    export STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
    stub_nix
    export PATH="$STUBS:$PATH"
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

# stub_tool <name>: logs "<name> cwd=.. nixcfg=[..] args=.." to $STUB_LOG and
# exits with $STUB_FAIL_<NAME> when that is set (dashes become underscores).
stub_tool() {
    local var="STUB_FAIL_$(printf '%s' "$1" | tr 'a-z-' 'A-Z_')"
    stub "$STUBS/$1" "printf '%s cwd=%s nixcfg=[%s] args=%s\n' '$1' \"\$PWD\" \"\${NIX_CONFIG:-}\" \"\$*\" >>\"\$STUB_LOG\"
[ -z \"\${$var:-}\" ] || exit \"\${$var}\"
exit 0"
}

# stub_nix: answers `nix eval --raw -f <file> username` by reading the file,
# `nix show-config` from $NIX_STUB_CONFIG, and fails eval when $NIX_STUB_EVAL_FAIL
# is set. Everything else is logged and succeeds.
stub_nix() {
    stub "$STUBS/nix" "printf 'nix cwd=%s nixcfg=[%s] args=%s\n' \"\$PWD\" \"\${NIX_CONFIG:-}\" \"\$*\" >>\"\$STUB_LOG\"
case \"\$1\" in
  eval)
    [ -z \"\${NIX_STUB_EVAL_FAIL:-}\" ] || exit 1
    [ -z \"\${NIX_STUB_USERNAME:-}\" ] || { printf '%s' \"\$NIX_STUB_USERNAME\"; exit 0; }
    sed -nE 's/^[[:space:]]*username = \"([^\"]+)\";.*/\\1/p' \"\$4\" ;;
  show-config)
    printf '%s\n' \"\${NIX_STUB_CONFIG-experimental-features = nix-command flakes}\" ;;
  profile)
    # \`nix profile install\` makes every <tool>.pending stub appear as <tool>.
    for f in \"\$STUBS\"/*.pending; do [ ! -e \"\$f\" ] || mv \"\$f\" \"\${f%.pending}\"; done ;;
  --version) echo 'nix (stub) 0' ;;
esac
[ -z \"\${STUB_FAIL_NIX:-}\" ] || exit \"\$STUB_FAIL_NIX\"
exit 0"
}

# make_repo <dir-name> [username]: scratch repo under the test tmpdir.
make_repo() {
    [ ! -x /nix/var/nix/profiles/default/bin/nix ] \
        || skip "a system Nix default profile would shadow the nix stub"
    FAKE="$BATS_TEST_TMPDIR/$1"
    LOG="$BATS_TEST_TMPDIR/lefthook.log"
    mkdir -p "$FAKE/ops" "$FAKE/nix/vars" "$FAKE/home/.chezmoidata" "$FAKE/.git" "$STUBS"
    cp "$REPO_ROOT/ops/install.sh" "$FAKE/ops/install.sh"
    cp -R "$REPO_ROOT/ops/lib" "$FAKE/ops/lib"
    printf '{\n  username = "%s";\n}\n' "${2:-utmostcreator}" >"$FAKE/nix/vars/default.nix"
    : >"$FAKE/home/.chezmoidata/personal.yaml"
    for tool in chezmoi home-manager mise; do stub_tool "$tool"; done
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

# ── username comes from nix eval ────────────────────────────────────────────

@test "a failing nix eval of the username is an error, not a skipped check" {
    make_repo repo
    run env USER=utmostcreator NIX_STUB_EVAL_FAIL=1 DRY_RUN=1 HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"[install:error] cannot read username from nix/vars/default.nix"* ]]
    [[ "$output" != *"── Nix ──"* ]]
}

@test "the username is whatever nix eval returns, not a sed match of the file" {
    make_repo repo
    printf '{ username = builtins.head [ "zed-user" ]; }\n' >"$FAKE/nix/vars/default.nix"
    run env USER=someone-else NIX_STUB_USERNAME=zed-user DRY_RUN=1 HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not match username 'zed-user' in nix/vars/default.nix"* ]]
    grep -q 'args=eval --raw -f '"$FAKE"'/nix/vars/default.nix username' "$STUB_LOG"
}

# ── external failures end in [install:error]; the snapshot fails closed ─────

@test "an external command failure is reported as [install:error] with its exit code" {
    make_repo repo
    run env USER=utmostcreator STUB_FAIL_HOME_MANAGER=7 HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 7 ]
    [[ "$output" == *"[install:error] command failed (exit 7): home-manager switch"* ]]
    [[ "$output" != *"Install complete"* ]]
}

@test "a failing snapshot stops the install before chezmoi apply" {
    make_repo repo
    stub "$FAKE/ops/snapshot-home.sh" 'echo "snapshot boom" >&2; exit 1'
    run env USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"[install:error]"*"snapshot-home.sh"* ]]
    ! grep -q 'args=.* apply' "$STUB_LOG"
}

@test "a missing snapshot helper stops the install before chezmoi apply" {
    make_repo repo
    rm "$FAKE/ops/snapshot-home.sh"
    run env USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"[install:error] ops/snapshot-home.sh missing"* ]]
    ! grep -q 'args=.* apply' "$STUB_LOG"
}

# ── chezmoi source directory and mise working directory ─────────────────────

@test "every chezmoi call, including the snapshot's, names the repo as its source" {
    make_repo repo
    stub "$FAKE/ops/snapshot-home.sh" 'chezmoi managed --include files,symlinks'
    run env USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    echo "$output"
    [ "$status" -eq 0 ]
    [ "$(grep -c '^chezmoi ' "$STUB_LOG")" -eq 3 ]   # init, managed (snapshot), apply
    grep -q "args=init --source=$FAKE\$" "$STUB_LOG"
    grep -q "args=--source=$FAKE managed" "$STUB_LOG"
    grep -q "args=--source=$FAKE apply --force" "$STUB_LOG"
}

@test "the dry-run chezmoi diff names the repo as its source" {
    make_repo repo
    run env USER=utmostcreator DRY_RUN=1 HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *'chezmoi --source="$1" diff'* ]]
    [[ "$output" == *"chezmoi init --source=$FAKE"* ]]
}

@test "mise install runs in the repo, not in the caller's directory" {
    make_repo repo
    mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
    cd "$BATS_TEST_TMPDIR/elsewhere"
    run env USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    grep -q "^mise cwd=$FAKE nixcfg=\[[^]]*\] args=install\$" "$STUB_LOG"
}

# ── Nix install, base tools, experimental features ──────────────────────────

# restricted_path: a PATH with only the stubs and symlinks to the few host tools
# install.sh needs, so a host-installed nix/home-manager/curl cannot leak in.
restricted_path() {
    local bin="$BATS_TEST_TMPDIR/basebin" c
    mkdir -p "$bin"
    for c in bash sh git sed grep cat cut head tr mktemp rm mkdir dirname id uname env date cp mv touch wc sort tail basename readlink chmod; do
        ln -sf "$(command -v "$c")" "$bin/$c"
    done
    RPATH="$STUBS:$bin"
}

@test "only the missing base tools are installed" {
    make_repo repo
    stub_tool mise
    stub "$STUBS/lefthook" 'exit 0'
    mv "$STUBS/home-manager" "$STUBS/home-manager.pending"
    restricted_path
    run env USER=utmostcreator PATH="$RPATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    echo "$output"
    [ "$status" -eq 0 ]
    grep -q 'args=profile install nixpkgs#home-manager$' "$STUB_LOG"
    [ "$(grep -c 'nixpkgs#chezmoi\|nixpkgs#mise\|nixpkgs#lefthook' "$STUB_LOG")" -eq 0 ]
}

@test "an existing Nix without nix-command and flakes gets them for this run only" {
    make_repo repo
    run env USER=utmostcreator NIX_STUB_CONFIG="max-jobs = 4" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    grep -q '^home-manager .*nixcfg=\[extra-experimental-features = nix-command flakes\]' "$STUB_LOG"
    [ ! -e "$HOME/.config/nix" ]
}

@test "an existing Nix that lacks only flakes is topped up" {
    make_repo repo
    run env USER=utmostcreator NIX_STUB_CONFIG="experimental-features = nix-command" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    grep -q '^home-manager .*nixcfg=\[extra-experimental-features = nix-command flakes\]' "$STUB_LOG"
}

@test "a Nix that already has both features is left alone" {
    make_repo repo
    run env USER=utmostcreator NIX_STUB_CONFIG="experimental-features = nix-command flakes" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    grep -q '^home-manager .*nixcfg=\[\]' "$STUB_LOG"
}

# no_nix_host: nix is not installed and the host is not NixOS. The curl stub
# serves an installer script that "installs" the held nix stub.
no_nix_host() {
    make_repo repo
    export STUBS
    mv "$STUBS/nix" "$STUBS/nix.hold"
    cat >"$STUBS/curl" <<'EOF'
#!/usr/bin/env bash
out=""
while [ $# -gt 0 ]; do [ "$1" = -o ] && out="$2"; shift; done
printf 'curl\n' >>"$STUB_LOG"
[ -z "${STUB_FAIL_CURL:-}" ] || exit "$STUB_FAIL_CURL"
cat >"$out" <<INST
#!/bin/sh
printf 'installer %s\n' "\$*" >>"$STUB_LOG"
mv "$STUBS/nix.hold" "$STUBS/nix"
INST
EOF
    chmod +x "$STUBS/curl"
    restricted_path
    NONIXOS="INSTALL_NIXOS_MARKER=$BATS_TEST_TMPDIR/none INSTALL_OS_RELEASE=$BATS_TEST_TMPDIR/none"
}

@test "a failed Nix installer download stops the install before the installer runs" {
    no_nix_host
    run env $NONIXOS USER=utmostcreator STUB_FAIL_CURL=22 PATH="$RPATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 22 ]
    [[ "$output" == *"[install:error] command failed (exit 22): curl"* ]]
    [[ "$output" != *"nix still not on PATH"* ]]
    ! grep -q '^installer' "$STUB_LOG"
}

@test "the downloaded Nix installer is run as a file, then the install continues" {
    no_nix_host
    run env $NONIXOS USER=utmostcreator PATH="$RPATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    echo "$output"
    [ "$status" -eq 0 ]
    grep -q '^installer install --no-confirm$' "$STUB_LOG"
    [[ "$output" != *"| sh"* ]]
}

@test "dry-run without Nix shows the download step and defers the user check" {
    no_nix_host
    run env $NONIXOS USER=utmostcreator DRY_RUN=1 PATH="$RPATH" HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: curl"*"-o "* ]]
    [[ "$output" == *"would run: sh "*"install --no-confirm"* ]]
    [[ "$output" == *"login-user check will run after a real install"* ]]
    [[ "$output" != *"| sh"* ]]
    [ ! -e "$STUB_LOG" ]
}

# ── NixOS system-layer advisory ─────────────────────────────────────────────

# nixos_host: install.sh believes it runs on NixOS; systemctl reports
# nix-optimise.timer active and nix-gc.timer active only when STUB_GC_ACTIVE is set.
nixos_host() {
    make_repo repo
    : >"$BATS_TEST_TMPDIR/NIXOS"
    NIXOS="INSTALL_NIXOS_MARKER=$BATS_TEST_TMPDIR/NIXOS"
    stub "$STUBS/systemctl" '[ "$1" = is-active ] || exit 0
case "$2" in
  nix-gc.timer) [ -n "${STUB_GC_ACTIVE:-}" ] ;;
  nix-optimise.timer) true ;;
  *) false ;;
esac'
}

@test "the NixOS advisory never suggests adding the user to trusted-users" {
    nixos_host
    run env $NIXOS USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NixOS system layer"* ]]
    [[ "$output" != *"trusted-users"* ]]
}

@test "nix-optimise.timer alone does not satisfy the GC timer check" {
    nixos_host
    run env $NIXOS USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nix-gc.timer is not active"* ]]
}

@test "an active nix-gc.timer passes the GC timer check" {
    nixos_host
    run env $NIXOS USER=utmostcreator STUB_GC_ACTIVE=1 HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"nix-gc.timer is not active"* ]]
}

# ── OS gating and the completion message ────────────────────────────────────

# helpers_present: optional helpers exist and log their calls.
helpers_present() {
    mkdir -p "$FAKE/ops/unix"
    stub "$FAKE/ops/syncthing-obsidian-stignore.sh" 'echo "syncthing $*" >>"$STUB_LOG"'
    stub "$FAKE/ops/unix/ssh-agent-setup.sh" 'echo "ssh-agent $*" >>"$STUB_LOG"'
    stub "$FAKE/ops/vscode-extensions.sh" 'echo "vscode $*" >>"$STUB_LOG"'
}

@test "the Linux-only Syncthing helper is not run on macOS" {
    make_repo repo
    helpers_present
    run env USER=utmostcreator DRY_RUN=1 HOST_PROFILE=macos bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"syncthing-obsidian-stignore"* ]]
}

@test "the Syncthing helper still runs on Linux, in dry-run and for real" {
    make_repo repo
    helpers_present
    run env USER=utmostcreator DRY_RUN=1 HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: bash $FAKE/ops/syncthing-obsidian-stignore.sh"* ]]
    run env USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    grep -q '^syncthing --apply$' "$STUB_LOG"
}

@test "a clean install ends with Install complete" {
    make_repo repo
    helpers_present
    run env INSTALL_NIXOS_MARKER=none INSTALL_OS_RELEASE=none USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Install complete (host=linux-cli, mode=apply)."* ]]
    [[ "$output" != *"degraded"* ]]
}

@test "a dry run never says Install complete" {
    make_repo repo
    run env USER=utmostcreator DRY_RUN=1 HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry run finished; nothing was changed."* ]]
    [[ "$output" != *"Install complete"* ]]
}

@test "a failed ssh-agent helper is listed as degraded, not as a complete install" {
    make_repo repo
    helpers_present
    stub "$FAKE/ops/unix/ssh-agent-setup.sh" 'exit 1'
    run env INSTALL_NIXOS_MARKER=none INSTALL_OS_RELEASE=none USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"finished with degraded steps (not a clean success)"* ]]
    [[ "$output" == *"degraded: ssh-agent-setup"* ]]
    [[ "$output" != *"Install complete"* ]]
}

@test "failed VS Code and Syncthing helpers are listed as degraded" {
    make_repo repo
    helpers_present
    stub "$FAKE/ops/vscode-extensions.sh" 'exit 1'
    stub "$FAKE/ops/syncthing-obsidian-stignore.sh" 'exit 1'
    run env INSTALL_NIXOS_MARKER=none INSTALL_OS_RELEASE=none USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"degraded: VS Code extensions"* ]]
    [[ "$output" == *"degraded: Syncthing"* ]]
    [[ "$output" != *"Install complete"* ]]
}

@test "a pending NixOS system rebuild is degraded and printed before any completion line" {
    nixos_host
    helpers_present
    run env $NIXOS USER=utmostcreator HOST_PROFILE=linux-cli bash "$FAKE/ops/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"degraded: system layer"* ]]
    [[ "$output" != *"Install complete"* ]]
}
