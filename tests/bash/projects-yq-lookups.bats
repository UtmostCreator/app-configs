#!/usr/bin/env bats
# T-0028: caller-side yq lookups in ops/projects must pass values via strenv(),
# never interpolate them into the yq expression.
#
# Run:  bats tests/bash/projects-yq-lookups.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    P="$REPO_ROOT/ops/projects"
    command -v yq >/dev/null 2>&1 || skip "yq not installed"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    export PROJECTS_CONFIG="$BATS_TEST_TMPDIR/config.yaml"
    unset TMUX
    STUBS="$BATS_TEST_TMPDIR/bin"
    LOG="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$HOME" "$STUBS"
    : >"$LOG"
}

@test "health lib: a project id containing yq syntax is looked up as data" {
    cat >"$PROJECTS_CONFIG" <<'EOF'
projects:
  'a"b':
    health: { checks: [web] }
  plain:
    health: { checks: [other] }
EOF
    run bash -c 'source "$1/health/lib.sh"; proj_health_for_each_project web' _ "$P"
    [ "$status" -eq 0 ]
    [ "$output" = 'a"b' ]
}

@test "pr-watch: event lookup passes the name via strenv, not interpolation" {
    run grep -F 'events.\"$name\"' "$P/github/pr-watch.sh"
    [ "$status" -ne 0 ]
    grep -Fq 'strenv' "$P/github/pr-watch.sh"
}
