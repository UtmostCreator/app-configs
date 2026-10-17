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
