#!/usr/bin/env bats
#
# The preflight contract of ops/update-all.sh: no mutation may happen until
# every precondition passes.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # The --apply runs below rely on the preflight stopping; keep the real HOME
  # out of reach in case one ever gets further.
  export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
  export SYS_UPDATE_STATE_DIR="$BATS_TEST_TMPDIR/state"
  export NO_COLOR=1
  # Home Manager's profile directory is looked up under XDG_STATE_HOME, then
  # under NIX_STATE_DIR; point both into the sandbox so the real ones never
  # decide a result (the second holds a per-user profile directory).
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/xdg-state"
  export NIX_STATE_DIR="$BATS_TEST_TMPDIR/nix-state"
  mkdir -p "$NIX_STATE_DIR/profiles/per-user/${USER:-$(id -un)}"
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
  [[ "$output" == *"diff --binary HEAD > <private dir>/wip.patch"* ]]
  [[ "$output" == *"restore --staged --worktree -- ."* ]]
  [[ "$output" == *"untracked files must be moved aside or committed by hand"* ]]
  [[ "$output" != *"stash push"* ]]
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

# A chezmoi stub for the managed-files gate: `status` prints $CHEZMOI_STATUS,
# `source-path` names a modify_ source for each target listed in
# $CHEZMOI_MODIFY_TARGETS and a plain source for everything else.
stub_chezmoi() {
  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  cat > "$STUBS/chezmoi" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  status) [[ -n "${CHEZMOI_STATUS:-}" ]] && printf '%s\n' "$CHEZMOI_STATUS" ;;
  target-path) [[ $# -eq 1 ]] && printf '%s\n' "$HOME" ;;
  source-path)
    shift
    for t in "$@"; do
      rel="${t#"$HOME"/}" base="${t##*/}" src="dot_${base#.}"
      for m in ${CHEZMOI_MODIFY_TARGETS:-}; do [[ "$rel" == "$m" ]] && src="modify_${base}.tmpl"; done
      printf '/src/%s/%s\n' "$(dirname "$rel")" "$src"
    done ;;
esac
exit 0
STUB
  chmod +x "$STUBS/chezmoi"
}

@test "a hand-edited plain managed file is reported as a conflict" {
  stub_chezmoi
  export CHEZMOI_STATUS='MM .gitconfig'
  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [[ "$output" == *"1 edited since chezmoi wrote them: .gitconfig"* ]]
}

@test "a modify_ target is not a conflict: chezmoi merges it without prompting" {
  stub_chezmoi
  export CHEZMOI_STATUS='MM .claude/settings.json'
  export CHEZMOI_MODIFY_TARGETS='.claude/settings.json'
  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [[ "$output" != *"edited since chezmoi wrote them"* ]]
  [[ "$output" == *"managed files"*"no local edits"* ]]
}

@test "modify_ targets are dropped but plain conflicts beside them still count" {
  stub_chezmoi
  export CHEZMOI_STATUS=$'MM .claude/settings.json\nMM .gitconfig\nMM .config/Code/User/settings.json'
  export CHEZMOI_MODIFY_TARGETS='.claude/settings.json .config/Code/User/settings.json'
  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [[ "$output" == *"1 edited since chezmoi wrote them: .gitconfig"* ]]
  [[ "$output" != *"wrote them: .claude"* ]]
  [[ "$output" != *"Code/User/settings.json"*"edited"* ]]
}

# ── T-0010: host detection, PRECHECK contracts, exit codes ──────────────────

# Stub every required tool so an apply run reaches the check under test on any
# host (a bare CI runner has no home-manager).
stub_required_tools() {
  local bin="$BATS_TEST_TMPDIR/req-bin"; mkdir -p "$bin"
  local t
  for t in nix chezmoi home-manager; do
    printf '#!/bin/sh\nexit 0\n' > "$bin/$t"; chmod +x "$bin/$t"
  done
  REQ_PATH="$bin:$PATH"
}

@test "S10: a failed host detection stops with exit 4 and shows the reason" {
  run env -u HOST_PROFILE DETECT_HOST_OSRELEASE=/nonexistent DETECT_HOST_PROC_VERSION=/nonexistent \
    bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 4 ]
  [[ "$output" == *"detect-host"* ]]
  [[ "$output" == *"cannot read kernel release"* ]]
}

