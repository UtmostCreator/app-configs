#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "mise report shows upgraded, added, and removed versions" {
  run bash -c '
    source "$1/ops/update-version-report.sh"
    report_mise_changes \
      $'"'"'example\t1.2.3\nremoved\t4.5.6'"'"' \
      $'"'"'example\t2.0.0\nadded\t7.8.9'"'"' \
      1
  ' _ "$REPO_ROOT"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"example: 1.2.3 => 2.0.0"* ]]
  [[ "$output" == *"added: ∅ => 7.8.9"* ]]
  [[ "$output" == *"removed: 4.5.6 => ∅"* ]]
}

@test "mise report states when nothing changed" {
  run bash -c '
    source "$1/ops/update-version-report.sh"
    report_mise_changes $'"'"'example\t1.2.3'"'"' $'"'"'example\t1.2.3'"'"' 1
  ' _ "$REPO_ROOT"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"no version changes"* ]]
}
