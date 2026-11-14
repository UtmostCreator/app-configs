#!/usr/bin/env bats
# Non-bats test suites, run here so they are part of test:bash, ops/ci.sh and
# CI. They used to run only when someone remembered the commands in the docs.
# php and python3 come from nix/modules/home/dev.nix and ops/ci-packages.txt,
# so a missing interpreter is a failure, not a skip.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "log-errors PHP unit checks pass (ops/projects/logging/test/log-errors-unit.php)" {
    command -v php >/dev/null || { echo "php not found (dev.nix provides it)"; return 1; }
    run php "$REPO_ROOT/ops/projects/logging/test/log-errors-unit.php"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" =~ 1\.\.[0-9]+ ]]
    [[ "$output" != *"not ok"* ]]
}

@test "health runner Python tests pass (ops/projects/health/test_health.py)" {
    command -v python3 >/dev/null || { echo "python3 not found"; return 1; }
    run env PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
        -s "$REPO_ROOT/ops/projects/health" -p 'test_health.py'
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"OK"* ]]
}
