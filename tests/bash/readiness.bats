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

@test "NixOS linux-cli (work host): no Tailscale line, so Tailscale cannot make a rebuild pending" {
    HOST_PROFILE=linux-cli READINESS_ASSUME_NIXOS=1 PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"NixOS system layer"* ]]
    [[ "$output" != *"Tailscale"* ]]
}

@test "NixOS with no recorded host file: TODO to record it, no tailscaled rebuild loop" {
    unset HOST_PROFILE
    READINESS_ASSUME_NIXOS=1 PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"host profile not recorded"* ]]
    [[ "$output" != *"Tailscale daemon inactive"* ]]
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

@test "readiness cbm ui unit: activating on the first start (no restarts) says starting, with no TODO and no start advice" {
    cbm_stub activating 0
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"codebase-memory-mcp-ui.service is starting"* ]]
    [[ "$output" != *"[TODO] codebase-memory-mcp-ui"* ]]
    [[ "$output" != *"systemctl --user start"* ]]
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

# `chezmoi init --source=<repo>` (ops/install.sh) does not persist sourceDir, so
# on WSL a plain `chezmoi verify` fails with "stat ~/.local/share/chezmoi" and
# readiness reported pending changes. chezmoi_stub: verify fails unless the call
# carries --source=<repo root>; `source-path` fails like an unconfigured chezmoi.
chezmoi_stub() {
    cat >"$S/chezmoi" <<STUB
#!/bin/sh
case "\$*" in
  *source-path*) exit 1 ;;
  *--source=$REPO_ROOT\ verify*) exit 0 ;;
esac
echo "stat \$HOME/.local/share/chezmoi: no such file" >&2
exit 1
STUB
    chmod +x "$S/chezmoi"
    ln -s "$(command -v readlink)" "$S/readlink"
}

@test "readiness chezmoi: an unpersisted sourceDir is verified with --source=<repo>, not reported as drift" {
    chezmoi_stub
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[OK]   all managed dotfiles match"* ]]
    [[ "$output" != *"chezmoi has pending changes"* ]]
}

@test "readiness chezmoi: real drift is still a TODO" {
    cat >"$S/chezmoi" <<'STUB'
#!/bin/sh
case "$*" in *source-path*) exit 1 ;; esac
exit 1
STUB
    chmod +x "$S/chezmoi"; ln -s "$(command -v readlink)" "$S/readlink"
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[TODO] chezmoi has pending changes"* ]]
    # the advice must work on this host: unconfigured, so it names --source=<repo>
    [[ "$output" == *"run: chezmoi --source=$REPO_ROOT apply  or  sys-update"* ]]
}

@test "readiness chezmoi: a configured sourceDir equal to the repo is verified without --source" {
    cat >"$S/chezmoi" <<STUB
#!/bin/sh
case "\$*" in
  *source-path*) echo "$REPO_ROOT/home"; exit 0 ;;
  verify*) exit 0 ;;
esac
exit 1
STUB
    chmod +x "$S/chezmoi"; ln -s "$(command -v readlink)" "$S/readlink"
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"[OK]   all managed dotfiles match"* ]]
}

@test "readiness chezmoi: configured and drifting, the advice is a plain chezmoi apply" {
    cat >"$S/chezmoi" <<STUB
#!/bin/sh
case "\$*" in
  *source-path*) echo "$REPO_ROOT/home"; exit 0 ;;
esac
exit 1
STUB
    chmod +x "$S/chezmoi"; ln -s "$(command -v readlink)" "$S/readlink"
    PATH="$S" run bash "$SCRIPT"
    [[ "$output" == *"run: chezmoi apply  or  sys-update"* ]]
}
