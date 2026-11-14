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

@test "the abort lists the changed paths so the cause is visible" {
  dirty_it
  run bash "$FAKE/ops/update-all.sh" --apply --yes
  [[ "$output" == *"Changed:"* ]]
  [[ "$output" == *"M nix/flake.lock"* ]]
  [[ "$output" == *"?? untracked"* ]]
}

@test "the changed-path list is capped with a count of the rest" {
  for i in $(seq 1 15); do printf 'x\n' >"$FAKE/scratch-$i"; done
  run bash "$FAKE/ops/update-all.sh" --apply --yes
  [ "$(grep -c '?? scratch-' <<<"$output")" -eq 10 ]
  [[ "$output" == *"and 5 more"* ]]
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

@test "--allow-dirty still stops on untracked files under nix/ (the flake cannot see them)" {
  mkdir -p "$FAKE/nix/modules"; printf '{ }\n' > "$FAKE/nix/modules/new.nix"
  run bash "$FAKE/ops/update-all.sh" --apply --yes --allow-dirty
  [ "$status" -ne 0 ]
  [[ "$output" == *"git add nix/modules/new.nix"* ]]
}

@test "under bats a clean apply against the real HOME is refused before mutation" {
  outside="${BATS_RUN_TMPDIR:-/tmp}/outside-home-$$"
  mkdir -p "$outside"
  # Stub the required tools so the preflight passes on any host (a bare CI
  # runner has no home-manager) and the run really reaches the guard.
  local bin="$BATS_TEST_TMPDIR/guard-bin"; mkdir -p "$bin"
  printf '#!/bin/sh\nexit 0\n' >"$bin/home-manager"
  printf '#!/bin/sh\nexit 0\n' >"$bin/chezmoi"
  chmod +x "$bin/home-manager" "$bin/chezmoi"
  run env HOME="$outside" PATH="$bin:$PATH" bash "$FAKE/ops/update-all.sh" --apply --yes
  [ "$status" -eq 3 ]
  [[ "$output" == *"refusing to apply from a bats test"* ]]
  [ -z "$(ls -A "$outside")" ]   # no snapshot or state written there
}
