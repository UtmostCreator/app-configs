#!/usr/bin/env bats
# Bootstrap safety for macOS and WSL: host detection, chezmoi source
# resolution for both documented clone locations, and first-install behaviour.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    PROC="$BATS_TEST_TMPDIR/version"
}

fake_uname() {
    printf '#!/bin/sh\necho %s\n' "$1" >"$STUBS/uname"
    chmod +x "$STUBS/uname"
}

detect() {
    PATH="$STUBS:$PATH" DETECT_HOST_PROC_VERSION="$PROC" run env -u HOST_PROFILE \
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