@test "S10: a failed host detection never falls back to linux-desktop" {
  run env -u HOST_PROFILE DETECT_HOST_OSRELEASE=/nonexistent DETECT_HOST_PROC_VERSION=/nonexistent \
    bash "$FAKE/ops/update-all.sh" --apply --yes
  [ "$status" -eq 4 ]
  [[ "$output" != *"SYSTEM UPDATE"* ]]
  [ ! -e "$SYS_UPDATE_STATE_DIR/runs" ]
}

@test "G-02: rollback does not need host detection and reaches its own no-run message" {
  run -1 env -u HOST_PROFILE DETECT_HOST_OSRELEASE=/nonexistent DETECT_HOST_PROC_VERSION=/nonexistent \
    bash "$FAKE/ops/update-all.sh" rollback --yes
  [[ "$output" == *"no recorded run"* ]]
  [[ "$output" != *"host detection failed"* ]]
}

@test "S11: an unsupported HOST_PROFILE is rejected with exit 4" {
  run env HOST_PROFILE=bogus bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 4 ]
  [[ "$output" == *"unsupported HOST_PROFILE: bogus"* ]]
}

@test "an unreadable worktree status stops the update (git state error)" {
  stub_required_tools
  printf 'not an index\n' > "$FAKE/.git/index"
  run env HOST_PROFILE=linux-cli PATH="$REQ_PATH" bash "$FAKE/ops/update-all.sh" --apply --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"worktree status"* ]]
  [[ "$output" == *"stopped before"* ]]
}

@test "an upstream that is configured but cannot be resolved stops an apply" {
  stub_required_tools
  branch="$(git -C "$FAKE" symbolic-ref --short HEAD)"
  git -C "$FAKE" config "branch.$branch.remote" origin
  git -C "$FAKE" config "branch.$branch.merge" "refs/heads/$branch"
  run env HOST_PROFILE=linux-cli PATH="$REQ_PATH" bash "$FAKE/ops/update-all.sh" --apply --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"upstream"*"cannot be resolved"* ]]
  [[ "$output" == *"stopped before"* ]]
}

@test "an unresolvable upstream is only a warning in report mode" {
  branch="$(git -C "$FAKE" symbolic-ref --short HEAD)"
  git -C "$FAKE" config "branch.$branch.remote" origin
  git -C "$FAKE" config "branch.$branch.merge" "refs/heads/$branch"
  run env HOST_PROFILE=linux-cli bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"upstream"*"cannot be resolved"* ]]
}

@test "a branch with no upstream is information, not a failure" {
  run env HOST_PROFILE=linux-cli bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no upstream"* ]]
}

@test "S47: --help lists every exit code" {
  run bash "$FAKE/ops/update-all.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exit codes"* ]]
  for code in 0 1 2 3 4 5 129 130 131 141 143; do
    grep -Eq "^ +$code +" <<<"$output"
  done
  [[ "$output" == *"lock"* ]]
  [[ "$output" == *"host detection"* ]]
}

@test "update-all: --help -> prints exactly the header comment block" {
  local script="$FAKE/ops/update-all.sh" line
  local -a header=()
  # the header: the comment lines after the shebang, up to the first non-comment
  while IFS= read -r line; do
    [[ "$line" == "#"* ]] || break
    line="${line#\#}"
    header+=("${line# }")
  done < <(tail -n +2 "$script")
  [ "${#header[@]}" -gt 20 ]
  run bash "$script" --help
  [ "$status" -eq 0 ]
  # bats' $lines collapses blank lines; split the output ourselves
  mapfile -t lines <<<"$output"
  [ "${#lines[@]}" -eq "${#header[@]}" ] || { echo "help has ${#lines[@]} lines, header ${#header[@]}"; return 1; }
  [ "${lines[0]}" = "${header[0]}" ]
  [ "${lines[-1]}" = "${header[-1]}" ]
  [ "$output" = "$(printf '%s\n' "${header[@]}")" ]
}

# -- remembered linux host (T-0044) ------------------------------------------------
# update-all reads the host file through detect-host and warns, in report and in
# apply output, when personal.yaml disagrees. The warning is in the Preflight
# section, so it comes before the chezmoi step and before any change.

