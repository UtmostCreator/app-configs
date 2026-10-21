#!/usr/bin/env bats

setup() {
  LOGGING_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORKSPACE="$LOGGING_DIR/watch/run.sh"
  VIEWER="$LOGGING_DIR/watch/viewer.sh"
  CAPTURE="$LOGGING_DIR/capture.sh"
  TEST_ROOT="$BATS_TEST_TMPDIR/workspace"
  TEST_HOME="$TEST_ROOT/home"
  TEST_STATE="$TEST_ROOT/state"
  TEST_TMUX="${TMPDIR:-/tmp}/lw-tmux-${BATS_TEST_NUMBER}-$$"
  SESSION="lw-test-${BATS_TEST_NUMBER}"
  mkdir -p "$TEST_HOME" "$TEST_STATE" "$TEST_TMUX"
  chmod 700 "$TEST_TMUX"
  export HOME="$TEST_HOME"
  export TMUX_TMPDIR="$TEST_TMUX"
  export LOG_WORKSPACE_STATE_DIR="$TEST_STATE"
  export LOG_WORKSPACE_SESSION_NAME="$SESSION"
}

teardown() {
  # Kill the test tmux server's pane process trees first: kill-server only
  # SIGHUPs panes, and a viewer or lnav that ignores it would outlive the run.
  local pid
  for pid in $(tmux list-panes -a -F '#{pane_pid}' 2>/dev/null); do
    pkill -KILL -P "$pid" 2>/dev/null || true
  done
  tmux kill-server >/dev/null 2>&1 || true
  # A TMUX=<path>,... client makes tmux use that path as its socket.
  tmux -S "$TEST_TMUX/fake-client" kill-server >/dev/null 2>&1 || true
  rm -rf "$TEST_TMUX"
}

run_workspace() {
  run bash "$WORKSPACE" --detached "$@"
}

session_instance() {
  tmux show-option -qv -t "$SESSION" @log_workspace_instance
}

wait_for() {
  local attempts=60
  while (( attempts > 0 )); do
    if "$@"; then
      return 0
    fi
    sleep 0.1
    ((attempts-=1))
  done
  return 1
}

health_has_state() {
  local instance="$1"
  local role="$2"
  local state="$3"
  [[ -f "$TEST_STATE/health/$instance.$role" ]] \
    && [[ "$(cut -f1 "$TEST_STATE/health/$instance.$role")" == "$state" ]]
}

pane_is_dead() {
  [[ "$(tmux display-message -p -t "$1" '#{pane_dead}')" == "1" ]]
}

pid_is_gone() {
  local args
  local state
  state="$(ps -o stat= -p "$1" 2>/dev/null | tr -d '[:space:]')"
  args="$(ps -o args= -p "$1" 2>/dev/null || true)"
  [[ -z "$state" || "$state" == Z* || "$args" != *"$VIEWER"* || "$args" != *"--state-dir $TEST_STATE"* ]]
}

@test "invalid arguments are rejected before an existing session is mutated" {
  tmux new-session -d -s "$SESSION" sleep 30
  before="$(tmux display-message -p -t "$SESSION" '#{session_id}:#{session_created}')"

  run bash "$WORKSPACE" --not-a-real-option

  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown argument"* ]]
  after="$(tmux display-message -p -t "$SESSION" '#{session_id}:#{session_created}')"
  [ "$after" = "$before" ]
}

@test "missing sources stay missing while the complete workspace reports WAITING" {
  run_workspace --rebuild

  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/Herd" ]
  [ ! -e "$TEST_HOME/logs" ]
  [ "$(tmux list-windows -t "$SESSION:" -F '#{window_index}:#{window_name}:#{window_panes}')" = $'1:all:1\n2:dashboard:3' ]
  instance="$(session_instance)"
  for role in all integration ws frontend; do
    health_has_state "$instance" "$role" WAITING
  done
}

