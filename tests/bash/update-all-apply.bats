#!/usr/bin/env bats
#
# The apply path, driven against stub tools so the real system is never
# touched. What is asserted here is the contract the updater owes the user:
# a snapshot before mutation, a rollback handle afterwards, no raw output on
# a clean run, and no attempt to upgrade packages another manager owns.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export NO_COLOR=1
  export HOME="$BATS_TEST_TMPDIR/home"
  export SYS_UPDATE_STATE_DIR="$HOME/.local/state/sys-update"
  export HOST_PROFILE=linux-desktop
  # Never let the developer's real state directories leak into a run.
  export XDG_STATE_HOME="$HOME/.local/state"
  export NIX_STATE_DIR="$BATS_TEST_TMPDIR/nix-state"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$STUB_LOG"
  # The updater commits the new lock; the fake $HOME has no git identity.
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  mkdir -p "$HOME/.local/state/nix/profiles" "$HOME/.nix-profile"
  # What `nix build --print-out-paths` yields: the conflict check needs a real
  # activation package with a home-path (an empty answer is an error).
  export STUB_HM_OUT="$BATS_TEST_TMPDIR/hm-out-default"
  mkdir -p "$STUB_HM_OUT/home-path/bin"

  # A previous Home Manager generation, so the rollback handle has something
  # real to point at.
  GEN_DIR="$BATS_TEST_TMPDIR/hm-generation-1"
  mkdir -p "$GEN_DIR"
  cat > "$GEN_DIR/activate" <<'ACT'
#!/usr/bin/env bash
printf 'activate %s
' "$*" >> "$STUB_LOG"
[[ "${STUB_ACTIVATE_NO_RELINK:-0}" == 1 ]] \
  || ln -sfn home-manager-1-link "${STUB_PROFILE_DIR:-$HOME/.local/state/nix/profiles}/home-manager"
ACT
  chmod +x "$GEN_DIR/activate"
  ln -s "$GEN_DIR" "$HOME/.local/state/nix/profiles/home-manager-1-link"
  ln -s home-manager-1-link "$HOME/.local/state/nix/profiles/home-manager"

  # A quote and a space in the path: the updater must quote its own repo path.
  FAKE="$BATS_TEST_TMPDIR/it's a repo"
  mkdir -p "$FAKE/nix"
  cp -a "$REPO_ROOT/ops" "$FAKE/ops"
  printf '{"nodes":{"nixpkgs":{"locked":{"rev":"old"}}}}\n' > "$FAKE/nix/flake.lock"
  printf '{ outputs = _: { }; }\n' > "$FAKE/nix/flake.nix"
  git -C "$FAKE" init -q
  git -C "$FAKE" add -A
  git -C "$FAKE" -c user.email=t@t -c user.name=t commit -q -m init

  # A profile with one flake-installed entry and one Home Manager owns.
  cat > "$HOME/.nix-profile/manifest.json" <<'JSON'
{"elements":{"chezmoi":{"active":true,"originalUrl":"flake:nixpkgs","storePaths":["/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-chezmoi-2.70.3"]},
             "home-manager-path":{"active":true,"storePaths":["/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-home-manager-path"]}}}
JSON

  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  for tool in nix chezmoi home-manager mise lefthook; do
    cat > "$STUBS/$tool" <<STUB
#!/usr/bin/env bash
printf '%s %s\n' "$tool" "\$*" >> "\$STUB_LOG"
case "$tool \$*" in
  "nix flake update"*)    [[ "\${FAIL_FLAKE_UPDATE:-0}" == 1 ]] && { echo "error: cannot update inputs" >&2; exit 1; }
                          printf '{"nodes":{"nixpkgs":{"locked":{"rev":"new"}}}}\n' > "$FAKE/nix/flake.lock"
                          [[ "\${STUB_HUP_AFTER_UPDATE:-0}" == 1 ]] && kill -HUP "\$PPID"
                          [[ "\${STUB_TERM_AFTER_UPDATE:-0}" == 1 ]] && kill -TERM "\$PPID"
                          [[ "\${STUB_INT_AFTER_UPDATE:-0}" == 1 ]] && kill -INT "\$PPID" ;;
  "nix flake check"*)     printf 'warning: The check omitted these incompatible systems: aarch64-darwin\n' >&2 ;;
  "nix build"*)          [[ "\${FAIL_HOST_BUILD:-0}" == 1 ]] && exit 1
                          if [[ "\$*" == *--print-out-paths* ]]; then
                            [[ "\${FAIL_PRINT_OUT:-0}" == 1 ]] && exit 1
                            [[ "\${STUB_HM_OUT_EMPTY:-0}" == 1 ]] || printf '%s\n' "\${STUB_HM_OUT:-$BATS_TEST_TMPDIR/hm-out}"
                          fi ;;
  "chezmoi managed"*)     [[ "\${CHEZMOI_MANAGED_FAIL:-0}" == 1 ]] && { echo "chezmoi: managed exploded" >&2; exit 1; } ;;
  "chezmoi status"*)      [[ "\${CHEZMOI_STATUS_FAIL:-0}" == 1 ]] && { echo "chezmoi: status exploded" >&2; exit 1; }
                          printf '%s\n' "\${CHEZMOI_STATUS:- M dot_thing}" ;;
  "chezmoi apply"*)       # STUB_TOUCH_LOCK=1: another session edits flake.lock mid-run
                          [[ "\${STUB_TOUCH_LOCK:-0}" == 1 ]] && printf '{"nodes":{"nixpkgs":{"locked":{"rev":"foreign"}}}}\n' > "$FAKE/nix/flake.lock" ;;
  "home-manager switch"*) printf 'There are 394 unread and relevant news items.\n'
                          if [[ "\${STUB_HM_NO_RELINK:-0}" != 1 ]]; then
                            ln -sfn "\${STUB_HM_OUT:-$BATS_TEST_TMPDIR/hm-out}" "\${STUB_PROFILE_DIR:-$HOME/.local/state/nix/profiles}/home-manager-2-link"
                            ln -sfn home-manager-2-link "\${STUB_PROFILE_DIR:-$HOME/.local/state/nix/profiles}/home-manager"
                          fi ;;
esac
exit 0
STUB
    chmod +x "$STUBS/$tool"
  done

  mkdir -p "$BATS_TEST_TMPDIR/hm-out"

  # Tools the lifecycle work calls directly. None of them touches real state.
  cat > "$STUBS/nix-store" <<'STUB'
#!/usr/bin/env bash
printf 'nix-store %s\n' "$*" >> "$STUB_LOG"
[[ "${FAIL_GCROOT:-0}" == 1 ]] && { echo "nix-store: cannot add root" >&2; exit 1; }
target="" root=""
while (($#)); do
  case "$1" in
    --realise) target="$2"; shift ;;
    --add-root) root="$2"; shift ;;
    -q) exit 0 ;;
  esac
  shift
done
if [[ -n "$root" ]]; then mkdir -p "$(dirname "$root")"; ln -sfn "$target" "$root"; fi
exit 0
STUB
  cat > "$STUBS/nix-env" <<'STUB'
#!/usr/bin/env bash
printf 'nix-env %s\n' "$*" >> "$STUB_LOG"
profile="" target=""
while (($#)); do
  case "$1" in
    --profile) profile="$2"; shift ;;
    --set) target="$2"; shift ;;
  esac
  shift
done
if [[ -n "$profile" && -n "$target" ]]; then
  ln -sfn "$target" "$profile-99-link"
  ln -sfn "$(basename "$profile")-99-link" "$profile"
fi
exit 0
STUB
  cat > "$STUBS/xdg-mime" <<'STUB'
#!/usr/bin/env bash
[[ "${STUB_MIME_EMPTY:-0}" == 1 ]] && exit 0
printf '%s\n' "${STUB_MIME-brave-browser.desktop}"
STUB
  cat > "$STUBS/brave" <<'STUB'
#!/usr/bin/env bash
[[ "${FAIL_BRAVE:-0}" == 1 ]] && exit 1
echo "Brave Browser 1.0.0"
STUB
  chmod +x "$STUBS/nix-store" "$STUBS/nix-env" "$STUBS/xdg-mime" "$STUBS/brave"
  PATH="$STUBS:$PATH"
}

run_update() { run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup --skip-verify "$@"; }

# Put the lock back to "old" so the next run has an input to update again.
reset_repo() {
  git -C "$FAKE" reset -q --hard "$(git -C "$FAKE" rev-list --max-parents=0 HEAD)"
  : > "$STUB_LOG"
}
commits() { git -C "$FAKE" rev-list --count HEAD; }

@test "a clean run keeps raw command output off the terminal" {
  run_update
  [ "$status" -eq 0 ]
  [[ "$output" != *"unread and relevant news items"* ]]
  [[ "$output" == *"home-manager"* ]]
}

@test "the raw output is kept in a run log" {
  run_update
  log="$(ls "$SYS_UPDATE_STATE_DIR"/runs/*.log | head -1)"
  grep -q "unread and relevant news items" "$log"
  [[ "$output" == *"full log"* ]]
}

@test "noisy warnings are re-stated as classified notes" {
  run_update
  [[ "$output" == *"Warnings"* ]]
  [[ "$output" == *"aarch64-darwin"* ]]
  [[ "$output" == *"394"* ]]
}

