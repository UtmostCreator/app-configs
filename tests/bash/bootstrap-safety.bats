#!/usr/bin/env bats
# Bootstrap safety for macOS and WSL: host detection, chezmoi source
# resolution for both documented clone locations, and first-install behaviour.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    STUBS="$BATS_TEST_TMPDIR/bin"
    # Exact-command-line tests below: never pick up a real selection file or an
    # exported XDG_CONFIG_HOME (tests that want a selection set their own).
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/no-selection"
    mkdir -p "$STUBS"
    PROC="$BATS_TEST_TMPDIR/version"
    # Isolate from the host: no inherited WSL env or WSL filesystem markers.
    unset WSL_DISTRO_NAME
    export DETECT_HOST_WSL_RUN="$BATS_TEST_TMPDIR/no-wsl-run" DETECT_HOST_WSL_INTEROP="$BATS_TEST_TMPDIR/no-wsl-interop"
    # The host is not NixOS unless a test says so (wsl maps to wsl-nixos there).
    export DETECT_HOST_NIXOS_MARKER="$BATS_TEST_TMPDIR/no-NIXOS" DETECT_HOST_OS_RELEASE="$BATS_TEST_TMPDIR/no-os-release"
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
        printf '%s\n' "$output" | grep -qx "DOTFILES_DIR=\"$r\""
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

# Render the REAL sys-update template for repo $1 into $HOME/.local/bin.
render_wrapper() {
    cp "$REPO_ROOT/home/dot_local/bin/executable_sys-update.tmpl" "$1/home/"
    mkdir -p "$HOME/.local/bin"
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/chezmoi.toml" --source "$1" \
        --file "$1/home/executable_sys-update.tmpl" >"$HOME/.local/bin/sys-update"
}

wsl_chezmoi_stub() {
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    printf '#!/bin/sh\necho "$HOME/.local/share/chezmoi"\n' >"$STUBS/chezmoi"
    chmod +x "$STUBS/chezmoi"
}

@test "MCP update unit: NixOS-WSL default source dir is missing, the repo comes from the rendered sys-update wrapper" {
    local wrapper="$REPO_ROOT/nix/modules/home/scripts/codebase-memory-mcp-update.sh" r="$BATS_TEST_TMPDIR/h/app-configs"
    make_repo "$r"
    wsl_chezmoi_stub
    render_wrapper "$r"
    PATH="$STUBS:$PATH" run bash "$wrapper"
    [ "$status" -eq 0 ]
    [[ "$output" == "ran $r/ops/update-codebase-memory-mcp.sh --apply" ]]
}

@test "MCP update unit: an existing default source dir that is not the repo falls back to the wrapper" {
    local wrapper="$REPO_ROOT/nix/modules/home/scripts/codebase-memory-mcp-update.sh" r="$BATS_TEST_TMPDIR/h/app-configs"
    make_repo "$r"
    wsl_chezmoi_stub
    mkdir -p "$HOME/.local/share/chezmoi"
    render_wrapper "$r"
    PATH="$STUBS:$PATH" run bash "$wrapper"
    [ "$status" -eq 0 ]
    [[ "$output" == "ran $r/ops/update-codebase-memory-mcp.sh --apply" ]]
}

@test "MCP update unit: a wrapper naming a missing directory fails with 'cannot locate the repo'" {
    wsl_chezmoi_stub
    mkdir -p "$HOME/.local/bin"
    printf 'DOTFILES_DIR="%s/gone"\n' "$BATS_TEST_TMPDIR" >"$HOME/.local/bin/sys-update"
    PATH="$STUBS:$PATH" run bash "$REPO_ROOT/nix/modules/home/scripts/codebase-memory-mcp-update.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot locate the repo"* ]]
}