host_file_fixture() { # host_file_fixture <value> <hostProfile-line> <gui-line>
  export APP_CONFIGS_HOST_FILE="$BATS_TEST_TMPDIR/cfg/app-configs/host"
  mkdir -p "$(dirname "$APP_CONFIGS_HOST_FILE")" "$FAKE/home/.chezmoidata"
  printf '%s\n' "$1" >"$APP_CONFIGS_HOST_FILE"
  printf 'name: Sentinel\n%s\n%s\n' "$2" "$3" >"$FAKE/home/.chezmoidata/personal.yaml"
  # committed, so the worktree stays clean and the report is not cut short
  git -C "$FAKE" add -A
  git -C "$FAKE" -c user.email=t@t -c user.name=t commit -q -m personal
  unset HOST_PROFILE WSL_DISTRO_NAME
  echo 'Linux version 6.18.33 (b@h) (gcc) #1 SMP' >"$BATS_TEST_TMPDIR/proc-version"
  echo 6.18.33 >"$BATS_TEST_TMPDIR/osrelease"
  export DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/proc-version" DETECT_HOST_OSRELEASE="$BATS_TEST_TMPDIR/osrelease"
  export DETECT_HOST_WSL_RUN="$BATS_TEST_TMPDIR/no-wsl-run" DETECT_HOST_WSL_INTEROP="$BATS_TEST_TMPDIR/no-wsl-interop"
  mkdir -p "$BATS_TEST_TMPDIR/ubin"
  printf '#!/bin/sh\necho Linux\n' >"$BATS_TEST_TMPDIR/ubin/uname"; chmod +x "$BATS_TEST_TMPDIR/ubin/uname"
  export PATH="$BATS_TEST_TMPDIR/ubin:$PATH"
}

@test "report mode reports the host from the host file (linux-cli)" {
  host_file_fixture linux-cli 'hostProfile: "linux-cli"' 'gui: false'
  run bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SYSTEM UPDATE · linux-cli"* ]]
  [[ "$output" != *"detected host"* ]]
}

@test "report mode warns about a personal.yaml that disagrees, with values and the fix, and edits nothing" {
  host_file_fixture linux-cli 'hostProfile: "linux-desktop"' 'gui: true'
  local before; before="$(cksum <"$FAKE/home/.chezmoidata/personal.yaml")"
  run bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SYSTEM UPDATE · linux-cli"* ]]
  [[ "$output" == *"detected host: linux-cli"* ]]
  [[ "$output" == *'hostProfile: "linux-desktop"'* ]]
  [[ "$output" == *"gui: true"* ]]
  [[ "$output" == *'set hostProfile: "linux-cli" and gui: false'* ]]
  [[ "$output" == *"chezmoi apply"* ]]
  [[ "$output" != *Sentinel* ]]
  [ "$(cksum <"$FAKE/home/.chezmoidata/personal.yaml")" = "$before" ]
}

@test "the warning comes before the chezmoi step in report output" {
  host_file_fixture linux-cli 'hostProfile: "linux-desktop"' 'gui: true'
  mkdir -p "$BATS_TEST_TMPDIR/cbin"
  printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/cbin/chezmoi"; chmod +x "$BATS_TEST_TMPDIR/cbin/chezmoi"
  PATH="$BATS_TEST_TMPDIR/cbin:$PATH" run bash "$FAKE/ops/update-all.sh"
  local warn_line chezmoi_line
  warn_line="$(printf '%s\n' "$output" | grep -n 'detected host: linux-cli' | head -n1 | cut -d: -f1)"
  chezmoi_line="$(printf '%s\n' "$output" | grep -n 'would run: chezmoi apply' | head -n1 | cut -d: -f1)"
  [ -n "$warn_line" ]
  [ -n "$chezmoi_line" ] || { echo "no chezmoi step line found:"; echo "$output"; return 1; }
  [ "$warn_line" -lt "$chezmoi_line" ]
}

@test "apply mode shows the warning too, before it stops or changes anything" {
  host_file_fixture linux-cli 'hostProfile: "linux-desktop"' 'gui: true'
  dirty_it
  run bash "$FAKE/ops/update-all.sh" --apply --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"detected host: linux-cli"* ]]
  [[ "$output" == *"stopped before"* ]]
  local warn_pos stop_pos
  warn_pos="$(printf '%s' "$output" | grep -bo 'detected host: linux-cli' | head -n1 | cut -d: -f1)"
  stop_pos="$(printf '%s' "$output" | grep -bo 'stopped before' | head -n1 | cut -d: -f1)"
  [ "$warn_pos" -lt "$stop_pos" ]
}

@test "no warning when HOST_PROFILE is set or the host file is absent" {
  host_file_fixture linux-cli 'hostProfile: "linux-desktop"' 'gui: true'
  HOST_PROFILE=linux-cli run bash "$FAKE/ops/update-all.sh"
  [[ "$output" != *"detected host"* ]]
  rm -f "$APP_CONFIGS_HOST_FILE"
  run bash "$FAKE/ops/update-all.sh"
  [[ "$output" != *"detected host"* ]]
}
