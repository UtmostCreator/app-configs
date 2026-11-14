#!/usr/bin/env bats
#
# ops/snapshot-home.sh must fail closed: it is the only way back before an
# apply, so "success with nothing captured" is worse than an error.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  export DOTFILES_SNAPSHOT_ROOT="$BATS_TEST_TMPDIR/snap root"
  mkdir -p "$HOME"
  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  export MANAGED_FILE="$BATS_TEST_TMPDIR/managed.txt"
  : > "$MANAGED_FILE"
  cat > "$STUBS/chezmoi" <<'STUB'
#!/usr/bin/env bash
[[ "${CHEZMOI_FAIL:-0}" == 1 ]] && { echo "chezmoi: boom" >&2; exit 1; }
cat "$MANAGED_FILE"
STUB
  chmod +x "$STUBS/chezmoi"
}

snap() { run env PATH="$STUBS:$PATH" bash "$REPO_ROOT/ops/snapshot-home.sh" "$@"; }

@test "chezmoi managed failure makes the snapshot fail" {
  CHEZMOI_FAIL=1 snap
  [ "$status" -ne 0 ]
  [[ "$output" != *"Snapshot complete"* ]]
}

@test "an empty managed list is a legitimate success" {
  snap --print-dir
  [ "$status" -eq 0 ]
}

@test "dangling symlinks are captured" {
  ln -s /nonexistent/target "$HOME/dangling"
  echo dangling > "$MANAGED_FILE"
  out="$(env PATH="$STUBS:$PATH" bash "$REPO_ROOT/ops/snapshot-home.sh" --print-dir 2>/dev/null)"
  [ -L "$out/dangling" ]
  grep -q -- '^- dangling$' "$out/MANIFEST.txt"
}

@test "a same-second collision never reuses an existing snapshot directory" {
  # Deterministic: pin the clock so every run computes the same stamp.
  cat > "$STUBS/date" <<'STUB'
#!/usr/bin/env bash
echo 20200101T000000Z
STUB
  chmod +x "$STUBS/date"
  echo f > "$HOME/f"
  echo f > "$MANAGED_FILE"
  mkdir -p "$DOTFILES_SNAPSHOT_ROOT/20200101T000000Z"
  echo precious > "$DOTFILES_SNAPSHOT_ROOT/20200101T000000Z/MANIFEST.txt"
  a="$(env PATH="$STUBS:$PATH" bash "$REPO_ROOT/ops/snapshot-home.sh" --print-dir 2>/dev/null)"
  b="$(env PATH="$STUBS:$PATH" bash "$REPO_ROOT/ops/snapshot-home.sh" --print-dir 2>/dev/null)"
  [ "$a" != "$b" ]
  [ "$a" != "$DOTFILES_SNAPSHOT_ROOT/20200101T000000Z" ]
  [ "$(cat "$DOTFILES_SNAPSHOT_ROOT/20200101T000000Z/MANIFEST.txt")" = precious ]
  [ -f "$a/MANIFEST.txt" ]
  [ -f "$b/MANIFEST.txt" ]
}

@test "a relative DOTFILES_SNAPSHOT_ROOT still yields an absolute printed dir" {
  echo f > "$HOME/f"
  echo f > "$MANAGED_FILE"
  cd "$BATS_TEST_TMPDIR"
  out="$(env PATH="$STUBS:$PATH" DOTFILES_SNAPSHOT_ROOT=rel/snaps bash "$REPO_ROOT/ops/snapshot-home.sh" --print-dir 2>/dev/null)"
  [[ "$out" == /* ]]
  [ -f "$out/MANIFEST.txt" ]
}

@test "--print-dir prints only the absolute dir on stdout, even with spaces" {
  echo f > "$HOME/f"
  echo f > "$MANAGED_FILE"
  out="$(env PATH="$STUBS:$PATH" bash "$REPO_ROOT/ops/snapshot-home.sh" --print-dir 2>/dev/null)"
  [[ "$out" == "$DOTFILES_SNAPSHOT_ROOT"/* ]]
  [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ]
  [ -f "$out/f" ]
}

@test "without the flag the human output is unchanged" {
  echo f > "$HOME/f"
  echo f > "$MANAGED_FILE"
  snap
  [ "$status" -eq 0 ]
  [[ "$output" == *"Snapshot complete: 1 copied"* ]]
  [[ "$output" == *"Snapshot dir: "* ]]
}

@test "an unknown argument is rejected with exit 2" {
  snap --bogus
  [ "$status" -eq 2 ]
}

@test "extra arguments are rejected with exit 2" {
  snap --print-dir extra
  [ "$status" -eq 2 ]
}
