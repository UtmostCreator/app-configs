#!/usr/bin/env bats
#
# What ops/update-all.sh owes the NEXT run: after a rollback, a failed step or
# a concurrent run, the repository must not be left dirty (the dirty-worktree
# gate would stop the next sys-update on our own output), runs must not step on
# each other, and a host that cannot be identified must not be guessed.
#
# Same harness as update-all-apply.bats: stub tools, a scratch repo copy, a
# scratch HOME.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export NO_COLOR=1
  export HOME="$BATS_TEST_TMPDIR/home"
  export SYS_UPDATE_STATE_DIR="$HOME/.local/state/sys-update"
  export HOST_PROFILE=linux-desktop
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  export STUB_HM_OUT="$BATS_TEST_TMPDIR/hm-out"
  mkdir -p "$STUB_HM_OUT/home-path/bin" "$HOME/.local/state/nix/profiles" "$HOME/.nix-profile"

  GEN_DIR="$BATS_TEST_TMPDIR/hm-generation-1"
  mkdir -p "$GEN_DIR"
  printf '#!/usr/bin/env bash\nprintf "activate %%s\\n" "$*" >> "$STUB_LOG"\n' > "$GEN_DIR/activate"
  chmod +x "$GEN_DIR/activate"
  ln -s "$GEN_DIR" "$HOME/.local/state/nix/profiles/home-manager-1-link"
  ln -s home-manager-1-link "$HOME/.local/state/nix/profiles/home-manager"
  printf '{"elements":{}}\n' > "$HOME/.nix-profile/manifest.json"

  FAKE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FAKE/nix/packages/brave" "$FAKE/nix/packages/codebase-memory-mcp"
  cp -a "$REPO_ROOT/ops" "$FAKE/ops"
  printf '{"nodes":{"nixpkgs":{"locked":{"rev":"old"}}}}\n' > "$FAKE/nix/flake.lock"
  printf '{ outputs = _: { }; }\n' > "$FAKE/nix/flake.nix"
  printf '{"version":"1.0.0"}\n' > "$FAKE/nix/packages/brave/release.json"
  printf '{"version":"1.0.0"}\n' > "$FAKE/nix/packages/codebase-memory-mcp/release.json"
  cat > "$FAKE/ops/update-brave.sh" <<'STUB'
#!/usr/bin/env bash
root="$(cd "$(dirname "$0")/.." && pwd)"
printf '{"version":"2.0.0"}\n' > "$root/nix/packages/brave/release.json"
STUB
  git -C "$FAKE" init -q
  git -C "$FAKE" add -A
  git -C "$FAKE" -c user.email=t@t -c user.name=t commit -q -m init

  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  for tool in nix chezmoi home-manager mise lefthook; do
    cat > "$STUBS/$tool" <<STUB
#!/usr/bin/env bash
printf '%s %s\n' "$tool" "\$*" >> "\$STUB_LOG"
case "$tool \$*" in
  "nix flake update"*)    printf '{"nodes":{"nixpkgs":{"locked":{"rev":"new"}}}}\n' > "$FAKE/nix/flake.lock"
                          [[ "\${BUMP_CBM:-0}" == 1 ]] && printf '{"version":"9.9.9"}\n' > "$FAKE/nix/packages/codebase-memory-mcp/release.json" ;;
  "nix build"*)          [[ "\${FAIL_HOST_BUILD:-0}" == 1 ]] && exit 1
                          [[ "\$*" == *--print-out-paths* ]] && printf '%s\n' "\$STUB_HM_OUT" ;;
  "chezmoi status"*)      : ;;
  "home-manager switch"*) [[ "\${FAIL_SWITCH:-0}" == 1 ]] && exit 1 ;;
esac
exit 0
STUB
    chmod +x "$STUBS/$tool"
  done
  PATH="$STUBS:$PATH"
}

