#!/usr/bin/env bats
# Non-bats test suites, run here so they are part of test:bash, ops/ci.sh and
# CI. They used to run only when someone remembered the commands in the docs.
# python3 comes from nix/modules/home/dev.nix and ops/ci-packages.txt, so a
# missing interpreter is a failure, not a skip.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "health runner Python tests pass (ops/projects/health/test_health.py)" {
    command -v python3 >/dev/null || { echo "python3 not found"; return 1; }
    run env PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
        -s "$REPO_ROOT/ops/projects/health" -p 'test_health.py'
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"OK"* ]]
}