@test "both unit scripts locate the repo with no tool but bash and chezmoi on PATH (unit PATHs carry no sed/head)" {
    # The audit and update units' PATHs are supersets of {bash, chezmoi}; a
    # script that works with only these cannot depend on sed, head, etc.
    local r="$BATS_TEST_TMPDIR/h/app-configs" bash_bin script
    make_repo "$r"
    mkdir -p "$r/ops"
    printf '#!/bin/sh\necho "ran $0 $*"\n' >"$r/ops/audit.sh"
    wsl_chezmoi_stub
    render_wrapper "$r"
    bash_bin="$(command -v bash)"
    mkdir -p "$BATS_TEST_TMPDIR/only"; ln -s "$bash_bin" "$BATS_TEST_TMPDIR/only/bash"
    cp "$STUBS/chezmoi" "$BATS_TEST_TMPDIR/only/chezmoi"
    for script in repo-audit.sh codebase-memory-mcp-update.sh; do
        run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/only" "$bash_bin" "$REPO_ROOT/nix/modules/home/scripts/$script"
        [ "$status" -eq 0 ]
        [[ "$output" == *"ran $r/ops/"* ]]
    done
}

@test "repo_root() is identical in the audit and the MCP update unit scripts" {
    body() { sed -n '/^repo_root() {$/,/^}$/p' "$REPO_ROOT/nix/modules/home/scripts/$1"; }
    [ -n "$(body repo-audit.sh)" ]
    [ "$(body repo-audit.sh)" = "$(body codebase-memory-mcp-update.sh)" ]
}

@test "MCP update unit fails loudly when chezmoi is missing" {
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
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
    # install.sh asks Nix for the username and its features; never use the
    # host's nix. The stub answers `nix eval --raw -f <file> username` by
    # reading the file and reports both experimental features as enabled.
    printf '%s\n' '#!/usr/bin/env bash' \
        'case "$1" in' \
        '  eval) sed -nE '"'"'s/^[[:space:]]*username = "([^"]+)";.*/\1/p'"'"' "$4" ;;' \
        '  show-config) echo "experimental-features = nix-command flakes" ;;' \
        '  --version) echo "nix (stub) 0" ;;' \
        'esac' >"$STUBS/nix"
    chmod +x "$STUBS/nix"
    run env PATH="$STUBS:$PATH" USER="$user" HOST_PROFILE="$1" DRY_RUN=1 bash "$FRESH/ops/install.sh"
}

@test "first install on macos: seeds for macos, uses darwin-rebuild, writes nothing" {
    first_install macos
    [ "$status" -eq 0 ]
    [[ "$output" == *"seed-personal-yaml.sh"*"personal.yaml macos"* ]]
    [[ "$output" == *"sudo nix --extra-experimental-features nix-command flakes run $FRESH/nix#darwin-rebuild -- switch --flake $FRESH/nix#macos"* ]]
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

@test "first install on NixOS-WSL: the switch is planned for wsl-nixos" {
    : >"$BATS_TEST_TMPDIR/NIXOS"; export DETECT_HOST_NIXOS_MARKER="$BATS_TEST_TMPDIR/NIXOS"
    first_install wsl
    [ "$status" -eq 0 ]
    [[ "$output" == *"home-manager switch -b hm-bak --flake $FRESH/nix#wsl-nixos"* ]]
    [[ "$output" != *"nix#wsl "* && "$output" != *"nix#wsl"$'\n'* ]]
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
    for s in doctor.sh snapshot-home.sh install-git-hooks.sh unix/ssh-agent-setup.sh; do
        printf '#!/usr/bin/env bash\necho "%s $*" >>"%s"\n[ "${STUB_FAIL:-}" = "%s" ] && exit 1\nexit 0\n' \
            "$s" "$CALLS" "$s" >"$FX/ops/$s"
    done
    for s in nix chezmoi mise home-manager lefthook sudo darwin-rebuild; do
        if [ "$s" = darwin-rebuild ] && [ -z "${WITH_DARWIN_REBUILD:-}" ]; then continue; fi
        cat >"$BSTUBS/$s" <<STUB
#!/usr/bin/env bash
if [ "$s" = chezmoi ]; then
  # An unconfigured chezmoi (sourceDir not persisted by \`chezmoi init --source\`):
  # every subcommand but init fails without --source=<repo>. CALLS gets the call
  # without that flag (stable greps); the raw call goes to CALLS.raw.
  echo "chezmoi \$*" >>"$CALLS.raw"
  _src=0; _a=()
  for _x in "\$@"; do case "\$_x" in --source=*) _src=1 ;; *) _a+=("\$_x") ;; esac; done
  set -- "\${_a[@]}"
  # a plain source-path answers like real chezmoi: the default path, rc 0, directory missing
  if [ "\$*" = source-path ] && [ "\$_src" = 0 ]; then echo "\$HOME/.local/share/chezmoi"; exit 0; fi
  if [ "\${CHEZMOI_UNCONFIGURED:-1}" = 1 ] && [ "\$_src" = 0 ] && [ "\${1:-}" != init ]; then
    echo "chezmoi: stat \$HOME/.local/share/chezmoi: no such file or directory" >&2
    exit 1
  fi