@test "literal glob arguments discover the next dated Integration file" {
  log_dir="$TEST_HOME/Herd/integration/storage/logs"
  mkdir -p "$log_dir"
  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$log_dir/laravel-2026-09-03.log"
  run_workspace --rebuild
  [ "$status" -eq 0 ]
  instance="$(session_instance)"
  wait_for grep -q 'laravel-2026-09-03.log' "$TEST_STATE/health/$instance.integration"

  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$log_dir/laravel-2026-09-04.log"

  wait_for grep -q 'laravel-2026-09-04.log' "$TEST_STATE/health/$instance.integration"
  pane="$(tmux list-panes -s -t "$SESSION:" -F '#{@log_workspace_role} #{pane_id}' | awk '$1 == "integration" {print $2}')"
  [ "$(tmux display-message -p -t "$pane" '#{pane_dead}')" -eq 0 ]
}

@test "paths with spaces quotes dollars and shell metacharacters stay data" {
  odd_root="$TEST_ROOT/Herd odd 'quote \$dollar;touch SHOULD_NOT_EXIST"
  log_dir="$odd_root/integration/storage/logs"
  mkdir -p "$log_dir"
  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$log_dir/laravel-2026-09-03.log"
  export LOG_WORKSPACE_HERD_ROOT="$odd_root"

  run_workspace --rebuild

  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/SHOULD_NOT_EXIST" ]
  instance="$(session_instance)"
  health_has_state "$instance" integration FOLLOWING
  start_command="$(tmux list-panes -s -t "$SESSION:" -F '#{@log_workspace_role} #{pane_start_command}' | awk '$1 == "integration" {sub($1 FS, ""); print}')"
  [[ "$start_command" == *"laravel-*.log"* ]]
}

@test "a dead viewer is repaired without rebuilding a matching session" {
  run_workspace --rebuild
  [ "$status" -eq 0 ]
  before_instance="$(session_instance)"
  pane="$(tmux list-panes -s -t "$SESSION:" -F '#{@log_workspace_role} #{pane_id}' | awk '$1 == "frontend" {print $2}')"
  tmux respawn-pane -k -t "$pane" false
  wait_for pane_is_dead "$pane"

  run_workspace

  [ "$status" -eq 0 ]
  [ "$(session_instance)" = "$before_instance" ]
  [ "$(tmux display-message -p -t "$pane" '#{pane_dead}')" -eq 0 ]
  health_has_state "$before_instance" frontend WAITING
}

@test "a structurally altered session is transactionally restored" {
  run_workspace --rebuild
  [ "$status" -eq 0 ]
  before_instance="$(session_instance)"
  tmux rename-window -t "$SESSION:all" renamed

  run_workspace

  [ "$status" -eq 0 ]
  [ "$(session_instance)" != "$before_instance" ]
  [ "$(tmux list-windows -t "$SESSION:" -F '#{window_index}:#{window_name}:#{window_panes}')" = $'1:all:1\n2:dashboard:3' ]
}

@test "a configuration fingerprint change replaces the session" {
  run_workspace --rebuild
  [ "$status" -eq 0 ]
  before_instance="$(session_instance)"

  run env HOME="$HOME" TMUX_TMPDIR="$TMUX_TMPDIR" \
    LOG_WORKSPACE_STATE_DIR="$LOG_WORKSPACE_STATE_DIR" \
    LOG_WORKSPACE_SESSION_NAME="$LOG_WORKSPACE_SESSION_NAME" \
    LOG_WORKSPACE_SINCE=4h bash "$WORKSPACE" --detached

  [ "$status" -eq 0 ]
  [ "$(session_instance)" != "$before_instance" ]
  fingerprint="$(tmux show-option -qv -t "$SESSION" @log_workspace_fingerprint)"
  [ -n "$fingerprint" ]
}

@test "rebuild is transactional and a failed candidate preserves the old session" {
  run_workspace --rebuild
  [ "$status" -eq 0 ]
  before_instance="$(session_instance)"

  run_workspace --rebuild
  [ "$status" -eq 0 ]
  replacement_instance="$(session_instance)"
  [ "$replacement_instance" != "$before_instance" ]

  fake_bin="$TEST_ROOT/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nprintf "lnav 0.14.0\\n"\n[[ "${1:-}" == "-V" ]] && exit 0\nexit 42\n' >"$fake_bin/lnav"
  chmod +x "$fake_bin/lnav"
  mkdir -p "$TEST_HOME/Herd/integration/storage/logs"
  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$TEST_HOME/Herd/integration/storage/logs/laravel-2026-09-03.log"

  run env PATH="$fake_bin:$PATH" HOME="$HOME" TMUX_TMPDIR="$TMUX_TMPDIR" \
    LOG_WORKSPACE_STATE_DIR="$LOG_WORKSPACE_STATE_DIR" \
    LOG_WORKSPACE_SESSION_NAME="$LOG_WORKSPACE_SESSION_NAME" \
    bash "$WORKSPACE" --detached --rebuild

  [ "$status" -ne 0 ]
  [ "$(session_instance)" = "$replacement_instance" ]
  [ "$(tmux list-sessions -F '#{session_name}' | grep -c "^$SESSION$")" -eq 1 ]
}

