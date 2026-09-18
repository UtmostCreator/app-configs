#!/usr/bin/env bats
#
# The package report: what the user reads after an update. It must show
# top-level package changes only — never closure noise — and it must make
# removals impossible to miss.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

report() {
  run bash -c '
    source "$1/ops/update-version-report.sh"
    render_package_delta "$2" "$3" "$4"
  ' _ "$REPO_ROOT" "$1" "$2" "$3"
}

@test "headline counts upgraded, added and removed packages" {
  before="$(printf 'firefox\t155.0.1\nfish\t4.9.2\nclaude-code\t2.1.263')"
  after="$(printf 'firefox\t156.0\nfish\t4.9.2\ntlottie\t0-unstable')"
  report "Home Manager" "$before" "$after"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 upgraded"* ]]
  [[ "$output" == *"1 added"* ]]
  [[ "$output" == *"1 removed"* ]]
}

@test "upgrades are listed as old to new" {
  before="$(printf 'firefox\t155.0.1')"
  after="$(printf 'firefox\t156.0')"
  report "Home Manager" "$before" "$after"
  [[ "$output" == *"firefox"* ]]
  [[ "$output" == *"155.0.1"* ]]
  [[ "$output" == *"156.0"* ]]
}

@test "removals are called out in their own section" {
  before="$(printf 'claude-code\t2.1.263\nfish\t4.9.2')"
  after="$(printf 'fish\t4.9.3')"
  report "Home Manager" "$before" "$after"
  [[ "$output" == *"REMOVED"* ]]
  [[ "$output" == *"claude-code"* ]]
}

@test "an unchanged package set says so in one line" {
  same="$(printf 'fish\t4.9.2')"
  report "Home Manager" "$same" "$same"
  [[ "$output" == *"no package changes"* ]]
  [[ "$output" != *"UPGRADED"* ]]
}

@test "a missing snapshot is reported as unavailable, not as an empty diff" {
  report "Home Manager" "" "$(printf 'fish\t4.9.2')"
  [[ "$output" == *"unavailable"* ]]
  [[ "$output" != *"added"* ]]
}

# ── mise ────────────────────────────────────────────────────────────────────

@test "mise report shows upgraded, added, and removed versions" {
  run bash -c '
    source "$1/ops/update-version-report.sh"
    report_mise_changes \
      "$(printf "example\t1.2.3\nremoved\t4.5.6")" \
      "$(printf "example\t2.0.0\nadded\t7.8.9")" \
      1
  ' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"example"* ]]
  [[ "$output" == *"1.2.3"* ]]
  [[ "$output" == *"2.0.0"* ]]
  [[ "$output" == *"added"* ]]
  [[ "$output" == *"7.8.9"* ]]
  [[ "$output" == *"removed"* ]]
  [[ "$output" == *"4.5.6"* ]]
}

@test "mise report states when nothing changed" {
  run bash -c '
    source "$1/ops/update-version-report.sh"
    report_mise_changes "$(printf "example\t1.2.3")" "$(printf "example\t1.2.3")" 1
  ' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no package changes"* ]]
}

@test "mise report is honest when the snapshot could not be taken" {
  run bash -c '
    source "$1/ops/update-version-report.sh"
    report_mise_changes "" "" 0
  ' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unavailable"* ]]
}