@test "a rollback handle is recorded before anything is applied" {
  run_update
  [ -f "$SYS_UPDATE_STATE_DIR/last-run" ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  grep -q '^flake_lock_backup=' "$meta"
  grep -q '^repo=' "$meta"
  [[ "$output" == *"sys-update rollback"* ]]
  # the pre-update lock is recoverable
  grep -q '"rev":"old"' "$(sed -n 's/^flake_lock_backup=//p' "$meta")"
}

@test "nix profile is never asked to upgrade what Home Manager owns" {
  run_update
  grep -q 'nix profile upgrade chezmoi' "$STUB_LOG"
  ! grep -q 'home-manager-path' "$STUB_LOG"
}

@test "chezmoi is applied without --force unless it is asked for" {
  run_update
  if grep -q 'chezmoi apply.*--force' "$STUB_LOG"; then echo 'assertion failed: expected no match' >&2; return 1; fi
  reset_repo
  run_update --force
  grep -q 'chezmoi apply.*--force' "$STUB_LOG"
}

@test "chezmoi never prompts: a hand-edited target fails the step instead" {
  run_update
  grep -q 'chezmoi apply --no-tty' "$STUB_LOG"
}

@test "a hand-edited managed file stops the update before anything is mutated" {
  export CHEZMOI_STATUS='MM .gitconfig'
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"stopped before"* ]]
  [[ "$output" == *".gitconfig"* ]]
  # names a way to inspect the edit and a way past it
  [[ "$output" == *"chezmoi diff"* ]]
  [[ "$output" == *"--force"* ]]
  if grep -q 'nix flake update' "$STUB_LOG"; then echo 'assertion failed: expected no match' >&2; return 1; fi
  if grep -q 'chezmoi apply' "$STUB_LOG"; then echo 'assertion failed: expected no match' >&2; return 1; fi
  [ "$(commits)" -eq 1 ]
}

@test "a hand edit that already matches the repo is not a conflict" {
  export CHEZMOI_STATUS='M  .gitconfig'
  run_update
  [ "$status" -eq 0 ]
  grep -q 'chezmoi apply --no-tty' "$STUB_LOG"
}

@test "--force turns a hand-edited managed file into a warning and overwrites it" {
  export CHEZMOI_STATUS='MM .gitconfig'
  run_update --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"overwritten"* ]]
  grep -q 'chezmoi apply --no-tty --force' "$STUB_LOG"
}

@test "the flake lock is only checked for this host unless --full-check" {
  run_update
  if grep -q 'all-systems' "$STUB_LOG"; then echo 'assertion failed: expected no match' >&2; return 1; fi
  reset_repo
  run_update --full-check
  grep -q 'flake check --all-systems' "$STUB_LOG"
}

@test "changed flake inputs are counted, not dumped" {
  run_update
  [[ "$output" == *"flake inputs"* ]]
  [[ "$output" == *"1 input(s) updated"* ]]
}

@test "the host closure builds before dotfiles are applied" {
  run_update
  [ "$status" -eq 0 ]
  build_line="$(grep -n 'nix build --no-link.*homeConfigurations.linux-desktop.activationPackage' "$STUB_LOG" | head -n1 | cut -d: -f1)"
  apply_line="$(grep -n 'chezmoi apply' "$STUB_LOG" | cut -d: -f1)"
  [ "$build_line" -lt "$apply_line" ]
}

@test "a failed host build leaves dotfiles and the active generation untouched" {
  export FAIL_HOST_BUILD=1
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"host build"* ]]
  if grep -q 'chezmoi apply\|home-manager switch\|mise upgrade' "$STUB_LOG"; then echo 'assertion failed: expected no match' >&2; return 1; fi
  [ "$(commits)" -eq 1 ]
}

@test "macOS builds the darwin system before activation" {
  export HOST_PROFILE=macos
  cp "$STUBS/home-manager" "$STUBS/darwin-rebuild"
  # The activation check reads the system link; there is no real one here.
  ln -s "$STUB_HM_OUT" "$BATS_TEST_TMPDIR/current-system"
  export SYS_UPDATE_DARWIN_SYSTEM_LINK="$BATS_TEST_TMPDIR/current-system"
  run_update
  [ "$status" -eq 0 ]
  grep -q 'nix build --no-link.*darwinConfigurations.macos.system' "$STUB_LOG"
}

@test "a successful update commits the new lock so the next run starts clean" {
  run_update
  [ "$status" -eq 0 ]
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
  [ "$(git -C "$FAKE" log -1 --format=%s)" = "chore(nix): update flake inputs" ]
  [ "$(git -C "$FAKE" diff --name-only HEAD~1 HEAD)" = "nix/flake.lock" ]
  [[ "$output" == *"committed"* ]]

  # the regression: a second run used to stop at the dirty-worktree gate
  run_update
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopped before"* ]]
  # nothing changed this time, so nothing new is committed
  [ "$(commits)" -eq 2 ]
}

prepare_brave_lock() {
  mkdir -p "$FAKE/nix/packages/brave"
  cp "$REPO_ROOT/nix/packages/brave/release.json" "$FAKE/nix/packages/brave/"
  cat > "$FAKE/ops/update-brave.sh" <<'STUB'
#!/usr/bin/env bash
[[ "${FAIL_BRAVE_UPDATE:-0}" == 1 ]] && exit 1
root="$(cd "$(dirname "$0")/.." && pwd)"
jq '.version = "999.0.0"' "$root/nix/packages/brave/release.json" > "$root/nix/packages/brave/release.json.tmp"
mv "$root/nix/packages/brave/release.json.tmp" "$root/nix/packages/brave/release.json"
STUB
  git -C "$FAKE" add nix/packages/brave/release.json ops/update-brave.sh
  git -C "$FAKE" commit -q -m 'add browser lock fixture'
}

@test "Brave updates are committed with the flake lock and the next run stays clean" {
  prepare_brave_lock
  run_update
  [ "$status" -eq 0 ]
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
  git -C "$FAKE" diff --name-only HEAD~1 HEAD | grep -q 'nix/packages/brave/release.json'
  run_update
  [ "$status" -eq 0 ]
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
}

@test "rollback restores both the browser release and flake lock" {
  prepare_brave_lock
  run_update
  [ "$status" -eq 0 ]
  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" rollback --yes
  [ "$status" -eq 0 ]
  cmp "$REPO_ROOT/nix/packages/brave/release.json" "$FAKE/nix/packages/brave/release.json"
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
}

@test "Brave metadata failure stops before configuration is applied" {
  prepare_brave_lock
  export FAIL_BRAVE_UPDATE=1
  run_update
  [ "$status" -ne 0 ]
  ! grep -q 'nix build\|chezmoi apply\|home-manager switch' "$STUB_LOG"
}

@test "a failed update leaves the lock uncommitted" {
  cat > "$STUBS/home-manager" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
  chmod +x "$STUBS/home-manager"
  run_update
  [ "$status" -ne 0 ]
  [ "$(commits)" -eq 1 ]
}

@test "--allow-dirty commits only the lock and leaves other changes alone" {
  printf 'scratch\n' > "$FAKE/untracked"
  printf 'edit\n' > "$FAKE/nix/flake.nix.note"
  git -C "$FAKE" add nix/flake.nix.note
  run_update --allow-dirty
  [ "$status" -eq 0 ]
  [ "$(git -C "$FAKE" diff --name-only HEAD~1 HEAD)" = "nix/flake.lock" ]
  [ "$(git -C "$FAKE" status --porcelain)" = "$(printf 'A  nix/flake.nix.note\n?? untracked')" ]
}

@test "a lock that already had local edits is never committed for you" {
  printf '{"nodes":{"nixpkgs":{"locked":{"rev":"mine"}}}}\n' > "$FAKE/nix/flake.lock"
  run_update --allow-dirty
  [ "$status" -eq 0 ]
  [ "$(commits)" -eq 1 ]
  [[ "$output" == *"not committed"* ]]
}

@test "a failing step stops the run and points at the rollback" {
  cat > "$STUBS/home-manager" <<'STUB'
#!/usr/bin/env bash
printf 'home-manager %s\n' "$*" >> "$STUB_LOG"
echo "error: attribute 'linux-desktop' missing" >&2
exit 1
STUB
  chmod +x "$STUBS/home-manager"
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"Update failed"* ]]
  [[ "$output" == *"attribute 'linux-desktop' missing"* ]]
  # later steps never ran
  ! grep -q 'mise upgrade' "$STUB_LOG"
}

@test "rollback restores the previous generation and the previous lock" {
  run_update
  grep -q '"rev":"new"' "$FAKE/nix/flake.lock"
  : > "$STUB_LOG"

  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" rollback --yes
  [ "$status" -eq 0 ]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
  grep -q '^activate' "$STUB_LOG"
  [[ "$output" == *"generation 1"* ]]
}

@test "rollback without a recorded run says so instead of guessing" {
  rm -rf "$SYS_UPDATE_STATE_DIR"
  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" rollback --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"no recorded run"* ]]
}

@test "verification says how long until the AI CLIs need a new login" {
  cat > "$STUBS/ai-auth-status" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == --summary ]] || exit 2
