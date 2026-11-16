#!/usr/bin/env bats
# ops/readiness.sh owns installed-state checks: nix, chezmoi, mise,
# home-manager, lefthook, jq, yq and a secret scanner (fail-closed, like the
# pre-commit hook).

bats_require_minimum_version 1.5.0

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/readiness.sh"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    S="$BATS_TEST_TMPDIR/bin"; mkdir -p "$S"
    for t in bash cat grep sed head cut wc dirname uname git tr; do
        ln -s "$(command -v "$t")" "$S/$t"
    done
    unset APP_CONFIGS_ALLOW_MISSING_SCANNER
    export HOST_PROFILE=linux-cli USER=tester
}

stub() { printf '#!/bin/sh\nexit 0\n' >"$S/$1"; chmod +x "$S/$1"; }

@test "missing jq and yq are required failures" {
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[MISS] jq missing"* ]]
    [[ "$output" == *"[MISS] yq missing"* ]]
}

@test "missing secret scanner is a failure matching the pre-commit policy" {
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[MISS] no secret scanner"* ]]
}

@test "scanner present passes; APP_CONFIGS_ALLOW_MISSING_SCANNER downgrades" {
    stub gitleaks
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[OK]   gitleaks"* ]]
    rm "$S/gitleaks"
    APP_CONFIGS_ALLOW_MISSING_SCANNER=1 PATH="$S" run bash "$SCRIPT"
    [[ "$output" != *"[MISS] no secret scanner"* ]]
    [[ "$output" == *"[TODO] no secret scanner"* ]]
}

@test "unknown argument is rejected on stderr with exit 2" {
    run --separate-stderr bash "$SCRIPT" --bogus
    [ "$status" -eq 64 ]
    [[ "$stderr" == *"unknown argument"* ]]
}

# The NixOS system block (READINESS_ASSUME_NIXOS=1 is a test seam that skips the
# host OS probe). With every tool absent from PATH its systemctl/nix checks are
# [TODO]; only the Tailscale line differs between profiles.
@test "NixOS desktop host still asks for the Tailscale daemon" {
    HOST_PROFILE=linux-desktop READINESS_ASSUME_NIXOS=1 PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"Tailscale daemon inactive"* ]]
}

@test "NixOS-WSL: no Tailscale line, so Tailscale cannot make a rebuild pending" {
    HOST_PROFILE=wsl READINESS_ASSUME_NIXOS=1 PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"NixOS system layer"* ]]
    [[ "$output" != *"Tailscale"* ]]
}

# CBM UI user unit (nix/modules/home/dev.nix). A unit that loops in
# `activating` (Restart=always) never reaches `failed`, so the check reads
# NRestarts too. cbm_stub <ActiveState> <NRestarts> installs a `systemctl`
# stub answering `show`.
cbm_stub() {
    cat >"$S/systemctl" <<STUB
#!/bin/sh
case "\$*" in
  *show*) printf 'ActiveState=$1\nNRestarts=$2\n' ;;
esac
exit 0
STUB
    chmod +x "$S/systemctl"
}

@test "readiness cbm ui unit: active is OK" {
    cbm_stub active 0
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[OK]   codebase-memory-mcp-ui.service active"* ]]
}

@test "readiness cbm ui unit: activating with restarts is a TODO naming the restart loop" {
    cbm_stub activating 7
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[TODO] codebase-memory-mcp-ui.service is restart-looping (activating, 7 restarts;"* ]]
    [[ "$output" == *"journalctl --user -u codebase-memory-mcp-ui"* ]]
}

@test "readiness cbm ui unit: activating on the first start (no restarts) is noted, not a loop" {
    cbm_stub activating 0
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[TODO] codebase-memory-mcp-ui.service activating (run: systemctl --user start codebase-memory-mcp-ui)"* ]]
    [[ "$output" != *"restart-looping"* ]]
}

@test "readiness cbm ui unit: inactive is a TODO with the start command" {
    cbm_stub inactive 0
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[TODO] codebase-memory-mcp-ui.service inactive (run: systemctl --user start codebase-memory-mcp-ui)"* ]]
}

@test "readiness cbm ui unit: failed is a TODO" {
    cbm_stub failed 3
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[TODO] codebase-memory-mcp-ui.service failed"* ]]
}

@test "readiness cbm ui unit: absent unit is skipped silently" {
    cat >"$S/systemctl" <<'STUB'
#!/bin/sh
case "$*" in
  *show*) printf 'ActiveState=inactive\nNRestarts=0\nLoadState=not-found\n' ;;
esac
exit 0
STUB
    chmod +x "$S/systemctl"
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" != *"codebase-memory-mcp-ui"* ]]
}

@test "readiness cbm ui unit: no systemctl, or no running user manager, is skipped" {
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" != *"codebase-memory-mcp-ui"* ]]
    # the real `show` prints nothing and exits 1 without a user manager
    printf '#!/bin/sh\nexit 1\n' >"$S/systemctl"
    chmod +x "$S/systemctl"
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" != *"codebase-memory-mcp-ui"* ]]
}

@test "readiness cbm ui unit: macOS (no systemd) is skipped even with a systemctl on PATH" {
    cbm_stub activating 9
    rm "$S/uname"; printf '#!/bin/sh\necho Darwin\n' >"$S/uname"; chmod +x "$S/uname"
    HOST_PROFILE=macos PATH="$S" run bash "$SCRIPT"
    [[ "$output" != *"codebase-memory-mcp-ui"* ]]
}
