#!/usr/bin/env bats
#
# Presentation layer for ops/update-all.sh: every step reports a severity and a
# one-line summary, while raw command output goes to the run log.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  UI_LOG_FILE="$BATS_TEST_TMPDIR/run.log"
  # shellcheck source=ops/lib/update-ui.sh
  source "$REPO_ROOT/ops/lib/update-ui.sh"
  ui_init "$UI_LOG_FILE"
}

@test "command output goes to the log, not the terminal" {
  run bash -c '
    source "$1/ops/lib/update-ui.sh"; ui_init "$2"
    ui_run "flake inputs" echo "noisy build output"
    ui_ok "flake inputs" "4 updated"
  ' _ "$REPO_ROOT" "$UI_LOG_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" != *"noisy build output"* ]]
  [[ "$output" == *"flake inputs"* ]]
  [[ "$output" == *"4 updated"* ]]
  grep -q "noisy build output" "$UI_LOG_FILE"
}

@test "verbose mode mirrors command output to the terminal" {
  run bash -c '
    source "$1/ops/lib/update-ui.sh"; ui_init "$2" 1
    ui_run "flake inputs" echo "noisy build output"
  ' _ "$REPO_ROOT" "$UI_LOG_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"noisy build output"* ]]
}

@test "a failing step reports its status and surfaces the captured output" {
  run bash -c '
    source "$1/ops/lib/update-ui.sh"; ui_init "$2"
    ui_run "flake check" bash -c "echo boom >&2; exit 3" || true
    ui_err "flake check" "evaluation failed"
  ' _ "$REPO_ROOT" "$UI_LOG_FILE"
  [[ "$output" == *"evaluation failed"* ]]
  [[ "$output" == *"boom"* ]]
}

@test "ui_run propagates the command exit status" {
  run bash -c '
    source "$1/ops/lib/update-ui.sh"; ui_init "$2"
    ui_run "step" bash -c "exit 7"
  ' _ "$REPO_ROOT" "$UI_LOG_FILE"
  [ "$status" -eq 7 ]
}

@test "counts every severity for the final summary" {
  run bash -c '
    source "$1/ops/lib/update-ui.sh"; ui_init "$2"
    ui_ok   a "fine"
    ui_ok   b "fine"
    ui_warn c "needs a look"
    ui_err  d "broken"
    ui_skip e "not applicable"
    printf "ok=%s warn=%s err=%s skip=%s\n" \
      "$UI_COUNT_OK" "$UI_COUNT_WARN" "$UI_COUNT_ERR" "$UI_COUNT_SKIP"
  ' _ "$REPO_ROOT" "$UI_LOG_FILE"
  [[ "$output" == *"ok=2 warn=1 err=1 skip=1"* ]]
}

@test "collected warnings are replayed in one block with remediation" {
  run bash -c '
    source "$1/ops/lib/update-ui.sh"; ui_init "$2"
    ui_note warn "phoenix-cli" "npm peer dependency conflict"
    ui_note info "flake"       "macOS outputs not checked on this host"
    ui_notes_report
  ' _ "$REPO_ROOT" "$UI_LOG_FILE"
  [[ "$output" == *"phoenix-cli"* ]]
  [[ "$output" == *"npm peer dependency conflict"* ]]
  [[ "$output" == *"macOS outputs not checked"* ]]
}

@test "scanning a log turns known warnings into classified notes" {
  run bash -c '
    source "$1/ops/lib/update-facts.sh"
    source "$1/ops/lib/update-ui.sh"; ui_init "$2"
    printf "%s\n" \
      "warning: The check omitted these incompatible systems: aarch64-darwin" \
      "building /nix/store/xxx.drv" > "$3"
    UI_LAST_LOG="$3" ui_scan_warnings
    ui_notes_report
  ' _ "$REPO_ROOT" "$UI_LOG_FILE" "$BATS_TEST_TMPDIR/step.log"
  [[ "$output" == *"aarch64-darwin"* ]]
  [[ "$output" != *"/nix/store/xxx.drv"* ]]
}

@test "dry-run mode announces commands instead of running them" {
  run bash -c '
    source "$1/ops/lib/update-ui.sh"; ui_init "$2"
    UI_DRY_RUN=1
    ui_run "dangerous" touch "$3"
  ' _ "$REPO_ROOT" "$UI_LOG_FILE" "$BATS_TEST_TMPDIR/should-not-exist"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]
  [[ "$output" == *"touch"* ]]
}