echo "Claude ${CLAUDE_DAYS}d left · Codex signed in"
(( CLAUDE_DAYS >= 7 ))
STUB
  printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/systemctl"
  chmod +x "$STUBS/ai-auth-status" "$STUBS/systemctl"
  verify_run() { run env PATH="$STUBS:$PATH" HOST_PROFILE=linux-cli CLAUDE_DAYS="$1" \
    bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup; }

  verify_run 23
  [ "$status" -eq 0 ]
  [[ "$output" == *"AI logins"*"Claude 23d left · Codex signed in"* ]]

  reset_repo
  verify_run 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"AI logins"*"Claude 3d left"* ]]
  [[ "$output" == *"log in again before you travel"* ]]
}

@test "a nix-profile entry that collides with Home Manager stops before the switch" {
  pkg="$BATS_TEST_TMPDIR/parallel-pkg"; mkdir -p "$pkg/bin"; touch "$pkg/bin/parallel"
  out="$BATS_TEST_TMPDIR/hm-out"; mkdir -p "$out/home-path/bin"; touch "$out/home-path/bin/parallel"
  cat > "$HOME/.nix-profile/manifest.json" <<JSON
{"elements":{"parallel":{"active":true,"originalUrl":"flake:nixpkgs","storePaths":["$pkg"]},
             "home-manager-path":{"active":true,"storePaths":["/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-home-manager-path"]}}}
JSON
  STUB_HM_OUT="$out" run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"nix profile remove parallel"* ]]
  run grep -c '^home-manager switch' "$STUB_LOG"; [ "$output" = 0 ]
  run grep -c '^chezmoi apply' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "home-manager switch backs up files it would clobber" {
  run_update
  grep -q '^home-manager switch .*-b hm-bak' "$STUB_LOG"
}

@test "a missing snapshot script stops the apply before anything runs" {
  rm "$FAKE/ops/snapshot-home.sh"
  run_update --allow-dirty
  [ "$status" -ne 0 ]
  [[ "$output" == *"snapshot"* ]]
  ! grep -q '^home-manager switch' "$STUB_LOG"
}

@test "a non-executable snapshot script stops the apply" {
  chmod -x "$FAKE/ops/snapshot-home.sh"
  run_update --allow-dirty
  [ "$status" -ne 0 ]
  [[ "$output" == *"snapshot"* ]]
  ! grep -q '^home-manager switch' "$STUB_LOG"
}

