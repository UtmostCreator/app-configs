#!/usr/bin/env bats
# Tests for ops/projects/lib.sh proj_ids — pane order for the tmux layout.
#
# chezmoi renders ~/.config/projects/config.yaml through toYaml, which sorts
# map keys, so declaration order under `projects:` does not survive. An
# explicit `project_order` list is the source of truth when present.
#
# Run:  bats tests/bash/projects-lib.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    command -v yq >/dev/null 2>&1 || skip "yq not installed"
    export PROJECTS_CONFIG="$BATS_TEST_TMPDIR/config.yaml"
}

ids() {
    bash -c '. "$1/ops/projects/lib.sh"; proj_ids' _ "$REPO_ROOT"
}

@test "proj_ids follows project_order, not the (sorted) map keys" {
    cat >"$PROJECTS_CONFIG" <<'EOF'
project_order: [cms, frontend, api]
projects:
  api: {dir: ~/a}
  cms: {dir: ~/c}
  frontend: {dir: ~/f}
EOF
    run ids
    [ "$status" -eq 0 ]
    [ "$output" = $'cms\nfrontend\napi' ]
}

@test "proj_ids falls back to project keys without project_order" {
    cat >"$PROJECTS_CONFIG" <<'EOF'
projects:
  api: {dir: ~/a}
  cms: {dir: ~/c}
EOF
    run ids
    [ "$status" -eq 0 ]
    [ "$output" = $'api\ncms' ]
}

@test "config template passes project_order through to the rendered file" {
    grep -q 'hasKey . "project_order"' "$REPO_ROOT/home/dot_config/projects/config.yaml.tmpl"
}

field() {
    bash -c '. "$1/ops/projects/lib.sh"; proj_field "$2" "$3"' _ "$REPO_ROOT" "$1" "$2"
}

@test "proj_field reads a present key and is empty for a missing one" {
    cat >"$PROJECTS_CONFIG" <<'EOF2'
projects:
  api: {dir: ~/a}
EOF2
    run field api dir
    [ "$status" -eq 0 ]
    [ "$output" = "~/a" ]

    run field api missing
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "every WS_SCRIPT_* path in workspace/config.sh points at an existing script" {
    WS_SCRIPTS_DIR="$REPO_ROOT/ops/projects/workspace"
    # shellcheck source=/dev/null
    source "$REPO_ROOT/ops/projects/workspace/config.sh"
    missing=""
    for v in $(compgen -v WS_SCRIPT_); do
        [ -e "${!v}" ] || missing+=" $v=${!v}"
    done
    [ -z "$missing" ] || { echo "missing:$missing"; return 1; }
}