fi
echo "$s \$* [pwd=\$PWD]" >>"$CALLS"
case "\${STUB_FAIL:-}" in "$s \$1"*) exit 1 ;; esac
if [ "$s" = nix ] && [ "\${1:-}" = --version ]; then echo "nix (stub) 2.0"; fi
if [ "$s" = nix ] && [ "\${1:-}" = eval ]; then echo "\${USER:-\$(id -un)}"; fi
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

mutated() { grep -Eq '^(nix profile|nix flake|chezmoi (init|apply)|mise (trust|install)|home-manager switch|install-git-hooks|sudo [^-]|snapshot-home|unix/ssh-agent)' "$CALLS"; }

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

@test "bootstrap --yes installs the git hooks, then checks them; lefthook install is never run" {
    bs_fixture
    bs --yes
    [ "$status" -eq 0 ]
    [ "$(grep -n '^install-git-hooks.sh $' "$CALLS" | cut -d: -f1)" -lt "$(grep -n '^install-git-hooks.sh --check$' "$CALLS" | cut -d: -f1)" ]
    run grep -c '^lefthook install' "$CALLS"
    [ "$output" = 0 ]
}

@test "bootstrap --yes stops when the git hook check fails" {
    bs_fixture
    printf '#!/usr/bin/env bash\necho "install-git-hooks.sh $*" >>"%s"\n[ "${1:-}" = --check ] && exit 1\nexit 0\n' "$CALLS" >"$FX/ops/install-git-hooks.sh"
    bs --yes
    [ "$status" -ne 0 ]
    [[ "$output" != *"bootstrap complete"* ]]
}

@test "bootstrap dry-run only announces the git hook install" {
    bs_fixture
    bs --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would: bash ops/install-git-hooks.sh (then --check)"* ]]
    run grep -c '^install-git-hooks' "$CALLS"
    [ "$output" = 0 ]
}

@test "bootstrap with a local selection: preview and switch carry the override (linux)" {
    bs_fixture
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/sel"
    mkdir -p "$APP_CONFIGS_SELECTION_DIR"; printf 'profile = "work"\n' >"$APP_CONFIGS_SELECTION_DIR/selection.toml"
    bs --yes
    [ "$status" -eq 0 ]
    grep -q "^home-manager switch -b hm-bak --flake $FX/nix#linux-cli --override-input selection path:$APP_CONFIGS_SELECTION_DIR --dry-run " "$CALLS"
    grep -q "^home-manager switch -b hm-bak --flake $FX/nix#linux-cli --override-input selection path:$APP_CONFIGS_SELECTION_DIR \[pwd=" "$CALLS"
    bs --dry-run
    [[ "$output" == *"would: home-manager switch -b hm-bak --flake $FX/nix#linux-cli --override-input selection path:$APP_CONFIGS_SELECTION_DIR"* ]]
}

