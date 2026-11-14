#!/usr/bin/env bats
# A broken or empty projects config must fail loudly instead of looking like
# "zero projects, all healthy", and a configured `false` must survive
# proj_field_default.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    command -v yq >/dev/null 2>&1 || skip "yq not installed"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset TMUX
    export PROJECTS_CONFIG="$BATS_TEST_TMPDIR/config.yaml"
}

lib() { bash -c '. "$1/ops/projects/lib.sh"; shift; "$@"' _ "$REPO_ROOT" "$@"; }

@test "proj_ids fails on malformed YAML" {
    printf 'projects: [unclosed\n  api: {\n' >"$PROJECTS_CONFIG"
    run lib proj_ids
    [ "$status" -ne 0 ]
}

@test "proj_ids fails when there is no projects key" {
    printf 'tmux: {master_session: x}\n' >"$PROJECTS_CONFIG"
    run lib proj_ids
    [ "$status" -ne 0 ]
    [[ "$output" == *"no projects"* ]]
}

@test "proj_ids fails on an empty projects map" {
    printf 'projects: {}\n' >"$PROJECTS_CONFIG"
    run lib proj_ids
    [ "$status" -ne 0 ]
}

@test "proj_yq propagates a yq error" {
    printf 'a: [unclosed\n' >"$PROJECTS_CONFIG"
    run lib proj_yq '.a'
    [ "$status" -ne 0 ]
}

@test "proj_field_default keeps a configured false" {
    printf 'projects:\n  api: {dir: ~/a, flag: false, other: true}\n' >"$PROJECTS_CONFIG"
    run lib proj_field_default api flag true
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
    run lib proj_field_default api missing true
    [ "$output" = "true" ]
    run lib proj_field_default api other false
    [ "$output" = "true" ]
}

@test "sync-main exits non-zero on malformed config instead of syncing nothing" {
    printf 'projects: [unclosed\n' >"$PROJECTS_CONFIG"
    run bash "$REPO_ROOT/ops/projects/github/sync-main.sh"
    [ "$status" -ne 0 ]
}

@test "sync-main exits non-zero when no projects are configured" {
    printf 'tmux: {}\n' >"$PROJECTS_CONFIG"
    run bash "$REPO_ROOT/ops/projects/github/sync-main.sh"
    [ "$status" -ne 0 ]
}

@test "health run reports a failure on malformed config" {
    command -v jq >/dev/null || skip "jq not installed"
    printf 'projects: [unclosed\n' >"$PROJECTS_CONFIG"
    run bash "$REPO_ROOT/ops/projects/health/run.sh" --json
    [ "$status" -ne 0 ]
}
