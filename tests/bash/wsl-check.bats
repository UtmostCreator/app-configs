#!/usr/bin/env bats
# ops/wsl-check.sh prints "OK <msg>" / "TODO <msg>" lines for sys-readiness.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/wsl-check.sh"
    STUBS="$BATS_TEST_TMPDIR/bin"
    WIN="$BATS_TEST_TMPDIR/mnt/c/Program Files/nodejs"
    mkdir -p "$STUBS" "$WIN"
    for t in bash cat grep sed head; do ln -s "$(command -v "$t")" "$STUBS/$t"; done
    printf 'systemd\n' >"$BATS_TEST_TMPDIR/comm"
    export WSL_CHECK_PROC1_COMM="$BATS_TEST_TMPDIR/comm"
    export WSL_CHECK_REPO_ROOT="$HOME/app-configs"
    export WSL_CHECK_WINDOWS_PREFIX="$BATS_TEST_TMPDIR/mnt/"
    printf 'Linux version 6.6.87.2-microsoft-standard-WSL2 #1 SMP\n' >"$BATS_TEST_TMPDIR/version"
    export DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/version"
}

check() { PATH="$1" run "$STUBS/bash" "$SCRIPT"; }

@test "healthy host reports only OK lines" {
    printf '#!/bin/sh\n' >"$STUBS/clip.exe"; chmod +x "$STUBS/clip.exe"
    check "$STUBS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK systemd"* ]]
    ! grep -q '^TODO' <<<"$output"
}

@test "systemd off is a TODO naming wsl.conf" {
    printf 'init\n' >"$WSL_CHECK_PROC1_COMM"
    check "$STUBS"
    grep -q '^TODO .*systemd=true.*/etc/wsl.conf' <<<"$output"
}

@test "repo on a Windows drive is a TODO" {
    WSL_CHECK_REPO_ROOT="${WSL_CHECK_WINDOWS_PREFIX}c/Users/me/app-configs" check "$STUBS"
    grep -q '^TODO .*Windows drive' <<<"$output"
}

@test "Windows npm shadowing the Linux one is a TODO" {
    printf '#!/bin/sh\n' >"$WIN/npm"; chmod +x "$WIN/npm"
    check "$WIN:$STUBS"
    grep -q '^TODO npm resolves to the Windows' <<<"$output"
}

@test "Linux npm ahead of Windows npm is fine" {
    printf '#!/bin/sh\n' >"$WIN/npm"; chmod +x "$WIN/npm"
    printf '#!/bin/sh\n' >"$STUBS/npm"; chmod +x "$STUBS/npm"
    check "$STUBS:$WIN"
    ! grep -q '^TODO npm' <<<"$output"
}

@test "missing clip.exe (interop off) is a TODO" {
    check "$STUBS"
    grep -q '^TODO .*clip.exe' <<<"$output"
}

@test "WSL2 kernel is reported OK" {
    check "$STUBS"
    grep -q '^OK WSL2' <<<"$output"
}

@test "WSL1 kernel is a TODO with the conversion command" {
    printf 'Linux version 4.4.0-19041-Microsoft (Microsoft@Microsoft.com) #1237-Microsoft\n' >"$DETECT_HOST_PROC_VERSION"
    check "$STUBS"
    grep -q '^TODO .*WSL1.*wsl --set-version' <<<"$output"
}

@test "docker CLI without a reachable daemon is a TODO" {
    printf '#!/bin/sh\nexit 1\n' >"$STUBS/docker"; chmod +x "$STUBS/docker"
    ln -sf "$(command -v timeout)" "$STUBS/timeout"
    check "$STUBS"
    grep -q '^TODO .*Docker daemon' <<<"$output"
}

@test "docker with a reachable daemon is OK" {
    printf '#!/bin/sh\nexit 0\n' >"$STUBS/docker"; chmod +x "$STUBS/docker"
    ln -sf "$(command -v timeout)" "$STUBS/timeout"
    check "$STUBS"
    grep -q '^OK Docker daemon reachable' <<<"$output"
}