@test "bootstrap with a local selection: macOS preview build and both sudo forms carry it" {
    bs_fixture
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/sel"
    mkdir -p "$APP_CONFIGS_SELECTION_DIR"; printf 'profile = "work"\n' >"$APP_CONFIGS_SELECTION_DIR/selection.toml"
    BS_HOST=macos bs --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would: nix build --no-link $FX/nix#darwinConfigurations.macos.system --override-input selection path:$APP_CONFIGS_SELECTION_DIR"* ]]
    [[ "$output" == *"-- switch --flake $FX/nix#macos --override-input selection path:$APP_CONFIGS_SELECTION_DIR"* ]]
    WITH_DARWIN_REBUILD=1 bs_fixture
    BS_HOST=macos bs --dry-run
    [[ "$output" == *"would: sudo darwin-rebuild switch --flake $FX/nix#macos --override-input selection path:$APP_CONFIGS_SELECTION_DIR"* ]]
}

@test "bootstrap without a local selection: switch lines are unchanged" {
    bs_fixture
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/none"
    bs --yes
    [ "$status" -eq 0 ]
    grep -q "^home-manager switch -b hm-bak --flake $FX/nix#linux-cli --dry-run " "$CALLS"
    grep -q "^home-manager switch -b hm-bak --flake $FX/nix#linux-cli \[pwd=" "$CALLS"
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
    grep -q '^profilebin chezmoi .*apply' "$CALLS"
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

@test "T-0009: bootstrap passes --source=<repo> to chezmoi diff and apply after init (sourceDir is not persisted)" {
    bs_fixture
    bs --yes
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    grep -qF "chezmoi init --source=$FX" "$CALLS.raw"
    grep -qF "chezmoi --source=$FX diff" "$CALLS.raw"
    grep -qF "chezmoi --source=$FX apply" "$CALLS.raw"
    grep -q '^chezmoi apply' "$CALLS"
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
    grep -q "^sudo nix --extra-experimental-features nix-command flakes run $FX/nix#darwin-rebuild -- switch --flake $FX/nix#macos" "$CALLS"
    run grep -q 'darwin-rebuild check' "$CALLS"
    [ "$status" -ne 0 ]
}

@test "bootstrap macOS with darwin-rebuild on PATH uses sudo darwin-rebuild" {
    WITH_DARWIN_REBUILD=1 bs_fixture
    BS_HOST=macos bs --yes
    [ "$status" -eq 0 ]
    grep -q "^sudo darwin-rebuild switch --flake $FX/nix#macos" "$CALLS"
    run grep -q "^sudo nix " "$CALLS"
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

# -- remembered linux host (T-0044) ----------------------------------------------
# bootstrap never asks and never writes the host file; it reads it through
# detect-host and warns when personal.yaml disagrees, before chezmoi apply.

bs_hostfile() { # bs_hostfile <value>: HOST_PROFILE unset, a pinned host file
    export APP_CONFIGS_HOST_FILE="$BATS_TEST_TMPDIR/cfg/app-configs/host"
    mkdir -p "$(dirname "$APP_CONFIGS_HOST_FILE")"
    printf '%s\n' "$1" >"$APP_CONFIGS_HOST_FILE"
    echo 'Linux version 6.18.33 (b@h) (gcc) #1 SMP' >"$BATS_TEST_TMPDIR/proc-version"
    echo 6.18.33 >"$BATS_TEST_TMPDIR/osrelease"
    printf '#!/bin/sh\necho Linux\n' >"$BSTUBS/uname"; chmod +x "$BSTUBS/uname"
}

bs_nohost() { # like bs, but HOST_PROFILE stays unset
    run env -u HOST_PROFILE HOME="$HOME_T" PATH="$BPATH" \
        DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/proc-version" DETECT_HOST_OSRELEASE="$BATS_TEST_TMPDIR/osrelease" \
        bash "$FX/ops/bootstrap.sh" "$@" </dev/null
}

@test "bootstrap reports linux-cli from the host file and does not prompt or write" {
    bs_fixture
    bs_hostfile linux-cli
    bs_nohost --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Host: linux-cli"* ]]
    [ "$(cat "$APP_CONFIGS_HOST_FILE")" = linux-cli ]
}

@test "bootstrap warns before chezmoi when personal.yaml disagrees with the host file, and edits nothing" {
    bs_fixture
    bs_hostfile linux-cli
    printf 'name: Sentinel\nhostProfile: "linux-desktop"\ngui: true\n' >"$FX/home/.chezmoidata/personal.yaml"
    local before; before="$(cksum <"$FX/home/.chezmoidata/personal.yaml")"
    bs_nohost --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"detected host: linux-cli"* ]]
    [[ "$output" == *'hostProfile: "linux-desktop"'* ]]
    [[ "$output" == *"gui: true"* ]]
    [[ "$output" == *'set hostProfile: "linux-cli" and gui: false'* ]]
    [[ "$output" != *Sentinel* ]]
    local warn_pos chezmoi_pos
    warn_pos="$(printf '%s' "$output" | grep -bo 'detected host: linux-cli' | head -n1 | cut -d: -f1)"
    chezmoi_pos="$(printf '%s' "$output" | grep -bo 'would: chezmoi init' | head -n1 | cut -d: -f1)"
    [ "$warn_pos" -lt "$chezmoi_pos" ]
    [ "$(cksum <"$FX/home/.chezmoidata/personal.yaml")" = "$before" ]
}

