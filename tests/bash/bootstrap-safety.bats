#!/usr/bin/env bats
# Bootstrap safety for macOS and WSL: host detection, chezmoi source
# resolution for both documented clone locations, and first-install behaviour.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    PROC="$BATS_TEST_TMPDIR/version"
    # Isolate from the host: no inherited WSL env or WSL filesystem markers.
    unset WSL_DISTRO_NAME
    export DETECT_HOST_WSL_RUN="$BATS_TEST_TMPDIR/no-wsl-run" DETECT_HOST_WSL_INTEROP="$BATS_TEST_TMPDIR/no-wsl-interop"
}

fake_uname() {
    printf '#!/bin/sh\necho %s\n' "$1" >"$STUBS/uname"
    chmod +x "$STUBS/uname"
}

detect() {
    PATH="$STUBS:$PATH" DETECT_HOST_PROC_VERSION="$PROC" DETECT_HOST_OSRELEASE="$BATS_TEST_TMPDIR/no-osrelease" run env -u HOST_PROFILE \
        bash "$REPO_ROOT/ops/detect-host.sh"
}

# ── host detection ──────────────────────────────────────────────────────────

@test "detect-host: Darwin is macos" {
    fake_uname Darwin
    detect
    [ "$status" -eq 0 ]
    [ "$output" = "macos" ]
}

@test "detect-host: WSL2 kernel is wsl" {
    fake_uname Linux
    echo 'Linux version 6.6.87.2-microsoft-standard-WSL2 (gcc) #1 SMP' >"$PROC"
    detect
    [ "$output" = "wsl" ]
}

@test "detect-host: plain Linux is linux-desktop, not wsl" {
    fake_uname Linux
    echo 'Linux version 6.18.33 (nixbld@localhost) #1-NixOS SMP' >"$PROC"
    detect
    [ "$output" = "linux-desktop" ]
}

@test "detect-host: HOST_PROFILE override wins and is validated" {
    run env HOST_PROFILE=wsl bash "$REPO_ROOT/ops/detect-host.sh"
    [ "$output" = "wsl" ]
    run env HOST_PROFILE=windows bash "$REPO_ROOT/ops/detect-host.sh"
    [ "$status" -ne 0 ]
}

# ── chezmoi source resolution ───────────────────────────────────────────────

make_repo() { # make_repo <dir>: minimal repo layout chezmoi understands
    mkdir -p "$1/home" "$1/ops"
    cp "$REPO_ROOT/.chezmoiroot" "$1/"
    printf '#!/bin/sh\necho "ran $0 $*"\n' >"$1/ops/update-codebase-memory-mcp.sh"
    : >"$BATS_TEST_TMPDIR/chezmoi.toml"
}

@test "sys-* helpers render DOTFILES_DIR for both clone locations" {
    for loc in app-configs Projects/app-configs; do
        local r="$BATS_TEST_TMPDIR/h/$loc"
        make_repo "$r"
        cp "$REPO_ROOT/home/dot_local/bin/executable_sys-update.tmpl" "$r/home/"
        run chezmoi execute-template --config "$BATS_TEST_TMPDIR/chezmoi.toml" \
            --source "$r" --file "$r/home/executable_sys-update.tmpl"
        [ "$status" -eq 0 ]
        [[ "$output" == *"DOTFILES_DIR=\"$r\""* ]]
    done
}

@test "MCP update unit finds the repo via chezmoi (both locations and symlink)" {
    local wrapper="$REPO_ROOT/nix/modules/home/scripts/codebase-memory-mcp-update.sh"
    make_repo "$BATS_TEST_TMPDIR/h/app-configs"
    make_repo "$BATS_TEST_TMPDIR/h/Projects/app-configs"
    ln -s "$BATS_TEST_TMPDIR/h/app-configs" "$BATS_TEST_TMPDIR/h/link"
    for r in "$BATS_TEST_TMPDIR/h/app-configs" "$BATS_TEST_TMPDIR/h/Projects/app-configs" \
        "$BATS_TEST_TMPDIR/h/link"; do
        printf '#!/bin/sh\nexec %s --config %s --source %s "$@"\n' \
            "$(command -v chezmoi)" "$BATS_TEST_TMPDIR/chezmoi.toml" "$r" >"$STUBS/chezmoi"
        chmod +x "$STUBS/chezmoi"
        PATH="$STUBS:$PATH" run bash "$wrapper"
        [ "$status" -eq 0 ]
        [[ "$output" == "ran $r/home/../ops/update-codebase-memory-mcp.sh --apply" ]]
    done
}

