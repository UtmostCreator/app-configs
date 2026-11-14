#!/usr/bin/env bats
# Tests for ops/run-bats.sh, the body of the `mise run test:bash` task.
#
# Run:  bats tests/bash/run-bats.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/run-bats.sh"
    STUB="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB"
    local t
    for t in bash env dirname; do
        ln -sf "$(command -v "$t")" "$STUB/$t"
    done
}

@test "mise test:bash task delegates to ops/run-bats.sh" {
    run grep -A4 '^\[tasks."test:bash"\]' "$REPO_ROOT/mise.toml"
    [[ "$output" == *"bash ops/run-bats.sh"* ]]
}

@test "run-bats fails with an install hint when bats is missing" {
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"bats not found"* ]]
    [[ "$output" == *"sys-update"* ]]
}

@test "run-bats runs bats on tests/bash and propagates its status" {
    printf '#!/usr/bin/env bash\necho "bats-stub $*"\nexit 3\n' >"$STUB/bats"
    chmod +x "$STUB/bats"
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -eq 3 ]
    [[ "$output" == *"bats-stub tests/bash"* ]]
}
