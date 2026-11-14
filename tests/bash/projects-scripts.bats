#!/usr/bin/env bats
# Regression tests for ops/projects scripts (T-0006): tmux ssh alias handling,
# master.sh argument order and pr-watch event detection.
#
# tmux, gh and the bell players are PATH stubs; HOME and the config are
# scratch. Nothing here touches a real tmux server or GitHub.
#
# Run:  bats tests/bash/projects-scripts.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    P="$REPO_ROOT/ops/projects"
    command -v yq >/dev/null 2>&1 || skip "yq not installed"
    command -v jq >/dev/null 2>&1 || skip "jq not installed"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    export PROJECTS_CONFIG="$BATS_TEST_TMPDIR/config.yaml"
    STUBS="$BATS_TEST_TMPDIR/bin"
    LOG="$BATS_TEST_TMPDIR/calls.log"
    STATE_FILE="$XDG_STATE_HOME/projects/pr-watch-state.json"
    mkdir -p "$HOME" "$STUBS"
    : >"$LOG"
}

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

# tmux stub: log every call; has-session reports "no session".
stub_tmux() {
    stub tmux 'printf "%s\n" "$*" >>"'"$LOG"'"
case "$1" in
  has-session) exit 1 ;;
  display-message|split-window) echo "%1" ;;
esac
exit 0'
}

@test "ssh.sh: an alias with shell syntax is rejected before any pane exists" {
    stub_tmux
    cat >"$PROJECTS_CONFIG" <<'EOF'
ssh_workspace:
  hosts: ["evil; touch pwned"]
EOF
    run env PATH="$STUBS:$PATH" bash "$P/tmux/ssh.sh" --detached
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid ssh alias"* ]]
    ! grep -q 'new-session\|send-keys' "$LOG"
}

@test "ssh.sh: a valid alias is sent after -- so a leading dash is not an option" {
    stub_tmux
    cat >"$PROJECTS_CONFIG" <<'EOF'
ssh_workspace:
  hosts: ["-Jhost", "user@host.example:22"]
EOF
    run env PATH="$STUBS:$PATH" bash "$P/tmux/ssh.sh" --detached
    [ "$status" -eq 0 ]
    grep -Fq 'send-keys -t %1 ssh -- -Jhost Enter' "$LOG"
    grep -Fq 'ssh -- user@host.example:22 Enter' "$LOG"
}

@test "master.sh: --force with a later invalid arg does not kill the session" {
    stub_tmux
    run env PATH="$STUBS:$PATH" bash "$P/tmux/master.sh" --force --invalid
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown argument: --invalid"* ]]
    ! grep -q 'kill-session' "$LOG"
}

@test "master.sh: --force with valid args still kills the session" {
    stub_tmux
    run env PATH="$STUBS:$PATH" bash "$P/tmux/master.sh" --force --detached
    grep -q 'kill-session' "$LOG"
}

