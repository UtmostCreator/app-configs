#!/usr/bin/env bats
#
# The apply path, driven against stub tools so the real system is never
# touched. What is asserted here is the contract the updater owes the user:
# a snapshot before mutation, a rollback handle afterwards, no raw output on
# a clean run, and no attempt to upgrade packages another manager owns.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export NO_COLOR=1
  export HOME="$BATS_TEST_TMPDIR/home"
  export SYS_UPDATE_STATE_DIR="$HOME/.local/state/sys-update"
  export HOST_PROFILE=linux-desktop
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$HOME/.local/state/nix/profiles" "$HOME/.nix-profile"

  # A previous Home Manager generation, so the rollback handle has something
  # real to point at.
  GEN_DIR="$BATS_TEST_TMPDIR/hm-generation-1"
  mkdir -p "$GEN_DIR"
  cat > "$GEN_DIR/activate" <<'ACT'
#!/usr/bin/env bash
printf 'activate %s
' "$*" >> "$STUB_LOG"
ACT
  chmod +x "$GEN_DIR/activate"
  ln -s "$GEN_DIR" "$HOME/.local/state/nix/profiles/home-manager-1-link"
  ln -s home-manager-1-link "$HOME/.local/state/nix/profiles/home-manager"

  FAKE="$BATS_TEST_TMPDIR/repo"
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
  "nix flake update"*)    printf '{"nodes":{"nixpkgs":{"locked":{"rev":"new"}}}}\n' > "$FAKE/nix/flake.lock" ;;
  "nix flake check"*)     printf 'warning: The check omitted these incompatible systems: aarch64-darwin\n' >&2 ;;
  "chezmoi status"*)      printf ' M dot_thing\n' ;;
  "home-manager switch"*) printf 'There are 394 unread and relevant news items.\n' ;;
esac
exit 0
STUB
    chmod +x "$STUBS/$tool"
  done
  PATH="$STUBS:$PATH"
}

run_update() { run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup --skip-verify "$@"; }

# An update rewrites flake.lock, so a second run in one test would otherwise
# trip the dirty-worktree gate.
reset_repo() { git -C "$FAKE" checkout -- .; : > "$STUB_LOG"; }

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
  ! grep -q 'chezmoi apply --force' "$STUB_LOG"
  reset_repo
  run_update --force
  grep -q 'chezmoi apply --force' "$STUB_LOG"
}

@test "the flake lock is only checked for this host unless --full-check" {
  run_update
  ! grep -q 'all-systems' "$STUB_LOG"
  reset_repo
  run_update --full-check
  grep -q 'flake check --all-systems' "$STUB_LOG"
}

@test "changed flake inputs are counted, not dumped" {
  run_update
  [[ "$output" == *"flake inputs"* ]]
  [[ "$output" == *"1 input(s) updated"* ]]
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