@test "bootstrap --yes warns before the chezmoi apply stub runs" {
    bs_fixture
    bs_hostfile linux-cli
    printf 'hostProfile: "linux-desktop"\ngui: true\n' >"$FX/home/.chezmoidata/personal.yaml"
    bs_nohost --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"detected host: linux-cli"* ]]
    grep -q '^chezmoi apply' "$CALLS"
    local warn_pos init_pos
    warn_pos="$(printf '%s' "$output" | grep -bo 'detected host: linux-cli' | head -n1 | cut -d: -f1)"
    init_pos="$(printf '%s' "$output" | grep -bo 'chezmoi init --source=' | head -n1 | cut -d: -f1)"
    [ -n "$warn_pos" ] && [ -n "$init_pos" ] && [ "$warn_pos" -lt "$init_pos" ]
}

@test "bootstrap stays quiet when personal.yaml agrees, or HOST_PROFILE is set" {
    bs_fixture
    bs_hostfile linux-cli
    printf 'hostProfile: "linux-cli"\ngui: false\n' >"$FX/home/.chezmoidata/personal.yaml"
    bs_nohost --dry-run
    [[ "$output" != *"detected host"* ]]
    printf 'hostProfile: "linux-desktop"\ngui: true\n' >"$FX/home/.chezmoidata/personal.yaml"
    bs --dry-run
    [[ "$output" != *"detected host"* ]]
}

@test "bootstrap dry-run on wsl: the preview and the switch name the same output (wsl without NixOS, wsl-nixos with it)" {
    bs_fixture
    BS_HOST=wsl bs --dry-run
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"home-manager switch -b hm-bak --flake $FX/nix#wsl "* || "$output" == *"home-manager switch -b hm-bak --flake $FX/nix#wsl"$'\n'* ]]
    [[ "$output" != *"wsl-nixos"* ]]
    : >"$BATS_TEST_TMPDIR/NIXOS"; export DETECT_HOST_NIXOS_MARKER="$BATS_TEST_TMPDIR/NIXOS"
    BS_HOST=wsl bs --dry-run
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"--flake $FX/nix#wsl-nixos"* ]]
    [[ "$output" == *"--dry-run"* ]]
}