@test "the snapshot dir is taken from --print-dir, not parsed from logs" {
  export DOTFILES_SNAPSHOT_ROOT="$BATS_TEST_TMPDIR/my snaps"
  run_update
  [ "$status" -eq 0 ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  dir="$(sed -n 's/^snapshot_dir=//p' "$meta")"
  [[ "$dir" == "$DOTFILES_SNAPSHOT_ROOT"/* ]]
  [ -f "$dir/MANIFEST.txt" ]
}

@test "a failed snapshot stops before any update and shows the cause" {
  export CHEZMOI_MANAGED_FAIL=1
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"snapshot failed"* ]]
  [[ "$output" == *"managed exploded"* ]]
  run ! grep -q '^nix flake update' "$STUB_LOG"
  run ! grep -q '^home-manager switch' "$STUB_LOG"
}

# ── T-0010 lock, run id, metadata, pruning ──────────────────────────────────

teardown() {
  [[ -n "${HOLDER:-}" ]] && kill "$HOLDER" 2>/dev/null
  chmod -R u+w "$BATS_TEST_TMPDIR" 2>/dev/null
  return 0
}

# A live holder of the flock lock, standing in for another sys-update.
hold_flock() {
  mkdir -p "$SYS_UPDATE_STATE_DIR"
  bash -c 'exec 9>"$1"; flock -n 9 || exit 1; echo ready; exec sleep 60' _ \
    "$SYS_UPDATE_STATE_DIR/lock" 3>&- > "$BATS_TEST_TMPDIR/holder.out" &
  HOLDER=$!
  for _ in $(seq 100); do [[ -s "$BATS_TEST_TMPDIR/holder.out" ]] && return 0; sleep 0.05; done
  return 1
}

# A fixed UTC timestamp, so two runs in "the same second" are reproducible.
freeze_date() {
  local real_date; real_date="$(command -v date)"
  cat > "$STUBS/date" <<STUB
#!/usr/bin/env bash
if [[ "\$1" == -u && "\$2" == +%Y%m%dT%H%M%SZ ]]; then echo 20260101T000000Z; exit 0; fi
exec "$real_date" "\$@"
STUB
  chmod +x "$STUBS/date"
}

no_rm_hint() { [[ ! "$1" =~ (^|[^a-z])rm[[:space:]] ]]; }

@test "S01: a running update holds the flock lock: exit 5 and no rm hint" {
  hold_flock
  run_update
  [ "$status" -eq 5 ]
  [[ "$output" == *"another sys-update"* ]]
  no_rm_hint "$output"
  [ -f "$SYS_UPDATE_STATE_DIR/lock" ]
  run grep -c 'nix flake update' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "S02: the lock is free after a failure and the lock file is kept" {
  export FAIL_HOST_BUILD=1
  run_update
  [ "$status" -ne 0 ]
  [ -f "$SYS_UPDATE_STATE_DIR/lock" ]
  flock -n "$SYS_UPDATE_STATE_DIR/lock" true
}

@test "S02: a successful run leaves the lock file in place and free" {
  run_update
  [ "$status" -eq 0 ]
  [ -f "$SYS_UPDATE_STATE_DIR/lock" ]
  flock -n "$SYS_UPDATE_STATE_DIR/lock" true
}

@test "S03: mkdir mode refuses a live foreign owner and prints the removal command" {
  export SYS_UPDATE_FORCE_MKDIR_LOCK=1
  sleep 60 3>&- & HOLDER=$!
  mkdir -p "$SYS_UPDATE_STATE_DIR/lock.d"
  printf '%s %s\n' "$HOLDER" "20260101T000000Z-$HOLDER" > "$SYS_UPDATE_STATE_DIR/lock.d/owner"
  run_update
  [ "$status" -eq 5 ]
  [[ "$output" == *"$HOLDER"* ]]
  [[ "$output" == *"sleep"* ]]
  [[ "$output" == *"rm -rf"*"lock.d"* ]]
  [[ "$output" == *"reused"* ]]
  [ -d "$SYS_UPDATE_STATE_DIR/lock.d" ]
  run grep -c 'nix flake update' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "S04: an owner-less lock directory counts as held" {
  export SYS_UPDATE_FORCE_MKDIR_LOCK=1
  mkdir -p "$SYS_UPDATE_STATE_DIR/lock.d"
  run_update
  [ "$status" -eq 5 ]
  [[ "$output" == *"rm -rf"*"lock.d"* ]]
  [ -d "$SYS_UPDATE_STATE_DIR/lock.d" ]
}

@test "S05: only the owner removes a mkdir lock" {
  export SYS_UPDATE_FORCE_MKDIR_LOCK=1
  # a refused run must not remove someone else's lock
  mkdir -p "$SYS_UPDATE_STATE_DIR/lock.d"
  printf '1 other-run\n' > "$SYS_UPDATE_STATE_DIR/lock.d/owner"
  run_update
  [ "$status" -eq 5 ]
  [ "$(cat "$SYS_UPDATE_STATE_DIR/lock.d/owner")" = "1 other-run" ]
  rm -rf "$SYS_UPDATE_STATE_DIR/lock.d"
  # the owner removes its own lock after success and after failure
  run_update
  [ "$status" -eq 0 ]
  [ ! -e "$SYS_UPDATE_STATE_DIR/lock.d" ]
  reset_repo
  FAIL_HOST_BUILD=1 run_update
  [ "$status" -ne 0 ]
  [ ! -e "$SYS_UPDATE_STATE_DIR/lock.d" ]
}

@test "S05: the mkdir lock owner file names this process and run id" {
  export SYS_UPDATE_FORCE_MKDIR_LOCK=1
  cat > "$STUBS/mise" <<'STUB'
#!/usr/bin/env bash
cat "$SYS_UPDATE_STATE_DIR/lock.d/owner" >> "$STUB_LOG"
exit 0
STUB
  run_update
  [ "$status" -eq 0 ]
  grep -Eq '^[0-9]+ [0-9]{8}T[0-9]{6}Z-[0-9]+$' "$STUB_LOG"
}

@test "report mode takes no lock and says so when an update is running" {
  hold_flock
  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"update is running"* ]]
}

@test "S06: a metadata write failure stops the run before anything changes" {
  mkdir -p "$SYS_UPDATE_STATE_DIR/runs"
  chmod 555 "$SYS_UPDATE_STATE_DIR/runs"
  run_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"metadata"* ]]
  run grep -c 'nix flake update' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "S07: two runs in the same second get distinct run ids" {
  freeze_date
  run_update
  [ "$status" -eq 0 ]
  reset_repo
  run_update
  [ "$status" -eq 0 ]
  [ "$(ls "$SYS_UPDATE_STATE_DIR"/runs/*.meta | wc -l)" -eq 2 ]
  for m in "$SYS_UPDATE_STATE_DIR"/runs/*.meta; do
    [[ "$(sed -n 's/^run_id=//p' "$m")" =~ ^20260101T000000Z-[0-9]+$ ]]
  done
}

@test "S08: a failed last-run pointer write stops before the update" {
  mkdir -p "$SYS_UPDATE_STATE_DIR/last-run"
  run_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"last-run"* ]]
  run grep -c 'nix flake update' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "S08: a failed snapshot leaves the previous last-run pointer alone" {
  run_update
  [ "$status" -eq 0 ]
  before="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  reset_repo
  export CHEZMOI_MANAGED_FAIL=1
  run_update
  [ "$status" -ne 0 ]
  [ "$(cat "$SYS_UPDATE_STATE_DIR/last-run")" = "$before" ]
}

@test "S09: the last-run record is complete, atomic and carries the run status" {
  run_update
  [ "$status" -eq 0 ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  [ -f "$meta" ]
  [ -z "$(ls "$SYS_UPDATE_STATE_DIR" | grep 'last-run.tmp' || true)" ]
  for key in run_id repo host hm_profile hm_path_before hm_gen_before lock_was_clean flake_lock_backup snapshot_dir; do
    grep -q "^$key=." "$meta"
  done
  [ "$(sed -n 's/^hm_gen_before=//p' "$meta")" = 1 ]
  [ "$(sed -n 's/^hm_profile=//p' "$meta")" = "$HOME/.local/state/nix/profiles/home-manager" ]
  [ "$(sed -n 's/^lock_was_clean=//p' "$meta")" = 1 ]
  grep -q '^status=started$' "$meta"
  [ "$(sed -n 's/^status=//p' "$meta" | tail -1)" = done ]
  [ "$(sed -n 's/^exit_code=//p' "$meta" | tail -1)" = 0 ]
}

@test "S09: a run that fails records its exit code" {
  export FAIL_HOST_BUILD=1
  run_update
  [ "$status" -eq 1 ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  [ "$(sed -n 's/^exit_code=//p' "$meta" | tail -1)" = 1 ]
}

@test "S45: pruning removes the oldest runs' files and keeps the newest" {
  export SYS_UPDATE_KEEP_RUNS=2
  runs="$SYS_UPDATE_STATE_DIR/runs"
  mkdir -p "$runs"
  for d in 20250101 20250102 20250103 20250104; do
    id="${d}T000000Z-1"
    for ext in log meta flake.lock brave.json; do : > "$runs/$id.$ext"; done
    mkdir -p "$SYS_UPDATE_STATE_DIR/gcroots/$id"
  done
  run_update
  [ "$status" -eq 0 ]
  for d in 20250101 20250102 20250103; do
    [ -z "$(ls "$runs" | grep "^${d}T" || true)" ]
    [ ! -e "$SYS_UPDATE_STATE_DIR/gcroots/${d}T000000Z-1" ]
  done
  [ -e "$runs/20250104T000000Z-1.meta" ]
  [ -d "$SYS_UPDATE_STATE_DIR/gcroots/20250104T000000Z-1" ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  [ -f "$meta" ]
}

@test "S45: pruning never removes the run that last-run points at" {
  export SYS_UPDATE_KEEP_RUNS=1
  run_update
  [ "$status" -eq 0 ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  [ -f "$meta" ]
  [ -f "${meta%.meta}.log" ]
}

@test "S48: a step sees no inherited lock descriptor while the lock is held" {
  cat > "$STUBS/nix" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" == "flake update"* ]]; then
  out="$BATS_TEST_TMPDIR/step.out"
  : > "$out"
  [[ -e /proc/$$/fd/9 ]] && echo fd9-open >> "$out"
  for fd in /proc/$$/fd/*; do
    [[ "$(readlink -f "$fd" 2>/dev/null)" == "$SYS_UPDATE_STATE_DIR/lock" ]] && echo "lock-fd-inherited $fd" >> "$out"
  done
  if flock -n "$SYS_UPDATE_STATE_DIR/lock" true; then echo lock-free >> "$out"; else echo lock-held >> "$out"; fi
  echo "reexec=${SYS_UPDATE_REEXEC-unset} runid=${SYS_UPDATE_RUN_ID-unset} pulled=${SYS_UPDATE_PULLED_FROM-unset}" >> "$out"
  exit 1
fi
exit 0
STUB
  run env SYS_UPDATE_REEXEC=1 SYS_UPDATE_RUN_ID=zzz SYS_UPDATE_PULLED_FROM=abc \
    PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup --skip-verify
  [ "$status" -eq 1 ]
  grep -q '^lock-held$' "$BATS_TEST_TMPDIR/step.out"
  run grep -E 'fd9-open|lock-fd-inherited' "$BATS_TEST_TMPDIR/step.out"
  [ "$status" -eq 1 ]
  grep -q 'reexec=unset runid=unset pulled=unset' "$BATS_TEST_TMPDIR/step.out"
}

@test "S48: SIGTERM exits 143, records it and frees the lock" {
  export STUB_TERM_AFTER_UPDATE=1
  run_update
  [ "$status" -eq 143 ]
  flock -n "$SYS_UPDATE_STATE_DIR/lock" true
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  [ "$(sed -n 's/^exit_code=//p' "$meta" | tail -1)" = 143 ]
}

@test "G-03: SIGHUP exits 129 and records a non-zero exit code" {
  export STUB_HUP_AFTER_UPDATE=1
  run_update
  [ "$status" -eq 129 ]
  flock -n "$SYS_UPDATE_STATE_DIR/lock" true
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  [ "$(sed -n 's/^exit_code=//p' "$meta" | tail -1)" = 129 ]
}

@test "G-04: a flake.lock backup failure stops before PREPARE and leaves no started record" {
  # A cp that refuses to write the flake.lock backup; everything else is real.
  cat > "$STUBS/cp" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do [[ "$a" == *.flake.lock ]] && { echo "cp: cannot write $a" >&2; exit 1; }; done
PATH="${PATH//$(dirname "$0"):/}"; exec cp "$@"
STUB
  chmod +x "$STUBS/cp"
  run_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"backup failed"* ]]
  [ ! -e "$SYS_UPDATE_STATE_DIR/last-run" ]
  run grep -c 'nix flake update' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "G-09: a failed nix flake update stops the run and leaves the lock uncommitted" {
  export FAIL_FLAKE_UPDATE=1
  run_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"nix flake update failed"* ]]
  [[ "$output" == *"cannot update inputs"* ]]
  [ "$(commits)" -eq 1 ]
  ! grep -q 'home-manager switch\|chezmoi apply' "$STUB_LOG"
}

@test "S48: the progress ticker does not keep the lock after SIGINT on a terminal" {
  command -v script >/dev/null || skip "script(1) not available"
  export STUB_INT_AFTER_UPDATE=1
  cmd="$(printf 'bash %q --apply --yes --no-cleanup --skip-verify; rc=$?; if flock -n %q true; then echo LOCK_FREE; else echo LOCK_HELD; fi; echo "rc=$rc"' \
    "$FAKE/ops/update-all.sh" "$SYS_UPDATE_STATE_DIR/lock")"
  # bats -j runs tests as background jobs, which start with SIGINT ignored,
  # and bash can neither trap nor reset a signal ignored at startup. Restore
  # the default disposition so the trap under test can see the interrupt.
  # script(1) runs the command with $SHELL; pin bash so a login fish (which
  # rewrites PATH and drops the stubs) is never in between.
  run env SHELL="$(command -v bash)" \
    script -qec "env --default-signal=INT bash -c $(printf '%q' "$cmd")" /dev/null
  [[ "$output" == *"LOCK_FREE"* ]]
  [[ "$output" == *"rc=130"* ]]
  flock -n "$SYS_UPDATE_STATE_DIR/lock" true
}

# ── T-0010 host, profile path, PREPARE gaps, lefthook ───────────────────────

last_meta() { cat "$SYS_UPDATE_STATE_DIR/last-run"; }
meta_value() { sed -n "s/^$1=//p" "$(last_meta)" | tail -1; }

# A Home Manager profile directory at <root>/nix/profiles, generation <n>.
make_profile_dir() {
  local dir="$1" gen="$2"
  mkdir -p "$dir"
  ln -s "$GEN_DIR" "$dir/home-manager-$gen-link"
  ln -s "home-manager-$gen-link" "$dir/home-manager"
}

@test "S12: the Home Manager profile follows XDG_STATE_HOME" {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/xdg"
  export STUB_PROFILE_DIR="$XDG_STATE_HOME/nix/profiles"
  make_profile_dir "$STUB_PROFILE_DIR" 7
  run_update
  [ "$status" -eq 0 ]
  [ "$(meta_value hm_profile)" = "$XDG_STATE_HOME/nix/profiles/home-manager" ]
  [ "$(meta_value hm_gen_before)" = 7 ]
}

@test "S12: without an XDG profile directory the per-user Nix profile directory is used" {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/no-such-xdg"
  user="${USER:-$(id -un)}"
  export STUB_PROFILE_DIR="$NIX_STATE_DIR/profiles/per-user/$user"
  make_profile_dir "$STUB_PROFILE_DIR" 5
  run_update
  [ "$status" -eq 0 ]
  [ "$(meta_value hm_profile)" = "$STUB_PROFILE_DIR/home-manager" ]
  [ "$(meta_value hm_gen_before)" = 5 ]
}

@test "S12: no profile directory at all stops an apply before anything changes" {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/no-such-xdg"
  run_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"home-manager profile"* ]]
  [[ "$output" == *"stopped before"* ]]
  run grep -c 'nix flake update' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "S12: no profile directory is only a warning in report mode" {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/no-such-xdg"
  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"home-manager profile"* ]]
}

@test "S13: an empty second build result stops before dotfiles or the switch" {
  export STUB_HM_OUT_EMPTY=1
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"host build"* ]]
  run grep -c '^chezmoi apply\|^home-manager switch' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "S14: a failing second build stops before dotfiles or the switch" {
  export FAIL_PRINT_OUT=1
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"host build"* ]]
  run grep -c '^chezmoi apply\|^home-manager switch' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "S14: a second build result that is not a directory stops the update" {
  export STUB_HM_OUT="$BATS_TEST_TMPDIR/does-not-exist"
  run_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"host build"* ]]
  run grep -c '^chezmoi apply\|^home-manager switch' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "S15: a chezmoi status failure is not read as 'no conflicts'" {
  export CHEZMOI_STATUS_FAIL=1
  run_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"chezmoi status"* ]]
  [[ "$output" == *"stopped before"* ]]
  run grep -c 'nix flake update' "$STUB_LOG"; [ "$output" = 0 ]
}

@test "S15: a chezmoi status failure is a warning in report mode" {
  export CHEZMOI_STATUS_FAIL=1
  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"chezmoi status"* ]]
}

@test "S16: the flake.lock hash written by the update is recorded, even when a later step fails" {
  export FAIL_HOST_BUILD=1
  run_update
  [ "$status" -ne 0 ]
  # the failed run restored the old lock; the written content is kept as .failed
  [ "$(meta_value flake_lock_hash_written)" = "$(git hash-object "$(meta_value flake_lock_backup).failed")" ]
  [ "$(meta_value flake_lock_hash_written)" != "$(git -C "$FAKE" hash-object nix/flake.lock)" ]
  git -C "$FAKE" diff --quiet -- nix/flake.lock
}

@test "S17: the Brave release hash is recorded after the writer, even when it fails" {
  prepare_brave_lock
  original="$(git -C "$FAKE" hash-object nix/packages/brave/release.json)"
  FAIL_BRAVE_UPDATE=1 run_update
  [ "$status" -ne 0 ]
  [ "$(meta_value brave_release_hash_written)" = "$original" ]
  reset_repo
  run_update
  [ "$status" -eq 0 ]
  [ "$(meta_value brave_release_hash_written)" = "$(git -C "$FAKE" hash-object nix/packages/brave/release.json)" ]
  [ "$(meta_value brave_release_hash_written)" != "$original" ]
}

@test "S46: lefthook runs in a repository path containing a quote and a space" {
  cat > "$STUBS/lefthook" <<'STUB'
#!/usr/bin/env bash
printf 'lefthook %s\n' "$*" >> "$STUB_LOG"
pwd -P >> "$STUB_LOG"
exit 0
STUB
  run_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"git hooks"*"synced"* ]]
  grep -q '^lefthook install$' "$STUB_LOG"
  grep -qxF "$(cd "$FAKE" && pwd -P)" "$STUB_LOG"
}

@test "S51: an empty Home Manager package set counts as zero packages, not one" {
  run_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 Home Manager packages recorded"* ]]
}

# ── T-0010 Gate B: phases, EXIT restore, profile-target check (T3) ──────────

# The statuses of the last run, in order, space separated.
statuses() { sed -n 's/^status=//p' "$(cat "$SYS_UPDATE_STATE_DIR/last-run")" | paste -sd' ' -; }

# A home-manager stub that fails; STUB_FAIL_HM_RELINK=1 moves the profile first.
failing_home_manager() {
  cat > "$STUBS/home-manager" <<'STUB'
#!/usr/bin/env bash
printf 'home-manager %s\n' "$*" >> "$STUB_LOG"
if [[ "${STUB_FAIL_HM_RELINK:-0}" == 1 ]]; then
  ln -sfn "$BATS_TEST_TMPDIR/hm-out" "$HOME/.local/state/nix/profiles/home-manager-2-link"
  ln -sfn home-manager-2-link "$HOME/.local/state/nix/profiles/home-manager"
fi
echo "error: switch exploded" >&2
exit 1
STUB
  chmod +x "$STUBS/home-manager"
}

@test "S20: a successful update records every phase, in order" {
  run_update
  [ "$status" -eq 0 ]
  [ "$(statuses)" = "started prepared activating activated verify-skipped committed done" ]
}

@test "S18: a switch that leaves the profile elsewhere fails, even with --skip-verify" {
  export STUB_HM_NO_RELINK=1
  run_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not point at the built closure"* ]]
  [ "$(commits)" -eq 1 ]
  [ "$(statuses | awk '{print $NF}')" = "failed:activate" ]
}

@test "S19: a failed switch that moved the profile says so" {
  failing_home_manager
  export STUB_FAIL_HM_RELINK=1
  run_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"the profile moved"* ]]
  [[ "$output" == *"sys-update rollback"* ]]
}

@test "S21: a failure while preparing restores the lock the update wrote" {
  export FAIL_HOST_BUILD=1
  run_update
  [ "$status" -eq 1 ]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
  [ "$(statuses | awk '{print $NF}')" = "failed:prepare" ]
}

@test "S21: a failure while activating restores the lock and names the rollback" {
  failing_home_manager
  run_update
  [ "$status" -eq 1 ]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
  [ "$(statuses | awk '{print $NF}')" = "failed:activate" ]
  [[ "$output" == *"sys-update rollback"* ]]
}

@test "S22: a lock somebody else changed during the run is kept, not overwritten" {
  failing_home_manager
  export STUB_TOUCH_LOCK=1
  run_update
  [ "$status" -eq 1 ]
  grep -q '"rev":"foreign"' "$FAKE/nix/flake.lock"
  [[ "$output" == *"left in place"* ]]
}

@test "S23: a restore keeps the failed content as a .failed copy outside the repo" {
  export FAIL_HOST_BUILD=1
  run_update
  [ "$status" -eq 1 ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  failed="$(sed -n 's/^flake_lock_backup=//p' "$meta").failed"
  [ -f "$failed" ]
  grep -q '"rev":"new"' "$failed"
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
}

@test "S49: an interrupt before the writer finished restores a lock that was clean" {
  export STUB_TERM_AFTER_UPDATE=1
  run_update
  [ "$status" -eq 143 ]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
}

@test "S50: an interrupt keeps a lock that had local edits before the run" {
  printf '{"nodes":{"nixpkgs":{"locked":{"rev":"mine"}}}}\n' > "$FAKE/nix/flake.lock"
  export STUB_TERM_AFTER_UPDATE=1
  run_update --allow-dirty
  [ "$status" -eq 143 ]
  grep -q '"rev":"new"' "$FAKE/nix/flake.lock"
  [[ "$output" == *"left in place"* ]]
}

@test "a failed snapshot is recorded as failed:snapshot" {
  export CHEZMOI_MANAGED_FAIL=1
  run_update
  [ "$status" -ne 0 ]
  meta="$(ls "$SYS_UPDATE_STATE_DIR"/runs/*.meta | head -1)"
  [ "$(sed -n 's/^status=//p' "$meta" | tail -1)" = "failed:snapshot" ]
}

@test "maintenance runs after the lock is committed, so a failing one cannot block it" {
  cat > "$STUBS/mise" <<'STUB'
#!/usr/bin/env bash
printf 'mise %s\n' "$*" >> "$STUB_LOG"
if [[ "$1" == upgrade ]]; then
  git -C "$FAKE_REPO" rev-list --count HEAD > "$BATS_TEST_TMPDIR/mise.commits"
  exit 1
fi
exit 0
STUB
  chmod +x "$STUBS/mise"
  export FAKE_REPO="$FAKE"
  run_update
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/mise.commits")" -eq 2 ]
  [ "$(commits)" -eq 2 ]
  [ "$(statuses)" = "started prepared activating activated verify-skipped committed done" ]
}

# ── T-0010 Gate B: VERIFY gate, commit order, --skip-verify (T3) ────────────

# A run that keeps the VERIFY gate and the CHECKS, with a graphical session.
# The tools the CHECKS call are stubbed so the real machine is never queried.
run_verified() {
  printf '#!/usr/bin/env bash\nif [[ -n "${STUB_FAILED_UNITS:-}" ]]; then echo "$STUB_FAILED_UNITS loaded failed failed x"; fi\nexit 0\n' > "$STUBS/systemctl"
  printf '#!/usr/bin/env bash\necho "Claude 30d left · Codex signed in"\n' > "$STUBS/ai-auth-status"
  chmod +x "$STUBS/systemctl" "$STUBS/ai-auth-status"
  run env PATH="$STUBS:$PATH" DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 XDG_SESSION_TYPE=wayland \
    bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup "$@"
}

@test "S24: a verification failure keeps the lock uncommitted and offers both ways out" {
  export FAIL_BRAVE=1
  run_verified
  [ "$status" -eq 1 ]
  [ "$(commits)" -eq 1 ]
  grep -q '"rev":"new"' "$FAKE/nix/flake.lock"
  [ "$(statuses | awk '{print $NF}')" = "failed:verify" ]
  [[ "$output" == *"sys-update rollback"* ]]
  [[ "$output" == *'commit --only -m "chore(nix): update flake inputs" -- nix/flake.lock'* ]]
}

@test "S24: a verified update records verified and commits afterwards" {
  run_verified
  [ "$status" -eq 0 ]
  [ "$(statuses)" = "started prepared activating activated verified committed done" ]
  [ "$(meta_value runtime_verified)" = 1 ]
  [ "$(commits)" -eq 2 ]
  [[ "$(git -C "$FAKE" log -1 --format=%B)" != *"Not runtime-verified"* ]]
}

@test "S25a: a default-browser mapping that did not apply fails and names mimeapps.list" {
  export STUB_MIME=firefox.desktop
  run_verified
  [ "$status" -eq 1 ]
  [[ "$output" == *"firefox.desktop"* ]]
  [[ "$output" == *"mimeapps.list"* ]]
  [ "$(commits)" -eq 1 ]
}

@test "S25b: an empty xdg-mime answer is advisory, not a failure" {
  export STUB_MIME_EMPTY=1
  run_verified
  [ "$status" -eq 0 ]
  [[ "$output" == *"could not be judged"* ]]
  [ "$(commits)" -eq 2 ]
}

@test "S25c: with no graphical session a wrong mapping is advisory" {
  export STUB_MIME=firefox.desktop
  printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/systemctl"
  printf '#!/usr/bin/env bash\necho ok\n' > "$STUBS/ai-auth-status"
  chmod +x "$STUBS/systemctl" "$STUBS/ai-auth-status"
  run env PATH="$STUBS:$PATH" DISPLAY= WAYLAND_DISPLAY= XDG_SESSION_TYPE=tty \
    bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup
  [ "$status" -eq 0 ]
  [[ "$output" == *"no graphical session"* ]]
  [ "$(commits)" -eq 2 ]
}

@test "S25: a Brave that does not run is a hard failure even without a graphical session" {
  export FAIL_BRAVE=1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/systemctl"
  chmod +x "$STUBS/systemctl"
  run env PATH="$STUBS:$PATH" DISPLAY= WAYLAND_DISPLAY= XDG_SESSION_TYPE=tty \
    bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup
  [ "$status" -eq 1 ]
  [[ "$output" == *"brave --version failed"* ]]
}

@test "S26: --skip-verify records that the update was not runtime-verified" {
  export FAIL_BRAVE=1
  run_update
  [ "$status" -eq 0 ]
  [ "$(meta_value runtime_verified)" = 0 ]
  [ "$(statuses)" = "started prepared activating activated verify-skipped committed done" ]
  [[ "$(git -C "$FAKE" log -1 --format=%B)" == *"Not runtime-verified"* ]]
  [ "$(git -C "$FAKE" log -1 --format=%s)" = "chore(nix): update flake inputs" ]
  [[ "$output" == *"not runtime-verified"* ]]
}

@test "S27: a failing advisory check warns and never blocks the committed update" {
  export STUB_FAILED_UNITS=broken.service
  run_verified
  [ "$status" -eq 0 ]
  [[ "$output" == *"broken.service"* ]]
  [ "$(commits)" -eq 2 ]
  [ "$(statuses)" = "started prepared activating activated verified committed done" ]
}

@test "a lock changed by something else during the run is not committed" {
  export STUB_TOUCH_LOCK=1
  run_update
  [ "$status" -eq 0 ]
  [ "$(commits)" -eq 1 ]
  grep -q '"rev":"foreign"' "$FAKE/nix/flake.lock"
  [[ "$output" == *"changed during the update by something else"* ]]
  [ "$(statuses)" = "started prepared activating activated verify-skipped commit-skipped done" ]
}

# ── T-0010 Gate B: pull, re-exec and adoption (T4) ──────────────────────────

# Give $FAKE a bare upstream with one new commit that changes the updater: the
# new updater announces itself in $STUB_LOG, so a run of it is observable.
fake_upstream_with_new_updater() {
  local branch; branch="$(git -C "$FAKE" branch --show-current)"
  git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
  git -C "$FAKE" remote add origin "$BATS_TEST_TMPDIR/origin.git"
  git -C "$FAKE" push -q origin "$branch"
  git -C "$FAKE" branch -q --set-upstream-to="origin/$branch" "$branch"
  git clone -q "$BATS_TEST_TMPDIR/origin.git" "$BATS_TEST_TMPDIR/other"
  sed -i '0,/^set -uo pipefail$/s//set -uo pipefail\nprintf "updater-version=2 reexec=%s\\n" "${SYS_UPDATE_REEXEC-unset}" >> "$STUB_LOG"/' \
    "$BATS_TEST_TMPDIR/other/ops/update-all.sh"
  git -C "$BATS_TEST_TMPDIR/other" -c user.email=t@t -c user.name=t commit -q -am "newer updater"
  git -C "$BATS_TEST_TMPDIR/other" push -q origin "$branch"
}

@test "S28: a pull that moved HEAD continues in the updated updater" {
  fake_upstream_with_new_updater
  run_update
  [ "$status" -eq 0 ]
  [ "$(grep -c '^updater-version=2' "$STUB_LOG")" -eq 1 ]
  grep -q '^updater-version=2 reexec=1$' "$STUB_LOG"
  # one run: one record, one log, one update
  [ "$(ls "$SYS_UPDATE_STATE_DIR"/runs/*.meta | wc -l)" -eq 1 ]
  [ "$(grep -c '^nix flake update' "$STUB_LOG")" -eq 1 ]
  [ "$(statuses)" = "started prepared activating activated verify-skipped committed done" ]
  [[ "$output" == *"restarting in the updated version"* ]]
}

@test "S28: the re-executed updater appends to the run log of its parent" {
  fake_upstream_with_new_updater
  run_update
  [ "$status" -eq 0 ]
  log="$(ls "$SYS_UPDATE_STATE_DIR"/runs/*.log)"
  [ "$(grep -c 'SYSTEM UPDATE\|== Preflight ==' "$log")" -ge 2 ]
  grep -q '\[✓\] git pull' "$log"
  grep -q '\[✓\] flake.lock: committed' "$log"
}

@test "S29: the re-exec happens before anything is snapshotted or changed" {
  fake_upstream_with_new_updater
  run_update
  [ "$status" -eq 0 ]
  first_marker="$(grep -n '^updater-version=2' "$STUB_LOG" | head -1 | cut -d: -f1)"
  [ -n "$first_marker" ]
  # nothing the update mutates ran before the new updater started
  ! head -n "$first_marker" "$STUB_LOG" | grep -q '^nix flake update\|^nix build\|^chezmoi apply\|^home-manager switch\|^nix-store'
}

@test "S30: the lock is held across the re-exec and free afterwards" {
  fake_upstream_with_new_updater
  cat > "$STUBS/nix" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" == "flake update"* ]]; then
  if flock -n "$SYS_UPDATE_STATE_DIR/lock" true; then echo lock-free > "$BATS_TEST_TMPDIR/relock.out"
  else echo lock-held > "$BATS_TEST_TMPDIR/relock.out"; fi
fi
[[ "$*" == *--print-out-paths* ]] && echo "$STUB_HM_OUT"
exit 0
STUB
  chmod +x "$STUBS/nix"
  run_update
  [ "$status" -eq 0 ]
  grep -q '^updater-version=2 reexec=1$' "$STUB_LOG"
  [ "$(cat "$BATS_TEST_TMPDIR/relock.out")" = lock-held ]
  flock -n "$SYS_UPDATE_STATE_DIR/lock" true
}

@test "S30: a second update started while the re-exec'd one runs is refused" {
  fake_upstream_with_new_updater
  cat > "$STUBS/nix" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" == "flake update"* ]]; then
  bash "$FAKE_REPO/ops/update-all.sh" --apply --yes --no-cleanup --skip-verify > "$BATS_TEST_TMPDIR/second.out" 2>&1
  echo "rc=$?" >> "$BATS_TEST_TMPDIR/second.out"
fi
[[ "$*" == *--print-out-paths* ]] && echo "$STUB_HM_OUT"
exit 0
STUB
  chmod +x "$STUBS/nix"
  export FAKE_REPO="$FAKE"
  run_update
  [ "$status" -eq 0 ]
  grep -q '^updater-version=2 reexec=1$' "$STUB_LOG"
  grep -q '^rc=5$' "$BATS_TEST_TMPDIR/second.out"
}

@test "S30: mkdir-mode lock ownership survives the re-exec" {
  export SYS_UPDATE_FORCE_MKDIR_LOCK=1
  fake_upstream_with_new_updater
  run_update
  [ "$status" -eq 0 ]
  grep -q '^updater-version=2 reexec=1$' "$STUB_LOG"
  [ ! -e "$SYS_UPDATE_STATE_DIR/lock.d" ]
}

@test "S30: the re-exec is a plain restart: no pull happens in the child" {
  fake_upstream_with_new_updater
  run_update
  [ "$status" -eq 0 ]
  grep -q '^updater-version=2 reexec=1$' "$STUB_LOG"
  log="$(ls "$SYS_UPDATE_STATE_DIR"/runs/*.log)"
  [ "$(grep -c '^\$ git .* pull' "$log")" -eq 1 ]
}

@test "report mode never writes to the run record named by a stray re-exec environment" {
  run_update
  [ "$status" -eq 0 ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  before="$(sha256sum "$meta")"
  id="$(sed -n 's/^run_id=//p' "$meta")"
  run env SYS_UPDATE_REEXEC=1 SYS_UPDATE_RUN_ID="$id" PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [ "$status" -eq 0 ]
  [ "$(sha256sum "$meta")" = "$before" ]
}

@test "a re-exec environment without an inherited lock is not adopted" {
  run env SYS_UPDATE_REEXEC=1 SYS_UPDATE_RUN_ID=20260101T000000Z-4242 \
    PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup --skip-verify
  [ "$status" -eq 0 ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  [ "$(sed -n 's/^run_id=//p' "$meta")" != 20260101T000000Z-4242 ]
}

# ── T-0010 Gate B: rollback (T5) ────────────────────────────────────────────

do_rollback_cmd() { run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" rollback --yes; }

# An update that succeeded, so there is a run to roll back; the stub log is
# emptied so the rollback's own calls are all that is left in it.
updated_once() {
  run_update
  [ "$status" -eq 0 ]
  : > "$STUB_LOG"
}

@test "S32: a rollback whose activate leaves the profile elsewhere sets the profile itself" {
  updated_once
  export STUB_ACTIVATE_NO_RELINK=1
  do_rollback_cmd
  [ "$status" -eq 0 ]
  grep -q "^nix-env --profile $HOME/.local/state/nix/profiles/home-manager --set $GEN_DIR\$" "$STUB_LOG"
  [ "$(readlink -f "$HOME/.local/state/nix/profiles/home-manager")" = "$(readlink -f "$GEN_DIR")" ]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
  [ "$(meta_value status)" = rolled-back ]
}

@test "S33: a rollback that cannot move the profile fails and keeps the lock" {
  updated_once
  export STUB_ACTIVATE_NO_RELINK=1
  printf '#!/usr/bin/env bash\nprintf "nix-env %%s\\n" "$*" >> "$STUB_LOG"\nexit 1\n' > "$STUBS/nix-env"
  chmod +x "$STUBS/nix-env"
  do_rollback_cmd
  [ "$status" -eq 1 ]
  [[ "$output" == *"still does not point at the previous generation"* ]]
  grep -q '"rev":"new"' "$FAKE/nix/flake.lock"
  [ "$(meta_value status)" != rolled-back ]
}

@test "S34: rolling back twice is harmless: the second finds the profile on target" {
  updated_once
  do_rollback_cmd
  [ "$status" -eq 0 ]
  : > "$STUB_LOG"
  do_rollback_cmd
  [ "$status" -eq 0 ]
  [[ "$output" == *"already on generation 1"* ]]
  run grep -c '^activate' "$STUB_LOG"
  [ "$output" = 0 ]
}

@test "S35b: a run that stopped while preparing has nothing to roll back" {
  export FAIL_HOST_BUILD=1
  run_update
  [ "$status" -eq 1 ]
  : > "$STUB_LOG"
  do_rollback_cmd
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to roll back"* ]]
  run grep -c '^activate\|^nix-env' "$STUB_LOG"
  [ "$output" = 0 ]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
}

@test "S35b: a run recorded as started restores a clean lock and activates nothing" {
  run_update
  [ "$status" -eq 0 ]
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  sed -i 's/^status=.*/status=started/' "$meta"
  # The update's own lock content is back in the worktree, uncommitted, as it
  # would be after a run that stopped right after writing it.
  git -C "$FAKE" reset -q --hard "$(git -C "$FAKE" rev-list --max-parents=0 HEAD)"
  printf '{"nodes":{"nixpkgs":{"locked":{"rev":"new"}}}}\n' > "$FAKE/nix/flake.lock"
  : > "$STUB_LOG"
  do_rollback_cmd
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to roll back"* ]]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
  run grep -c '^activate' "$STUB_LOG"
  [ "$output" = 0 ]
}

@test "S36: a rollback uses the profile the run recorded, not one found today" {
  updated_once
  export STUB_ACTIVATE_NO_RELINK=1
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/somewhere-else"
  mkdir -p "$XDG_STATE_HOME/nix/profiles"
  do_rollback_cmd
  [ "$status" -eq 0 ]
  grep -q "^nix-env --profile $HOME/.local/state/nix/profiles/home-manager --set" "$STUB_LOG"
}

@test "S37: a rollback is refused while an update holds the lock, and changes nothing" {
  updated_once
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  before="$(sha256sum "$meta" "$FAKE/nix/flake.lock")"
  runs_before="$(ls "$SYS_UPDATE_STATE_DIR/runs")"
  hold_flock
  do_rollback_cmd
  [ "$status" -eq 5 ]
  [[ "$output" == *"another sys-update"* ]]
  no_rm_hint "$output"
  [ "$(sha256sum "$meta" "$FAKE/nix/flake.lock")" = "$before" ]
  [ "$(ls "$SYS_UPDATE_STATE_DIR/runs")" = "$runs_before" ]
  run grep -c '^activate\|^nix-env\|^home-manager' "$STUB_LOG"
  [ "$output" = 0 ]
}

@test "S38: in mkdir mode a refused rollback leaves the foreign lock alone" {
  updated_once
  export SYS_UPDATE_FORCE_MKDIR_LOCK=1
  sleep 60 3>&- & HOLDER=$!
  mkdir -p "$SYS_UPDATE_STATE_DIR/lock.d"
  printf '%s %s\n' "$HOLDER" "20260101T000000Z-$HOLDER" > "$SYS_UPDATE_STATE_DIR/lock.d/owner"
  do_rollback_cmd
  [ "$status" -eq 5 ]
  [ "$(cat "$SYS_UPDATE_STATE_DIR/lock.d/owner")" = "$HOLDER 20260101T000000Z-$HOLDER" ]
  grep -q '"rev":"new"' "$FAKE/nix/flake.lock"
}

@test "S39: two rollbacks cannot run at once" {
  updated_once
  cat > "$GEN_DIR/activate" <<'ACT'
#!/usr/bin/env bash
: > "$BATS_TEST_TMPDIR/in-activate"
for _ in $(seq 200); do [[ -e "$BATS_TEST_TMPDIR/release" ]] && break; sleep 0.05; done
printf 'activate %s\n' "$*" >> "$STUB_LOG"
ln -sfn home-manager-1-link "$HOME/.local/state/nix/profiles/home-manager"
ACT
  chmod +x "$GEN_DIR/activate"
  env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" rollback --yes \
    3>&- > "$BATS_TEST_TMPDIR/first.out" 2>&1 &
  HOLDER=$!
  for _ in $(seq 100); do [[ -e "$BATS_TEST_TMPDIR/in-activate" ]] && break; sleep 0.05; done
  [ -e "$BATS_TEST_TMPDIR/in-activate" ]
  do_rollback_cmd
  [ "$status" -eq 5 ]
  : > "$BATS_TEST_TMPDIR/release"
  wait "$HOLDER"
  HOLDER=""
  grep -q 'rollback.*done' "$BATS_TEST_TMPDIR/first.out"
  flock -n "$SYS_UPDATE_STATE_DIR/lock" true
}

@test "S40: an interrupted rollback frees its lock and rolls nothing further" {
  updated_once
  cat > "$GEN_DIR/activate" <<'ACT'
#!/usr/bin/env bash
if flock -n "$SYS_UPDATE_STATE_DIR/lock" true; then echo free > "$BATS_TEST_TMPDIR/lock-state"
else echo held > "$BATS_TEST_TMPDIR/lock-state"; fi
kill -TERM "$PPID"
sleep 0.3
ACT
  chmod +x "$GEN_DIR/activate"
  do_rollback_cmd
  [ "$status" -eq 143 ]
  [ "$(cat "$BATS_TEST_TMPDIR/lock-state")" = held ]
  flock -n "$SYS_UPDATE_STATE_DIR/lock" true
  grep -q '"rev":"new"' "$FAKE/nix/flake.lock"
}

@test "S40: a failed rollback frees its lock" {
  updated_once
  rm -rf "$GEN_DIR"
  do_rollback_cmd
  [ "$status" -eq 1 ]
  flock -n "$SYS_UPDATE_STATE_DIR/lock" true
}

@test "a rollback keeps a lock that was edited after the update" {
  updated_once
  printf '{"nodes":{"nixpkgs":{"locked":{"rev":"later-edit"}}}}\n' > "$FAKE/nix/flake.lock"
  do_rollback_cmd
  [ "$status" -eq 0 ]
  grep -q '"rev":"later-edit"' "$FAKE/nix/flake.lock"
  [[ "$output" == *"left in place"* ]]
}

@test "a rollback whose restore commit fails says how to settle the repository" {
  updated_once
  # The rollback commits the restored lock by itself; with that refused, the
  # repository is left differing from HEAD and the output must say what to do.
  mkdir -p "$FAKE/.git/hooks"
  printf '#!/bin/sh\nexit 1\n' > "$FAKE/.git/hooks/pre-commit"
  chmod +x "$FAKE/.git/hooks/pre-commit"
  do_rollback_cmd
  [ "$status" -eq 0 ]
  [[ "$output" == *"checkout HEAD -- nix/flake.lock"* ]]
  [[ "$output" == *"commit --only"* ]]
}

@test "a record without a host is rolled back with a detected host, and fails closed when detection fails" {
  updated_once
  meta="$(cat "$SYS_UPDATE_STATE_DIR/last-run")"
  sed -i '/^host=/d; /^hm_profile=/d' "$meta"
  HOST_PROFILE=bogus do_rollback_cmd
  [ "$status" -eq 4 ]
  do_rollback_cmd
  [ "$status" -eq 0 ]
}

@test "macOS rollback restores the files and says the system switch is manual" {
  export HOST_PROFILE=macos
  cp "$STUBS/home-manager" "$STUBS/darwin-rebuild"
  ln -s "$STUB_HM_OUT" "$BATS_TEST_TMPDIR/current-system"
  export SYS_UPDATE_DARWIN_SYSTEM_LINK="$BATS_TEST_TMPDIR/current-system"
  updated_once
  do_rollback_cmd
  [ "$status" -eq 1 ]
  [[ "$output" == *"not rolled back automatically"* ]]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
}

# ── T-0010 Gate B: GC roots for the rollback target (T6) ────────────────────

# A cleanup stub the updater will run (committed, so the worktree stays clean).
# It records its arguments; STUB_CLEANUP_COLLECTS=1 also deletes the previous
# generation, the way a garbage collection would.
install_cleanup_stub() {
  cat > "$FAKE/ops/cleanup.sh" <<'STUB'
#!/usr/bin/env bash
printf 'cleanup %s\n' "$*" >> "$STUB_LOG"
[[ "${STUB_CLEANUP_COLLECTS:-0}" == 1 ]] && rm -rf "$GEN_DIR_TO_COLLECT"
exit 0
STUB
  chmod +x "$FAKE/ops/cleanup.sh"
  git -C "$FAKE" add ops/cleanup.sh
  git -C "$FAKE" commit -q -m 'cleanup stub'
}

run_with_cleanup() { run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" --apply --yes --skip-verify "$@"; }

@test "S41: the Home Manager generation about to be replaced is pinned by a GC root" {
  run_update
  [ "$status" -eq 0 ]
  id="$(meta_value run_id)"
  root="$SYS_UPDATE_STATE_DIR/gcroots/$id/hm"
  [ "$(meta_value gcroot)" = "$root" ]
  [ -L "$root" ]
  [ "$(readlink -f "$root")" = "$(readlink -f "$GEN_DIR")" ]
  grep -q "^nix-store --realise $GEN_DIR --add-root $root\$" "$STUB_LOG"
  ! grep -q -- '--indirect' "$STUB_LOG"
}

@test "S41b: with no previous generation there is nothing to pin and the run records gcroot=none" {
  rm "$HOME/.local/state/nix/profiles/home-manager"
  run_update
  [ "$status" -eq 0 ]
  [ "$(meta_value gcroot)" = none ]
  run grep -c '^nix-store --realise' "$STUB_LOG"
  [ "$output" = 0 ]
}

@test "S41: on macOS the running darwin system is pinned too" {
  export HOST_PROFILE=macos
  cp "$STUBS/home-manager" "$STUBS/darwin-rebuild"
  ln -s "$STUB_HM_OUT" "$BATS_TEST_TMPDIR/current-system"
  export SYS_UPDATE_DARWIN_SYSTEM_LINK="$BATS_TEST_TMPDIR/current-system"
  run_update
  [ "$status" -eq 0 ]
  id="$(meta_value run_id)"
  [ "$(meta_value darwin_system_before)" = "$(readlink -f "$STUB_HM_OUT")" ]
  [ "$(meta_value darwin_gcroot)" = "$SYS_UPDATE_STATE_DIR/gcroots/$id/darwin" ]
  [ -L "$SYS_UPDATE_STATE_DIR/gcroots/$id/darwin" ]
}

@test "S42: a GC root that cannot be created stops the update before anything changes" {
  export FAIL_GCROOT=1
  run_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot pin"* ]]
  [[ "$output" == *"cannot add root"* ]]
  run grep -c '^nix flake update\|^chezmoi apply\|^home-manager switch' "$STUB_LOG"
  [ "$output" = 0 ]
  [ ! -e "$SYS_UPDATE_STATE_DIR/last-run" ]
}

@test "S43: cleanup is told which Home Manager generation to protect" {
  install_cleanup_stub
  : > "$STUB_LOG"
  run_with_cleanup
  [ "$status" -eq 0 ]
  grep -q '^cleanup --apply --yes --protect-hm-generation 1$' "$STUB_LOG"
}

@test "S43: no protect flag when the generation number is unknown" {
  install_cleanup_stub
  # a profile that is not a numbered generation link has no number to protect
  ln -sfn "$GEN_DIR" "$HOME/.local/state/nix/profiles/home-manager"
  : > "$STUB_LOG"
  run_with_cleanup
  [ "$status" -eq 0 ]
  grep -q '^cleanup --apply --yes$' "$STUB_LOG"
}

@test "S44: a previous generation that cleanup collected is reported as a lost rollback handle" {
  install_cleanup_stub
  export STUB_CLEANUP_COLLECTS=1 GEN_DIR_TO_COLLECT="$GEN_DIR"
  run_with_cleanup
  [ "$status" -eq 0 ]
  [[ "$output" == *"no longer in the store"* ]]
  [ "$(meta_value rollback_handle)" = lost ]
}

@test "S44: an intact previous generation records no lost handle" {
  install_cleanup_stub
  run_with_cleanup
  [ "$status" -eq 0 ]
  [ -z "$(meta_value rollback_handle)" ]
}

@test "S45: GC roots older than KEEP_DAYS are removed, younger ones and the new run's stay" {
  roots="$SYS_UPDATE_STATE_DIR/gcroots"
  mkdir -p "$roots/20250101T000000Z-1" "$roots/20260101T000000Z-2"
  touch -d '30 days ago' "$roots/20250101T000000Z-1"
  touch -d '2 days ago' "$roots/20260101T000000Z-2"
  run_update
  [ "$status" -eq 0 ]
  [ ! -e "$roots/20250101T000000Z-1" ]
  [ -d "$roots/20260101T000000Z-2" ]
  [ -L "$roots/$(meta_value run_id)/hm" ]
}

@test "S45: KEEP_DAYS from the environment sets the GC root lifetime" {
  roots="$SYS_UPDATE_STATE_DIR/gcroots"
  mkdir -p "$roots/20260101T000000Z-2"
  touch -d '3 days ago' "$roots/20260101T000000Z-2"
  KEEP_DAYS=1 run_update
  [ "$status" -eq 0 ]
  [ ! -e "$roots/20260101T000000Z-2" ]
}

# ── T-0011: the progress ticker follows the updater, not its parent ─────────

# Runs the updater on a pseudo-terminal (so the progress ticker is on) inside a
# wrapper that, once the updater is gone, reports whether the ticker it forked
# is still alive and whether the lock is free, without closing the terminal.
# STUB_KILL_MODE (kill9|int|term|none) is what the stubbed `nix flake update`
# does to the updater; it records the updater's children (the ticker) first.
pty_update() {
  local w="$BATS_TEST_TMPDIR/wrapper.sh" pids="$BATS_TEST_TMPDIR/ticker.pids"
  cat > "$STUBS/nix" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" == "flake update"* ]]; then
  pgrep -P "$PPID" | grep -vx "$$" > "$BATS_TEST_TMPDIR/ticker.pids"
  case "${STUB_KILL_MODE:-none}" in
    kill9) kill -9 "$PPID"; sleep 1 ;;
    int)   kill -INT "$PPID" ;;
    term)  kill -TERM "$PPID" ;;
  esac
fi
[[ "$*" == *--print-out-paths* ]] && echo "$STUB_HM_OUT"
exit 0
STUB
  chmod +x "$STUBS/nix"
  {
    # bats -j starts tests with SIGINT ignored, and bash cannot trap a signal
    # ignored at startup: restore the default so the INT mode can be seen.
    printf 'env --default-signal=INT bash %q --apply --yes --no-cleanup --skip-verify\nrc=$?\n' "$FAKE/ops/update-all.sh"
    printf 'for _ in $(seq 40); do\n  alive=0\n  for p in $(cat %q 2>/dev/null); do kill -0 "$p" 2>/dev/null && alive=1; done\n  [ "$alive" = 0 ] && break\n  sleep 0.1\ndone\n' "$pids"
    printf 'if [ "$alive" = 0 ]; then echo TICKER_GONE; else echo TICKER_ALIVE; fi\n'
    printf 'if flock -n %q true; then echo LOCK_FREE; else echo LOCK_HELD; fi\n' "$SYS_UPDATE_STATE_DIR/lock"
    printf 'echo "rc=$rc"\n'
  } > "$w"
  run script -qec "bash $w" /dev/null
}

@test "T-0011: after SIGKILL of the updater the ticker exits and the next run gets the lock" {
  command -v script >/dev/null || skip "script(1) not available"
  export STUB_KILL_MODE=kill9
  pty_update
  [ -s "$BATS_TEST_TMPDIR/ticker.pids" ]
  [[ "$output" == *"TICKER_GONE"* ]]
  [[ "$output" == *"LOCK_FREE"* ]]
  [[ "$output" == *"rc=137"* ]]
  # the next run is not refused
  export STUB_KILL_MODE=none
  run_update
  [ "$status" -eq 0 ]
}

@test "T-0011: a normal exit, SIGINT and SIGTERM leave no ticker behind" {
  command -v script >/dev/null || skip "script(1) not available"
  for mode in none int term; do
    reset_repo
    export STUB_KILL_MODE="$mode"
    pty_update
    [ -s "$BATS_TEST_TMPDIR/ticker.pids" ]
    [[ "$output" == *"TICKER_GONE"* ]]
    [[ "$output" == *"LOCK_FREE"* ]]
    case "$mode" in
      none) [[ "$output" == *"rc=0"* ]] ;;
      int)  [[ "$output" == *"rc=130"* ]] ;;
      term) [[ "$output" == *"rc=143"* ]] ;;
    esac
  done
}