@test "MCP update unit fails loudly when chezmoi is missing" {
    printf '#!/bin/sh\nexit 1\n' >"$STUBS/chezmoi"
    chmod +x "$STUBS/chezmoi"
    PATH="$STUBS:$PATH" run bash "$REPO_ROOT/nix/modules/home/scripts/codebase-memory-mcp-update.sh"
    [ "$status" -ne 0 ]
}

# ── first install (dry run on a fresh copy without personal.yaml) ───────────

first_install() { # first_install <host>
    FRESH="$BATS_TEST_TMPDIR/fresh-$1"
    mkdir -p "$FRESH"
    git -C "$REPO_ROOT" ls-files -z | (cd "$REPO_ROOT" && xargs -0 tar -cf -) | tar -xf - -C "$FRESH"
    rm -f "$FRESH/home/.chezmoidata/personal.yaml"
    local user
    user="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$REPO_ROOT/nix/vars/default.nix")"
    run env USER="$user" HOST_PROFILE="$1" DRY_RUN=1 bash "$FRESH/ops/install.sh"
}

@test "first install on macos: seeds for macos, uses darwin-rebuild, writes nothing" {
    first_install macos
    [ "$status" -eq 0 ]
    [[ "$output" == *"seed-personal-yaml.sh"*"personal.yaml macos"* ]]
    [[ "$output" == *"darwin-rebuild switch --flake $FRESH/nix#macos"* ]]
    [[ "$output" != *"home-manager switch"* ]]
    [ ! -e "$FRESH/home/.chezmoidata/personal.yaml" ]
}

@test "first install on wsl: seeds for wsl, uses home-manager, writes nothing" {
    first_install wsl
    [ "$status" -eq 0 ]
    [[ "$output" == *"seed-personal-yaml.sh"*"personal.yaml wsl"* ]]
    [[ "$output" == *"home-manager switch -b hm-bak --flake $FRESH/nix#wsl"* ]]
    [[ "$output" != *"darwin-rebuild"* ]]
    [ ! -e "$FRESH/home/.chezmoidata/personal.yaml" ]
}

# ── ops/bootstrap.sh safety contract (T-0008) ───────────────────────────────
# Runs a copy of bootstrap.sh inside a fixture repo with stub tools and a temp
# HOME. Every stub appends "<name> <args> [pwd=<dir>]" to $CALLS; nothing real
# is ever installed or applied.