@test "healthy sessions use direct attach and in-tmux switch targets" {
  run_workspace --rebuild
  [ "$status" -eq 0 ]
  fake_bin="$TEST_ROOT/fake-tmux-bin"
  real_tmux="$(command -v tmux)"
  mkdir -p "$fake_bin"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'case "$1" in' \
    '  attach-session) printf "ATTACH"; printf " <%s>" "$@"; printf "\\n" ;;' \
    '  switch-client) printf "SWITCH"; printf " <%s>" "$@"; printf "\\n" ;;' \
    '  *) exec "$REAL_TMUX" "$@" ;;' \
    'esac' >"$fake_bin/tmux"
  chmod +x "$fake_bin/tmux"

  run env -u TMUX PATH="$fake_bin:$PATH" REAL_TMUX="$real_tmux" HOME="$HOME" TMUX_TMPDIR="$TMUX_TMPDIR" \
    LOG_WORKSPACE_STATE_DIR="$LOG_WORKSPACE_STATE_DIR" \
    LOG_WORKSPACE_SESSION_NAME="$LOG_WORKSPACE_SESSION_NAME" bash "$WORKSPACE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ATTACH <attach-session> <-t> <$SESSION:dashboard>"* ]]

  run env TMUX="$TEST_TMUX/fake-client,0,0" PATH="$fake_bin:$PATH" REAL_TMUX="$real_tmux" HOME="$HOME" TMUX_TMPDIR="$TMUX_TMPDIR" \
    LOG_WORKSPACE_STATE_DIR="$LOG_WORKSPACE_STATE_DIR" \
    LOG_WORKSPACE_SESSION_NAME="$LOG_WORKSPACE_SESSION_NAME" bash "$WORKSPACE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SWITCH <switch-client> <-t> <$SESSION:dashboard>"* ]]
}

@test "older lnav selects the clearly labelled less fallback" {
  fake_bin="$TEST_ROOT/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nprintf "lnav 0.13.0\\n"\n' >"$fake_bin/lnav"
  chmod +x "$fake_bin/lnav"
  mkdir -p "$TEST_HOME/Herd/integration/storage/logs"
  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$TEST_HOME/Herd/integration/storage/logs/laravel-2026-09-03.log"

  run env PATH="$fake_bin:$PATH" HOME="$HOME" TMUX_TMPDIR="$TMUX_TMPDIR" \
    LOG_WORKSPACE_STATE_DIR="$LOG_WORKSPACE_STATE_DIR" \
    LOG_WORKSPACE_SESSION_NAME="$LOG_WORKSPACE_SESSION_NAME" \
    bash "$WORKSPACE" --detached --rebuild

  [ "$status" -eq 0 ]
  [[ "$output" == *"(less viewer)"* ]]
  command="$(tmux list-panes -s -t "$SESSION:" -F '#{@log_workspace_role} #{pane_start_command}' | awk '$1 == "all" {sub($1 FS, ""); print}')"
  [[ "$command" == *"--backend less"* ]]
  [[ "$command" == *"below the supported 0.14.0 baseline"* ]]
  instance="$(session_instance)"
  wait_for health_has_state "$instance" integration DEGRADED
  pane="$(tmux list-panes -s -t "$SESSION:" -F '#{@log_workspace_role} #{pane_id}' | awk '$1 == "integration" {print $2}')"
  [ "$(tmux display-message -p -t "$pane" '#{pane_dead}')" -eq 0 ]
  wait_for grep -q 'Reduced viewer:' "$TEST_STATE/less-$instance-integration.log"

  printf '%s\n' '[2026-09-04 00:00:01] local.INFO: fallback-rollover-marker' \
    >"$TEST_HOME/Herd/integration/storage/logs/laravel-2026-09-04.log"
  wait_for grep -q 'fallback-rollover-marker' "$TEST_STATE/less-$instance-integration.log"
}

