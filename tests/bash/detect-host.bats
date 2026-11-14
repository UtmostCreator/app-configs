#!/usr/bin/env bats
# ops/detect-host.sh: profile detection, WSL1/WSL2 classification, input
# validation and failure behaviour (T-0013).

bats_require_minimum_version 1.5.0

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    PROC="$BATS_TEST_TMPDIR/version"
    OSREL="$BATS_TEST_TMPDIR/osrelease"
    export DETECT_HOST_PROC_VERSION="$PROC" DETECT_HOST_OSRELEASE="$OSREL"
    unset HOST_PROFILE HOST_PROFILE_DEFAULT WSL_DISTRO_NAME
    printf '#!/bin/sh\necho Linux\n' >"$STUBS/uname"
    chmod +x "$STUBS/uname"
}

detect() { PATH="$STUBS:$PATH" run --separate-stderr bash "$REPO_ROOT/ops/detect-host.sh" "$@"; }

kernel() { # kernel <release>
    echo "$1" >"$OSREL"
    echo "Linux version $1 (builder@host) (gcc) #1 SMP" >"$PROC"
}

@test "plain Linux is linux-desktop" {
    kernel 6.18.33
    detect
    [ "$status" -eq 0 ]
    [ "$output" = linux-desktop ]
}

@test "HOST_PROFILE_DEFAULT=linux-cli is honoured" {
    kernel 6.18.33
    HOST_PROFILE_DEFAULT=linux-cli detect
    [ "$status" -eq 0 ]
    [ "$output" = linux-cli ]
}

@test "invalid HOST_PROFILE_DEFAULT is rejected, not echoed" {
    kernel 6.18.33
    HOST_PROFILE_DEFAULT=bogus detect
    [ "$status" -ne 0 ]
    [ -z "$output" ]
    [[ "$stderr" == *HOST_PROFILE_DEFAULT* ]]
}

@test "WSL2 kernel is wsl" {
    kernel 6.6.87.2-microsoft-standard-WSL2
    detect
    [ "$status" -eq 0 ]
    [ "$output" = wsl ]
}

@test "WSL1 kernel is rejected in profile mode" {
    kernel 4.4.0-19041-Microsoft
    detect
    [ "$status" -ne 0 ]
    [ -z "$output" ]
    [[ "$stderr" == *WSL1* ]]
}

@test "--wsl-version reports 1 for WSL1, 2 for WSL2, none otherwise" {
    kernel 4.4.0-19041-Microsoft
    detect --wsl-version
    [ "$output" = 1 ]
    kernel 6.6.87.2-microsoft-standard-WSL2
    detect --wsl-version
    [ "$output" = 2 ]
    kernel 6.18.33
    detect --wsl-version
    [ "$output" = none ]
}

@test "unrelated 'wsl' or 'microsoft' text in /proc/version is not WSL" {
    echo 6.18.33 >"$OSREL"
    echo 'Linux version 6.18.33 (wsl-builder@microsoft-ci) (gcc) #1 SMP' >"$PROC"
    detect
    [ "$status" -eq 0 ]
    [ "$output" = linux-desktop ]
}

@test "missing /proc/version and osrelease fail with a diagnostic" {
    rm -f "$PROC" "$OSREL"
    detect
    [ "$status" -ne 0 ]
    [ -z "$output" ]
    [ -n "$stderr" ]
}

@test "osrelease alone is enough when /proc/version is missing" {
    echo 6.6.87.2-microsoft-standard-WSL2 >"$OSREL"
    rm -f "$PROC"
    detect
    [ "$output" = wsl ]
}

@test "custom-named WSL2 kernel with WSL_DISTRO_NAME is wsl" {
    kernel 6.6.36-custom
    WSL_DISTRO_NAME=Ubuntu detect
    [ "$status" -eq 0 ]
    [ "$output" = wsl ]
}

@test "WSL_DISTRO_NAME with an old unmarked kernel is ambiguous and fails" {
    kernel 4.4.0-custom
    WSL_DISTRO_NAME=Ubuntu detect
    [ "$status" -ne 0 ]
    [[ "$stderr" == *ambiguous* ]]
}

@test "unknown argument is rejected" {
    kernel 6.18.33
    detect --wsl-verison
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"unknown argument"* ]]
}

@test "extra argument after --wsl-version is rejected" {
    kernel 6.18.33
    detect --wsl-version extra
    [ "$status" -ne 0 ]
}

@test "Darwin is macos" {
    printf '#!/bin/sh\necho Darwin\n' >"$STUBS/uname"
    rm -f "$PROC" "$OSREL"
    detect
    [ "$output" = macos ]
}

@test "unsupported OS fails with a diagnostic" {
    printf '#!/bin/sh\necho FreeBSD\n' >"$STUBS/uname"
    detect
    [ "$status" -ne 0 ]
    [ -n "$stderr" ]
}

@test "HOST_PROFILE override is validated" {
    HOST_PROFILE=wsl detect
    [ "$output" = wsl ]
    HOST_PROFILE=windows detect
    [ "$status" -ne 0 ]
}
