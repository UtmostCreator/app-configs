#!/usr/bin/env bats
# Tests for nix/modules/home/scripts/sync-open.sh.
#
# Regression: sync-open ran xdg-open even when the Web UI never became ready
# (opening a "connection refused" tab) and its wait was not bounded by one
# overall deadline. Now: ready -> xdg-open; not ready by the deadline -> exit 1,
# no xdg-open.
#
# systemctl, curl, xdg-open and sleep are stubbed on PATH.
#
# Run:  bats tests/bash/sync-open.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/nix/modules/home/scripts/sync-open.sh"
    [ -f "$SCRIPT" ]

    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"

    printf '#!/usr/bin/env bash\necho "systemctl $*" >>"$CALLS"\nexit 0\n' >"$STUBS/systemctl"
    printf '#!/usr/bin/env bash\necho "xdg-open $*" >>"$CALLS"\n' >"$STUBS/xdg-open"
    # curl prints CURL_CODE (default 200) as %{http_code} when CURL_OK=1, else
    # "000" and exit 7 (connection failure), like the real tool.
    printf '#!/usr/bin/env bash\necho curl >>"$CALLS"\nif [ "${CURL_OK:-0}" = 1 ]; then printf "%%s" "${CURL_CODE:-200}"; else printf 000; exit 7; fi\n' >"$STUBS/curl"
    # sleep really waits 1s per call so the SECONDS-based deadline is exercised
    # without a long test.
    REAL_SLEEP="$(command -v sleep)"
    printf '#!/usr/bin/env bash\n%s 1\n' "$REAL_SLEEP" >"$STUBS/sleep"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
}

@test "opens the UI when it is ready" {
    CURL_OK=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q '^xdg-open http://127.0.0.1:8384/$' "$CALLS"
}

@test "does not open the UI and exits 1 when it never becomes ready" {
    SYNC_OPEN_TIMEOUT=2 CURL_OK=0 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not ready after 2s"* ]]
    ! grep -q xdg-open "$CALLS"
}

@test "the wait is bounded by the overall deadline" {
    start=$SECONDS
    SYNC_OPEN_TIMEOUT=2 CURL_OK=0 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [ $((SECONDS - start)) -le 6 ]
}

@test "rejects a non-numeric timeout" {
    SYNC_OPEN_TIMEOUT=abc run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    ! grep -q xdg-open "$CALLS"
}

@test "a login-protected UI (HTTP 401) counts as ready" {
    CURL_OK=1 CURL_CODE=401 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q '^xdg-open ' "$CALLS"
}

@test "a leading-zero timeout is decimal, not an octal error" {
    SYNC_OPEN_TIMEOUT=01 CURL_OK=0 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not ready after 1s"* ]]
}

@test "08 is accepted as decimal" {
    CURL_OK=1 SYNC_OPEN_TIMEOUT=08 run bash "$SCRIPT"
    # Octal parsing would abort with "value too great for base".
    [[ "$output" != *"value too great"* ]]
    [ "$status" -eq 0 ]
    grep -q '^xdg-open ' "$CALLS"
}
