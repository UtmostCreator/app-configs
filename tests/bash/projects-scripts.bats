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

pr_watch_setup() {
    # Players only drop a marker: the real script backgrounds them.
    stub afplay 'touch "'"$BATS_TEST_TMPDIR"'/bell"'
    stub paplay 'touch "'"$BATS_TEST_TMPDIR"'/bell"'
    cat >"$PROJECTS_CONFIG" <<'EOF'
github:
  pr_watch:
    enabled: true
    include_repos: [org/repo]
    events:
      pr_merged: { enabled: true }
EOF
    mkdir -p "$XDG_STATE_HOME/projects"
    echo '{"org/repo#7":{"review":"NONE","ci":"NONE","mergeable":"UNKNOWN","updatedAt":"x"}}' \
        >"$STATE_FILE"
}

# Positive bell check: the player runs in the background, so wait up to 5s.
wait_bell() {
    local _
    for _ in $(seq 50); do
        [ -f "$BATS_TEST_TMPDIR/bell" ] && return 0
        sleep 0.1
    done
    return 1
}

# stub_gh <state>: no open PRs; `gh pr view` prints <state>.
stub_gh() {
    stub gh 'case "$2" in list) echo "[]" ;; view) echo "'"$1"'" ;; esac'
}

@test "pr-watch: closure is reported even when no PRs are open" {
    pr_watch_setup
    stub_gh MERGED
    run env PATH="$STUBS:$PATH" bash "$P/github/pr-watch.sh" --once
    [ "$status" -eq 0 ]
    [[ "$output" == *"[pr-watch][MERGED]"*"org/repo#7"* ]]
    run jq -r 'keys | length' "$STATE_FILE"
    [ "$output" = "0" ]
}

@test "pr-watch: merged PR rings pr_merged" {
    pr_watch_setup
    stub_gh MERGED
    run env PATH="$STUBS:$PATH" bash "$P/github/pr-watch.sh" --once
    wait_bell
}

@test "pr-watch: closed-unmerged PR is reported, dropped, and does not fire pr_merged" {
    pr_watch_setup
    stub_gh CLOSED
    run env PATH="$STUBS:$PATH" bash "$P/github/pr-watch.sh" --once
    [ "$status" -eq 0 ]
    [[ "$output" == *"[pr-watch][CLOSED]"*"org/repo#7"* ]]
    sleep 0.5
    [ ! -f "$BATS_TEST_TMPDIR/bell" ]
    run jq -r 'keys | length' "$STATE_FILE"
    [ "$output" = "0" ]
}

@test "pr-watch: a failing gh pr list leaves state untouched and rings nothing" {
    pr_watch_setup
    before="$(cat "$STATE_FILE")"
    stub gh 'exit 1'
    run env PATH="$STUBS:$PATH" bash "$P/github/pr-watch.sh" --once
    [ "$status" -eq 0 ]
    [[ "$output" != *"[pr-watch]"* ]]
    [ "$(cat "$STATE_FILE")" = "$before" ]
    sleep 0.5
    [ ! -f "$BATS_TEST_TMPDIR/bell" ]
}

@test "pr-watch: a failing gh pr view keeps the tracked PR for the next poll" {
    pr_watch_setup
    before="$(cat "$STATE_FILE")"
    stub gh 'case "$2" in list) echo "[]" ;; view) exit 1 ;; esac'
    run env PATH="$STUBS:$PATH" bash "$P/github/pr-watch.sh" --once
    [[ "$output" != *"CLOSED"* && "$output" != *"MERGED"* ]]
    [ "$(cat "$STATE_FILE")" = "$before" ]
}

@test "pr-watch: a PR that gh still reports OPEN is kept, not reported closed" {
    pr_watch_setup
    before="$(cat "$STATE_FILE")"
    stub_gh OPEN
    run env PATH="$STUBS:$PATH" bash "$P/github/pr-watch.sh" --once
    [[ "$output" != *"CLOSED"* && "$output" != *"MERGED"* ]]
    [ "$(cat "$STATE_FILE")" = "$before" ]
}

@test "pr-watch: a non-event change logs [update] without jq parse errors" {
    pr_watch_setup
    stub gh 'case "$2" in list) echo "[{\"number\":7,\"title\":\"t\",\"author\":{\"login\":\"a\"},\"reviewDecision\":null,\"mergeable\":\"UNKNOWN\",\"updatedAt\":\"y\",\"statusCheckRollup\":[]}]" ;; esac'
    run env PATH="$STUBS:$PATH" bash "$P/github/pr-watch.sh" --once
    [[ "$output" == *"[pr-watch][update]"* ]]
    [[ "$output" != *"[REVIEW]"* && "$output" != *"[CI FAIL]"* ]]
    [[ "$output" != *"parse error"* ]]
}