run_update() { run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup --skip-verify "$@"; }
run_rollback() { run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" rollback --yes; }
commits() { git -C "$FAKE" rev-list --count HEAD; }
clean() { [ -z "$(git -C "$FAKE" status --porcelain)" ]; }

# ── rollback ────────────────────────────────────────────────────────────────

@test "rollback commits the restored files so the next sys-update starts clean" {
  run_update
  [ "$status" -eq 0 ]
  [ "$(commits)" -eq 2 ]
  run_rollback
  [ "$status" -eq 0 ]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
  clean
  [ "$(git -C "$FAKE" log -1 --format=%s)" = "chore(nix): roll back flake inputs" ]
  # the browser lock went back with the flake lock, in the same commit
  git -C "$FAKE" diff --name-only HEAD~1 HEAD | grep -qx 'nix/packages/brave/release.json'
  git -C "$FAKE" diff --name-only HEAD~1 HEAD | grep -qx 'nix/flake.lock'
  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [[ "$output" != *"stopped before"* ]]
}

@test "rollback does not commit a lock that had local edits before it ran" {
  run_update
  printf '{"nodes":{"nixpkgs":{"locked":{"rev":"mine"}}}}\n' > "$FAKE/nix/flake.lock"
  run_rollback
  [ "$status" -eq 0 ]
  [ "$(commits)" -eq 2 ]
  [[ "$output" == *"not committed"* ]]
}

# ── a failed step ───────────────────────────────────────────────────────────

@test "a failed step puts the pre-run lock and browser lock back" {
  export FAIL_SWITCH=1
  run_update
  [ "$status" -ne 0 ]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
  grep -q '"1.0.0"' "$FAKE/nix/packages/brave/release.json"
  clean
  [ "$(commits)" -eq 1 ]
  [[ "$output" == *"restored"* ]]
  # so the next run is not stopped by our own leftovers
  unset FAIL_SWITCH
  run_update
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopped before"* ]]
}

@test "a failed host build restores the lock too" {
  export FAIL_HOST_BUILD=1
  run_update
  [ "$status" -ne 0 ]
  grep -q '"rev":"old"' "$FAKE/nix/flake.lock"
  clean
}

@test "a failed step restores a locally edited lock to the user's version, not HEAD's" {
  printf '{"nodes":{"nixpkgs":{"locked":{"rev":"mine"}}}}\n' > "$FAKE/nix/flake.lock"
  export FAIL_SWITCH=1
  run_update --allow-dirty
  [ "$status" -ne 0 ]
  grep -q '"rev":"mine"' "$FAKE/nix/flake.lock"
  [ "$(commits)" -eq 1 ]
}

# ── release locks ───────────────────────────────────────────────────────────

@test "a second sys-update stops while another run holds the lock" {
  mkdir -p "$SYS_UPDATE_STATE_DIR"
  exec 8>"$SYS_UPDATE_STATE_DIR/lock"
  flock -n 8
  run_update
  exec 8>&-
  [ "$status" -ne 0 ]
  [[ "$output" == *"another"* ]]
  [ ! -s "$STUB_LOG" ]
  [ "$(commits)" -eq 1 ]
}

@test "the lock is released when a run ends" {
  run_update
  [ "$status" -eq 0 ]
  exec 8>"$SYS_UPDATE_STATE_DIR/lock"
  flock -n 8
  exec 8>&-
}

@test "two runs in the same second get different run ids" {
  real_date="$(command -v date)"
  cat > "$STUBS/date" <<STUB
#!/usr/bin/env bash
if [[ "\$*" == "-u +%Y%m%dT%H%M%SZ" ]]; then echo 20260101T000000Z; else exec "$real_date" "\$@"; fi
STUB
  chmod +x "$STUBS/date"
  run_update
  [ "$status" -eq 0 ]
  git -C "$FAKE" reset -q --hard "$(git -C "$FAKE" rev-list --max-parents=0 HEAD)"
  run_update
  [ "$status" -eq 0 ]
  [ "$(ls "$SYS_UPDATE_STATE_DIR"/runs/*.log | wc -l)" -eq 2 ]
  [ "$(ls "$SYS_UPDATE_STATE_DIR"/runs/*.meta | wc -l)" -eq 2 ]
}

# ── bats guard ──────────────────────────────────────────────────────────────

@test "--apply refuses a repo outside the test dir even with a scratch HOME" {
  # The copy lives outside $BATS_TEST_TMPDIR, so a missing guard could only
  # reach the PATH stubs, never a real repository.
  outside="${BATS_RUN_TMPDIR:-/tmp}/outside-update-$$"
  mkdir -p "$outside/nix"
  cp -a "$REPO_ROOT/ops" "$outside/ops"
  run env PATH="$STUBS:$PATH" bash "$outside/ops/update-all.sh" --apply --yes
  rm -rf "$outside"
  [ "$status" -eq 3 ]
  [[ "$output" == *"refusing to apply from a bats test"* ]]
  [ ! -s "$STUB_LOG" ]
}

# ── host identity ───────────────────────────────────────────────────────────

@test "an undetectable host stops the run instead of assuming linux-desktop" {
  printf '#!/usr/bin/env bash\necho "unsupported" >&2\nexit 1\n' > "$FAKE/ops/detect-host.sh"
  run env -u HOST_PROFILE PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"host detection failed"* ]]
  [[ "$output" != *"SYSTEM UPDATE"* ]]
  run env -u HOST_PROFILE PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" --apply --yes
  [ "$status" -ne 0 ]
  [ ! -s "$STUB_LOG" ]
}

@test "WSL1 is refused with the conversion command" {
  printf 'Linux version 4.4.0-19041-Microsoft (Microsoft@Microsoft.com)\n' > "$BATS_TEST_TMPDIR/version"
  run env HOST_PROFILE=wsl DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/version" \
    PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"WSL1"* ]]
  [[ "$output" == *"wsl --set-version"* ]]
  [[ "$output" != *"SYSTEM UPDATE"* ]]
}