@test "a broken lnav executable falls back instead of aborting startup" {
  fake_bin="$TEST_ROOT/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nexit 127\n' >"$fake_bin/lnav"
  chmod +x "$fake_bin/lnav"

  run env PATH="$fake_bin:$PATH" HOME="$HOME" TMUX_TMPDIR="$TMUX_TMPDIR" \
    LOG_WORKSPACE_STATE_DIR="$LOG_WORKSPACE_STATE_DIR" \
    LOG_WORKSPACE_SESSION_NAME="$LOG_WORKSPACE_SESSION_NAME" \
    bash "$WORKSPACE" --detached --rebuild

  [ "$status" -eq 0 ]
  [[ "$output" == *"(less viewer)"* ]]
}

@test "stopping a fallback session cleans viewer processes and stream files" {
  fake_bin="$TEST_ROOT/fake-bin"
  mkdir -p "$fake_bin" "$TEST_HOME/Herd/integration/storage/logs"
  printf '#!/usr/bin/env bash\nprintf "lnav 0.13.0\\n"\n' >"$fake_bin/lnav"
  chmod +x "$fake_bin/lnav"
  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$TEST_HOME/Herd/integration/storage/logs/laravel-2026-09-03.log"

  run env PATH="$fake_bin:$PATH" HOME="$HOME" TMUX_TMPDIR="$TMUX_TMPDIR" \
    LOG_WORKSPACE_STATE_DIR="$LOG_WORKSPACE_STATE_DIR" \
    LOG_WORKSPACE_SESSION_NAME="$LOG_WORKSPACE_SESSION_NAME" \
    bash "$WORKSPACE" --detached --rebuild
  [ "$status" -eq 0 ]
  instance="$(session_instance)"
  mapfile -t viewer_pids < <(cut -f3 "$TEST_STATE/health/$instance".*)

  tmux kill-session -t "$SESSION"

  for pid in "${viewer_pids[@]}"; do
    wait_for pid_is_gone "$pid"
  done
  run bash -c 'compgen -G "$1/less-$2-*.log"' bash "$TEST_STATE" "$instance"
  [ "$status" -ne 0 ]
}

@test "lnav cutoff crash retry remains visibly degraded" {
  fake_bin="$TEST_ROOT/fake-bin"
  marker="$TEST_ROOT/lnav-retried"
  viewer_output="$TEST_ROOT/viewer-output.log"
  source_file="$TEST_ROOT/integration/storage/logs/laravel-2026-09-03.log"
  mkdir -p "$fake_bin" "$(dirname "$source_file")"
  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$source_file"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [[ ! -e "$FAKE_LNAV_MARKER" ]]; then' \
    '  : >"$FAKE_LNAV_MARKER"' \
    '  exit 134' \
    'fi' \
    'sleep 10' >"$fake_bin/lnav"
  chmod +x "$fake_bin/lnav"

  env PATH="$fake_bin:$PATH" FAKE_LNAV_MARKER="$marker" \
    bash "$VIEWER" --role integration --instance retry --state-dir "$TEST_STATE" \
    --config-dir "$LOGGING_DIR/lnav" --since 24h --backend lnav -- "$source_file" \
    >"$viewer_output" 2>&1 &
  viewer_pid="$!"

  wait_for test -e "$marker"
  wait_for health_has_state retry integration DEGRADED
  grep -Eq '(retrying|lnav) without time cutoff' "$TEST_STATE/health/retry.integration"
  kill "$viewer_pid"
  wait "$viewer_pid" || true
}

