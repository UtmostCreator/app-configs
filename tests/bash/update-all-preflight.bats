#!/usr/bin/env bats
#
# The preflight contract of ops/update-all.sh: no mutation may happen until
# every precondition passes.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export SYS_UPDATE_STATE_DIR="$BATS_TEST_TMPDIR/state"
  export NO_COLOR=1
  FAKE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FAKE"
  cp -a "$REPO_ROOT/ops" "$FAKE/ops"
  mkdir -p "$FAKE/nix"
  printf '{}\n' > "$FAKE/nix/flake.lock"
  printf '{ outputs = _: { }; }\n' > "$FAKE/nix/flake.nix"
  git -C "$FAKE" init -q
  git -C "$FAKE" add -A
  git -C "$FAKE" -c user.email=t@t -c user.name=t commit -q -m init
}

dirty_it() {
  printf 'local edit\n' > "$FAKE/nix/flake.lock"
  printf 'scratch\n' > "$FAKE/untracked"
}

@test "a dirty worktree aborts before anything is mutated" {
  dirty_it
  run bash "$FAKE/ops/update-all.sh" --apply --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"uncommitted"* ]]
  [[ "$output" == *"stopped before"* ]]
  # the offending files are still exactly as they were
  [ "$(cat "$FAKE/nix/flake.lock")" = "local edit" ]
}

@test "the abort names both the fix and the override" {
  dirty_it
  run bash "$FAKE/ops/update-all.sh" --apply --yes
  [[ "$output" == *"stash push -u"* ]]
  [[ "$output" == *"status"* ]]
  [[ "$output" == *"--allow-dirty"* ]]
}

@test "--allow-dirty converts the gate into a recorded warning" {
  dirty_it
  run bash "$FAKE/ops/update-all.sh" --allow-dirty
  [[ "$output" != *"stopped before"* ]]
  [[ "$output" == *"1 modified"* ]]
  [[ "$output" == *"1 untracked"* ]]
}

@test "the repository is reported by its canonical path" {
  ln -s "$FAKE" "$BATS_TEST_TMPDIR/alias"
  run bash "$BATS_TEST_TMPDIR/alias/ops/update-all.sh"
  [[ "$output" == *"$(cd "$FAKE" && pwd -P)"* ]]
}

@test "report mode is the default and mutates nothing" {
  run bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"report"* || "$output" == *"would"* ]]
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
}

@test "--help documents the phases without touching the system" {
  run bash "$FAKE/ops/update-all.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"PRECHECK"* ]]
  [[ "$output" == *"VERIFY"* ]]
  [[ "$output" == *"rollback"* ]]
}

@test "an unknown flag is rejected before any work starts" {
  run bash "$FAKE/ops/update-all.sh" --definitely-not-a-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown"* ]]
}
