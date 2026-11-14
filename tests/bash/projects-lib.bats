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

# --- T-0005: injection, error masking, exact tmux targets -------------------

lib() {
    bash -c '. "$1/ops/projects/lib.sh"; shift; "$@"' _ "$REPO_ROOT" "$@"
}

@test "proj_expand_path keeps \$(...) as data and does not execute it" {
    cd "$BATS_TEST_TMPDIR"
    run lib proj_expand_path '/x/$(touch probe)/y'
    [ "$status" -eq 0 ]
    [ "$output" = '/x/$(touch probe)/y' ]
    [ ! -e "$BATS_TEST_TMPDIR/probe" ]
}

@test "proj_expand_path keeps backticks as data" {
    cd "$BATS_TEST_TMPDIR"
    run lib proj_expand_path '/x/`touch probe`'
    [ "$output" = '/x/`touch probe`' ]
    [ ! -e "$BATS_TEST_TMPDIR/probe" ]
}

@test "proj_expand_path still expands ~, \$HOME and \${HOME}" {
    HOME=/h run lib proj_expand_path '~/a'
    [ "$output" = "/h/a" ]
    HOME=/h run lib proj_expand_path '$HOME/a/${HOME}'
    [ "$output" = "/h/a//h" ]
}

@test "proj_field preserves boolean false" {
    cat >"$PROJECTS_CONFIG" <<'EOF2'
projects:
  api: {enabled: false, on: true, dir: ~/a}
EOF2
    run field api enabled
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

@test "proj_field treats an id containing yq syntax as data" {
    cat >"$PROJECTS_CONFIG" <<'EOF2'
projects:
  api: {dir: ~/a}
  'a"b': {dir: ~/quoted}
EOF2
    run field 'a"b' dir
    [ "$status" -eq 0 ]
    [ "$output" = "~/quoted" ]
    run field 'nope" // .projects.api // "' dir
    [ -z "$output" ]
}

@test "proj_field rejects an invalid dotted path" {
    cat >"$PROJECTS_CONFIG" <<'EOF2'
projects:
  api: {dir: ~/a}
EOF2
    run field api 'dir | env'
    [ "$status" -ne 0 ]
}

@test "proj_yq returns non-zero on malformed YAML" {
    printf 'projects: [unclosed\n' >"$PROJECTS_CONFIG"
    run lib proj_yq '.projects'
    [ "$status" -ne 0 ]
    run field api dir
    [ "$status" -ne 0 ]
}

@test "proj_field_default does not substitute the default after a read failure" {
    printf 'projects: [unclosed\n' >"$PROJECTS_CONFIG"
    run lib proj_field_default api dir fallback
    [ "$status" -ne 0 ]
    [[ "$output" != *fallback* ]]
}

@test "proj_field_default keeps false and the string \"null\"; defaults only when missing" {
    cat >"$PROJECTS_CONFIG" <<'EOF2'
projects:
  api: {enabled: false, label: "null", dir: ~/a}
EOF2
    run lib proj_field_default api enabled true
    [ "$output" = "false" ]
    run lib proj_field_default api label dflt
    [ "$output" = "null" ]
    run lib proj_field_default api missing dflt
    [ "$output" = "dflt" ]
}

@test "proj_tmux_session and proj_layout_percent read values, default when missing, reject bad keys" {
    cat >"$PROJECTS_CONFIG" <<'EOF2'
tmux:
  master_session: mine
  layout: {left: 0}
EOF2
    run lib proj_tmux_session master_session dflt
    [ "$output" = "mine" ]
    run lib proj_tmux_session other dflt
    [ "$output" = "dflt" ]
    run lib proj_layout_percent left 50
    [ "$output" = "0" ]
    run lib proj_layout_percent right 50
    [ "$output" = "50" ]
    run lib proj_tmux_session 'x | env' dflt
    [ "$status" -ne 0 ]
    run lib proj_layout_percent 'x | env' 50
    [ "$status" -ne 0 ]
}

# Fake tmux that records its argv.
fake_tmux() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat >"$BATS_TEST_TMPDIR/bin/tmux" <<'EOF2'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TMUX_LOG"
EOF2
    chmod +x "$BATS_TEST_TMPDIR/bin/tmux"
    export TMUX_LOG="$BATS_TEST_TMPDIR/tmux.log"
    : >"$TMUX_LOG"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "tmux session targets are exact (=name)" {
    fake_tmux
    unset TMUX
    lib proj_tmux_session_exists dev
    lib proj_tmux_attach dev 0
    lib proj_tmux_pane_id dev win
    TMUX=/sock,1,0 lib proj_tmux_attach dev 0
    run cat "$TMUX_LOG"
    [[ "$output" == *"has-session -t =dev"* ]]
    [[ "$output" == *"attach-session -t =dev"* ]]
    [[ "$output" == *"display-message -p -t =dev:win"* ]]
    [[ "$output" == *"switch-client -t =dev"* ]]
}

@test "proj_tmux_attach honours detached=1 inside \$TMUX" {
    fake_tmux
    TMUX=/sock,1,0 run lib proj_tmux_attach dev 1
    [ "$status" -eq 0 ]
    [ ! -s "$TMUX_LOG" ]
}