@test "Ctrl-C exits an lnav viewer cleanly" {
  fake_bin="$TEST_ROOT/fake-bin"
  source_file="$TEST_ROOT/integration/storage/logs/laravel-2026-09-03.log"
  mkdir -p "$fake_bin" "$(dirname "$source_file")"
  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$source_file"
  printf '#!/usr/bin/env bash\nsleep 10\n' >"$fake_bin/lnav"
  chmod +x "$fake_bin/lnav"

  env PATH="$fake_bin:$PATH" \
    bash "$VIEWER" --role integration --instance interrupted --state-dir "$TEST_STATE" \
    --config-dir "$LOGGING_DIR/lnav" --since 24h --backend lnav -- "$source_file" \
    >"$TEST_ROOT/viewer-output.log" 2>&1 &
  viewer_pid="$!"

  wait_for health_has_state interrupted integration FOLLOWING
  kill -INT "$viewer_pid"
  wait "$viewer_pid"
}

@test "viewer failures remain explicit in health state" {
  fake_bin="$TEST_ROOT/fake-bin"
  source_file="$TEST_ROOT/integration/storage/logs/laravel-2026-09-03.log"
  mkdir -p "$fake_bin" "$(dirname "$source_file")"
  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$source_file"
  printf '#!/usr/bin/env bash\nexit 42\n' >"$fake_bin/lnav"
  chmod +x "$fake_bin/lnav"

  run env PATH="$fake_bin:$PATH" bash "$VIEWER" --role integration --instance failed \
    --state-dir "$TEST_STATE" --config-dir "$LOGGING_DIR/lnav" --since 24h \
    --backend lnav -- "$source_file"

  [ "$status" -eq 42 ]
  health_has_state failed integration 'FAILED 42'
}

@test "focused source manifest declares all viewer metadata" {
  run bash -c 'source "$1"; log_workspace_manifest' bash "$LOGGING_DIR/watch/config.sh"

  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 4 ]
  [[ "$output" == *$'integration_laravel\tIntegration Laravel\t'*$'\tintegration\toptional\tbackend_laravel_log'* ]]
  [[ "$output" == *$'backend_npm\tbackend npm\t'*$'\tws\toptional\tbackend_npm_log'* ]]
  [[ "$output" == *$'frontend_npm\tFrontend npm\t'*$'\tfrontend\toptional\tbackend_npm_log'* ]]
}

@test "npm capture adds UTC millisecond labels strips persisted ANSI and avoids double prefixes" {
  output_file="$TEST_ROOT/npm.log"
  existing='2026-09-03T09:42:18.381Z [BACKEND-NPM] INFO already stamped'

  run bash -c 'printf "\\033[31mERROR boom\\033[0m\\nprogress\\rDONE\\n%s\\n" "$1" | bash "$2" --label BACKEND-NPM --output "$3"' \
    bash "$existing" "$CAPTURE" "$output_file"

  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[31mERROR boom\033[0m'* ]]
  [ "$(wc -l <"$output_file")" -eq 3 ]
  grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z \[BACKEND-NPM\] ERROR boom$' "$output_file"
  grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z \[BACKEND-NPM\] DONE$' "$output_file"
  [ "$(grep -Fxc "$existing" "$output_file")" -eq 1 ]
  ! grep -q $'\033' "$output_file"
  ! grep -q $'\r' "$output_file"
}

@test "repository lnav formats validate with their canonical samples" {
  run lnav -n -N -W -I "$LOGGING_DIR/lnav"

  [ "$status" -eq 0 ]
  [[ "$output" != *"error:"* ]]

  mkdir -p "$TEST_ROOT/backend/storage/logs" "$TEST_ROOT/logs"
  cp "$BATS_TEST_DIRNAME/fixtures/laravel.log" "$TEST_ROOT/backend/storage/logs/laravel.log"
  cp "$BATS_TEST_DIRNAME/fixtures/npm.log" "$TEST_ROOT/logs/backend-npm.log"

  run lnav -n -N -I "$LOGGING_DIR/lnav" \
    -c ';SELECT log_format, correlation_key, correlation_id FROM backend_laravel_log' \
    "$TEST_ROOT/backend/storage/logs/laravel.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"request_id"*"req-123"* ]]
  [[ "$output" == *"trace_id"*"trace-456"* ]]

  run lnav -n -N -I "$LOGGING_DIR/lnav" \
    -c ';SELECT log_format, source, level FROM backend_npm_log' \
    "$TEST_ROOT/logs/backend-npm.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BACKEND-NPM"*"INFO"* ]]
  [[ "$output" == *"FRONTEND-NPM"*"ERROR"* ]]
}
