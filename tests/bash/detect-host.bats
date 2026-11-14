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
    INTEROP="$BATS_TEST_TMPDIR/WSLInterop"
    WSLRUN="$BATS_TEST_TMPDIR/run-WSL"
    export DETECT_HOST_PROC_VERSION="$PROC" DETECT_HOST_OSRELEASE="$OSREL"
    export DETECT_HOST_WSL_INTEROP="$INTEROP" DETECT_HOST_WSL_RUN="$WSLRUN"
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
    [ "$status" -eq 0 ]
    [ "$output" = 1 ]
    kernel 6.6.87.2-microsoft-standard-WSL2
    detect --wsl-version
    [ "$status" -eq 0 ]
    [ "$output" = 2 ]
    kernel 6.18.33
    detect --wsl-version
    [ "$status" -eq 0 ]
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

@test "custom-named WSL2 kernel with WSL_DISTRO_NAME and WSLInterop marker is wsl" {
    kernel 6.6.36-custom
    : >"$INTEROP"
    WSL_DISTRO_NAME=Ubuntu detect
    [ "$status" -eq 0 ]
    [ "$output" = wsl ]
}

@test "custom-named WSL2 kernel with WSL_DISTRO_NAME and /run/WSL marker is wsl" {
    kernel 6.6.36-custom
    : >"$WSLRUN"
    WSL_DISTRO_NAME=Ubuntu detect
    [ "$output" = wsl ]
}

@test "WSL_DISTRO_NAME without a filesystem marker is ambiguous (inherited env)" {
    kernel 6.6.36-custom
    WSL_DISTRO_NAME=Ubuntu detect
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [[ "$stderr" == *ambiguous* ]]
    [[ "$stderr" == *"HOST_PROFILE=wsl"* ]]
}

@test "unmarked microsoft release on a 5.x+ kernel is ambiguous, no WSL1 hint" {
    kernel 6.1.0-Microsoft-custom
    detect
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [[ "$stderr" == *ambiguous* ]]
    [[ "$stderr" != *"set-version"* ]]
}

@test "conflicting WSL1 and WSL2 markers are ambiguous" {
    echo 4.4.0-19041-Microsoft >"$OSREL"
    echo 'Linux version 6.6.87.2-microsoft-standard-WSL2 (b@h) #1' >"$PROC"
    detect
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [[ "$stderr" == *ambiguous* ]]
}

@test "explicit HOST_PROFILE values are echoed" {
    for p in macos linux-desktop linux-cli wsl; do
        HOST_PROFILE=$p detect
        [ "$status" -eq 0 ]
        [ "$output" = "$p" ]
    done
}

@test "--wsl-version is none with exit 0 on macOS" {
    OSTYPE=darwin23 detect --wsl-version
    [ "$status" -eq 0 ]
    [ "$output" = none ]
}

@test "WSL_DISTRO_NAME with an old unmarked kernel is ambiguous and fails" {
    kernel 4.4.0-custom
    : >"$INTEROP"
    WSL_DISTRO_NAME=Ubuntu detect
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [[ "$stderr" == *ambiguous* ]]
}

@test "unknown argument is rejected" {
    kernel 6.18.33
    detect --wsl-verison
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    [[ "$stderr" == *"unknown argument"* ]]
}

@test "extra argument after --wsl-version is rejected" {
    kernel 6.18.33
    detect --wsl-version extra
    [ "$status" -eq 2 ]
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
