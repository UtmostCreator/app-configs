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

# ── T-0024: empty package set vs failed snapshot ─────────────────────────────

@test "mise: a successful empty snapshot is an empty set, not unavailable" {
  run bash -c '
    source "$1/ops/update-version-report.sh"
    report_mise_changes "" "$(printf "example\t1.0.0")" 1
  ' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unavailable"* ]]
  [[ "$output" == *"1 added"* ]]
}

@test "mise: empty before and after (available) reports no changes" {
  run bash -c '
    source "$1/ops/update-version-report.sh"
    report_mise_changes "" "" 1
  ' _ "$REPO_ROOT"
  [[ "$output" != *"unavailable"* ]]
  [[ "$output" == *"no package changes"* ]]
}

@test "profile snapshot that lists nothing is distinguishable from a failed one" {
  run bash -c '
    source "$1/ops/update-version-report.sh"
    nix_toplevel_packages() { return 0; }   # succeeded, zero packages
    empty="$(packages_in_profile /nonexistent)"
    nix_toplevel_packages() { return 1; }   # snapshot failed
    failed="$(packages_in_profile /nonexistent)"
    [[ "$empty" != "$failed" ]] || { echo "INDISTINGUISHABLE"; exit 1; }
    render_package_delta "nix profile" "$empty" "$(printf "fish\t4.9.2")"
    echo ---
    render_package_delta "nix profile" "$failed" "$(printf "fish\t4.9.2")"
  ' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  empty_part="${output%%---*}"
  failed_part="${output##*---}"
  [[ "$empty_part" == *"1 added"* ]]
  [[ "$empty_part" != *"unavailable"* ]]
  [[ "$failed_part" == *"unavailable"* ]]
}