bs_fixture() {
    FX="$BATS_TEST_TMPDIR/fx"
    HOME_T="$BATS_TEST_TMPDIR/home"
    CALLS="$BATS_TEST_TMPDIR/calls"
    BSTUBS="$BATS_TEST_TMPDIR/bsbin"
    BSYS="$BATS_TEST_TMPDIR/sysbin"
    mkdir -p "$FX/ops/unix" "$HOME_T" "$BSTUBS" "$BSYS" "$FX/.git"
    # Curated PATH: stubs plus symlinked basic tools, so a real nix, chezmoi,
    # mise, home-manager or darwin-rebuild can never be reached.
    local t p
    for t in bash env git curl sed awk cat dirname head find xargs stat sort grep \
        uname mkdir tee tr rm cp chmod ls readlink basename sleep date wc cut id \
        mktemp ln script timeout sh; do
        p="$(command -v "$t" 2>/dev/null)" || continue
        [ -x "$p" ] && ln -sf "$p" "$BSYS/$t"
    done
    BPATH="$BSTUBS:$BSYS"
    : >"$CALLS"
    : >"$FX/mise.toml"
    cp "$REPO_ROOT/ops/bootstrap.sh" "$REPO_ROOT/ops/detect-host.sh" "$FX/ops/"
    cp -a "$REPO_ROOT/ops/lib" "$FX/ops/lib"
    # The shared preflight seeds personal.yaml when it is missing; a present one
    # keeps these tests about bootstrap itself.
    mkdir -p "$FX/home/.chezmoidata" && : >"$FX/home/.chezmoidata/personal.yaml"
    local s
    for s in doctor.sh snapshot-home.sh unix/ssh-agent-setup.sh; do
        printf '#!/usr/bin/env bash\necho "%s $*" >>"%s"\n[ "${STUB_FAIL:-}" = "%s" ] && exit 1\nexit 0\n' \
            "$s" "$CALLS" "$s" >"$FX/ops/$s"
    done
    for s in nix chezmoi mise home-manager lefthook sudo darwin-rebuild; do
        if [ "$s" = darwin-rebuild ] && [ -z "${WITH_DARWIN_REBUILD:-}" ]; then continue; fi
        cat >"$BSTUBS/$s" <<STUB
#!/usr/bin/env bash
echo "$s \$* [pwd=\$PWD]" >>"$CALLS"
case "\${STUB_FAIL:-}" in "$s \$1"*) exit 1 ;; esac
if [ "$s" = nix ] && [ "\${1:-}" = --version ]; then echo "nix (stub) 2.0"; fi
exit 0
STUB
        chmod +x "$BSTUBS/$s"
    done
    chmod +x "$FX"/ops/*.sh "$FX"/ops/unix/*.sh
}

bs() { # bs <args...>: non-TTY stdin
    run env HOME="$HOME_T" PATH="$BPATH" HOST_PROFILE="${BS_HOST:-linux-cli}" \
        bash "$FX/ops/bootstrap.sh" "$@" </dev/null
}

bs_tty() { # bs_tty <answer> <args...>: stdin and stdout on a pty
    local answer="$1" # several answers: "y\ny"
    shift
    # script(1) runs the command with $SHELL: pin bash so a login fish never
    # starts (it writes its own state into the suite HOME).
    run env SHELL="$(command -v bash)" bash -c 'printf "%b\n" "$1" | timeout 30 script -qec "$2" /dev/null' _ "$answer" \
        "env HOME=$HOME_T PATH=$BPATH HOST_PROFILE=${BS_HOST:-linux-cli} bash $FX/ops/bootstrap.sh $*"
}

mutated() { grep -Eq '^(nix profile|nix flake|chezmoi (init|apply)|mise (trust|install)|home-manager switch|lefthook install|sudo [^-]|snapshot-home|unix/ssh-agent)' "$CALLS"; }

@test "bootstrap dry-run is strictly read-only: plans only, creates nothing" {
    bs_fixture
    local before after
    before="$(find "$HOME_T" "$FX" | sort | xargs stat -c '%n %Y %s')"
    bs --dry-run
    after="$(find "$HOME_T" "$FX" | sort | xargs stat -c '%n %Y %s')"
    [ "$status" -eq 0 ]
    [ "$before" = "$after" ]
    if mutated; then return 1; fi
    grep -q 'doctor.sh --preflight' "$CALLS"
    [[ "$output" == *"would: chezmoi init"* ]]
    [[ "$output" == *"would: nix flake check"* ]]
    [[ "$output" != *"bootstrap complete"* ]]
}

@test "bootstrap dry-run runs no chezmoi, flake check or switch preview" {
    bs_fixture
    bs --dry-run
    [ "$status" -eq 0 ]
    run grep -Eq '^(chezmoi|nix flake|home-manager)' "$CALLS"
    [ "$status" -ne 0 ]
}

@test "bootstrap is dry-run by default and ignores the MODE env var" {
    bs_fixture
    run env MODE=apply CI=true HOME="$HOME_T" PATH="$BPATH" HOST_PROFILE=linux-cli \
        bash "$FX/ops/bootstrap.sh" </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"bootstrap:dry-run"* ]]
    if mutated; then return 1; fi
}

@test "bootstrap --apply without a TTY and without --yes fails, whatever CI is" {
    bs_fixture
    local ci
    for ci in "" true false 0 1; do
        : >"$CALLS"
        run env CI="$ci" HOME="$HOME_T" PATH="$BPATH" HOST_PROFILE=linux-cli \
            bash "$FX/ops/bootstrap.sh" --apply </dev/null
        [ "$status" -ne 0 ]
        [[ "$output" == *"--yes"* ]]
        if mutated; then return 1; fi
    done
}

@test "bootstrap --yes applies non-interactively and reports completion" {
    bs_fixture
    bs --yes
    [ "$status" -eq 0 ]
    grep -q '^nix profile install' "$CALLS"
    grep -q '^chezmoi apply' "$CALLS"
    grep -q '^home-manager switch' "$CALLS"
    grep -qx 'doctor.sh ' "$CALLS"
    [[ "$output" == *"bootstrap complete"* ]]
}

@test "bootstrap --yes does not prompt on a TTY" {
    bs_fixture
    bs_tty "" --yes
    [ "$status" -eq 0 ]
    [[ "$output" != *"[y/N]"* ]]
    grep -q '^chezmoi apply' "$CALLS"
}

@test "bootstrap --apply on a TTY asks, and declining mutates nothing" {
    bs_fixture
    bs_tty n --apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"[y/N]"* ]]
    if mutated; then return 1; fi
}

@test "bootstrap --apply on a TTY proceeds after two y answers" {
    bs_fixture
    bs_tty 'y\ny' --apply
    [ "$status" -eq 0 ]
    grep -q '^chezmoi apply' "$CALLS"
}

@test "bootstrap --apply on a TTY asks again after chezmoi diff; declining applies nothing" {
    bs_fixture
    bs_tty 'y\nn' --apply
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing was applied"* ]]
    [[ "$output" != *"bootstrap complete"* ]]
    grep -q '^chezmoi diff' "$CALLS"
    run grep -Eq '^(chezmoi apply|home-manager|mise|snapshot-home)' "$CALLS"
    [ "$status" -ne 0 ]
}

@test "bootstrap prompts on stderr, so redirected stdout does not hide them" {
    bs_fixture
    bs_tty n --apply '>/dev/null'
    [ "$status" -ne 0 ]
    [[ "$output" == *"[y/N]"* ]]
}

@test "bootstrap repeating the same mode flag is not a conflict" {
    bs_fixture
    bs --dry-run --dry-run
    [ "$status" -eq 0 ]
    bs --apply --yes
    [ "$status" -eq 0 ]
}

@test "bootstrap prefers freshly installed ~/.nix-profile/bin tools" {
    bs_fixture
    mkdir -p "$HOME_T/.nix-profile/bin"
    printf '#!/usr/bin/env bash\necho "profilebin chezmoi $*" >>"%s"\n' "$CALLS" \
        >"$HOME_T/.nix-profile/bin/chezmoi"
    chmod +x "$HOME_T/.nix-profile/bin/chezmoi"
    # A bare bin/ without a manifest is not a real profile; skip the HM
    # conflict check here (hm-switch.bats covers it).
    export HM_PROFILE_MANIFEST="$BATS_TEST_TMPDIR/no-profile/manifest.json"
    bs --yes
    [ "$status" -eq 0 ]
    grep -q '^profilebin chezmoi apply' "$CALLS"
}

@test "bootstrap macOS apply checks sudo up front: no TTY uses sudo -n, nothing mutated" {
    bs_fixture
    STUB_FAIL="sudo -n" BS_HOST=macos bs --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs sudo"* ]]
    grep -q '^sudo -n true' "$CALLS"
    if mutated; then return 1; fi
}

@test "bootstrap macOS apply on a TTY validates sudo with sudo -v before mutating" {
    bs_fixture
    STUB_FAIL="sudo -v" BS_HOST=macos bs_tty "" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs sudo"* ]]
    grep -q '^sudo -v' "$CALLS"
    if mutated; then return 1; fi
}

@test "bootstrap rejects unknown args and conflicting mode flags" {
    bs_fixture
    bs --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown arg: --bogus"* ]]
    bs --yes --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"conflicting"* ]]
    bs --dry-run --yes
    [ "$status" -eq 1 ]
    if mutated; then return 1; fi
}

@test "bootstrap fails when chezmoi diff fails and never applies" {
    bs_fixture
    STUB_FAIL="chezmoi diff" bs --yes
    [ "$status" -ne 0 ]
    run grep -q '^chezmoi apply' "$CALLS"
    [ "$status" -ne 0 ]
}

@test "bootstrap fails when the switch preview fails and never switches" {
    bs_fixture
    STUB_FAIL="home-manager switch" bs --yes
    [ "$status" -ne 0 ]
    [ "$(grep -c '^home-manager switch' "$CALLS")" -eq 1 ]
    grep -q '^home-manager switch.*--dry-run' "$CALLS"
    [[ "$output" != *"bootstrap complete"* ]]
}

@test "bootstrap fails when doctor.sh is missing, in dry-run and apply" {
    bs_fixture
    rm "$FX/ops/doctor.sh"
    bs --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"doctor.sh"* ]]
    bs --yes
    [ "$status" -ne 0 ]
    if mutated; then return 1; fi
}

@test "bootstrap fails when doctor --preflight fails, before mutating" {
    bs_fixture
    STUB_FAIL="doctor.sh" bs --yes
    [ "$status" -ne 0 ]
    if mutated; then return 1; fi
}

@test "bootstrap runs mise in the repo, trusting only its mise.toml" {
    bs_fixture
    cd "$HOME_T"
    bs --yes
    [ "$status" -eq 0 ]
    grep -qxF "mise trust ./mise.toml [pwd=$FX]" "$CALLS"
    grep -qxF "mise install [pwd=$FX]" "$CALLS"
}

@test "bootstrap macOS first run: sudo nix run pinned darwin-rebuild, preview via nix build" {
    bs_fixture
    BS_HOST=macos bs --yes
    [ "$status" -eq 0 ]
    grep -q "^nix build --no-link $FX/nix#darwinConfigurations.macos.system" "$CALLS"
    grep -q "^sudo nix run $FX/nix#darwin-rebuild -- switch --flake $FX/nix#macos" "$CALLS"
    run grep -q 'darwin-rebuild check' "$CALLS"
    [ "$status" -ne 0 ]
}

@test "bootstrap macOS with darwin-rebuild on PATH uses sudo darwin-rebuild" {
    WITH_DARWIN_REBUILD=1 bs_fixture
    BS_HOST=macos bs --yes
    [ "$status" -eq 0 ]
    grep -q "^sudo darwin-rebuild switch --flake $FX/nix#macos" "$CALLS"
    run grep -q '^sudo nix run' "$CALLS"
    [ "$status" -ne 0 ]
}

@test "bootstrap reports a degraded ssh-agent step instead of plain success" {
    bs_fixture
    STUB_FAIL="unix/ssh-agent-setup.sh" bs --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"degraded"*"ssh-agent"* ]]
    [[ "$output" != *"bootstrap complete"* ]]
}

@test "bootstrap rejects WSL1 via detect-host and does nothing" {
    bs_fixture
    printf '#!/bin/sh\necho Linux\n' >"$BSTUBS/uname"
    chmod +x "$BSTUBS/uname"
    echo 'Linux version 4.4.0-19041-Microsoft (gcc)' >"$BATS_TEST_TMPDIR/proc"
    echo 4.4.0-19041-Microsoft >"$BATS_TEST_TMPDIR/osr"
    run env -u HOST_PROFILE HOME="$HOME_T" PATH="$BPATH" \
        DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/proc" DETECT_HOST_OSRELEASE="$BATS_TEST_TMPDIR/osr" \
        bash "$FX/ops/bootstrap.sh" --dry-run </dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *WSL1* ]]
    if mutated; then return 1; fi
}
