#!/usr/bin/env bats

setup() {
    REPORT="$BATS_TEST_DIRNAME/../../ops/macos-memory-report.sh"
}

@test "memory report help is available on any OS" {
    run /bin/bash "$REPORT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "memory report rejects options that could be mistaken for an apply mode" {
    run /bin/bash "$REPORT" --apply
    [ "$status" -eq 64 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "memory report refuses non-macOS hosts before probing" {
    uname() { printf 'Linux\n'; }
    export -f uname
    run /bin/bash "$REPORT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires macOS"* ]]
    [[ "$output" != *"Swap totals"* ]]
}

@test "memory report returns live aggregate measurements on macOS" {
    [[ "$(uname -s)" == Darwin ]] || skip "macOS probes unavailable"
    run /bin/bash "$REPORT"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'Physical memory (bytes) ==\n'* ]]
    [[ "$output" == *"System-wide memory free percentage:"* ]]
    [[ "$output" == *"Swap totals"* && "$output" == *"used ="* ]]
    [[ "$output" == *"VM counters"* && "$output" == *"Pages free:"* ]]
}
