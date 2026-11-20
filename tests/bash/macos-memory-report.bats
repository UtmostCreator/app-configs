#!/usr/bin/env bats

setup() {
    REPORT="$BATS_TEST_DIRNAME/../../ops/macos-memory-report.sh"
    # /bin/bash is bash 3.2 on macOS, the shell the report must support. NixOS
    # has no /bin/bash, so fall back to the bash on PATH there.
    BASH_BIN=/bin/bash
    [ -x "$BASH_BIN" ] || BASH_BIN="$(command -v bash)"
}

@test "memory report help is available on any OS" {
    run "$BASH_BIN" "$REPORT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "memory report rejects options that could be mistaken for an apply mode" {
    run "$BASH_BIN" "$REPORT" --apply
    [ "$status" -eq 64 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "memory report refuses non-macOS hosts before probing" {
    uname() { printf 'Linux\n'; }
    export -f uname
    run "$BASH_BIN" "$REPORT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires macOS"* ]]
    [[ "$output" != *"Swap totals"* ]]
}

@test "memory report returns live aggregate measurements on macOS" {
    [[ "$(uname -s)" == Darwin ]] || skip "macOS probes unavailable"
    run "$BASH_BIN" "$REPORT"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'Physical memory (bytes) ==\n'* ]]
    [[ "$output" == *"System-wide memory free percentage:"* ]]
    [[ "$output" == *"Swap totals"* && "$output" == *"used ="* ]]
    [[ "$output" == *"VM counters"* && "$output" == *"Pages free:"* ]]
}
