#!/usr/bin/env bats
#
# T-0002: the Syncthing helper is REPORT ONLY for conflict files. It installs
# the .stignore block, lists conflict files with resolve-by-hand guidance, and
# never deletes them (directly or through sys-update).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export NO_COLOR=1
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  SCRIPT="$REPO_ROOT/ops/syncthing-obsidian-stignore.sh"

  FOLDER="$BATS_TEST_TMPDIR/vault"
  OTHER="$BATS_TEST_TMPDIR/other-folder"
  mkdir -p "$FOLDER/.stfolder" "$FOLDER/notes/sub" "$OTHER"
  printf 'mine\n'  > "$FOLDER/note.md"
  printf 'a\n'     > "$FOLDER/note.sync-conflict-20260101-000000-ABCDEFG.md"
  printf 'b\n'     > "$FOLDER/notes/sub/x.sync-conflict-20260102-000000-ABCDEFG.md"
  printf 'c\n'     > "$FOLDER/notes/prefixsync-conflict-thing.md"
  printf 'd\n'     > "$FOLDER/data-sync-conflict.db"
  printf 'e\n'     > "$OTHER/keep.sync-conflict-20260103-000000-ABCDEFG.md"
  CONFLICTS=(
    "$FOLDER/note.sync-conflict-20260101-000000-ABCDEFG.md"
    "$FOLDER/notes/sub/x.sync-conflict-20260102-000000-ABCDEFG.md"
    "$FOLDER/notes/prefixsync-conflict-thing.md"
    "$FOLDER/data-sync-conflict.db"
    "$OTHER/keep.sync-conflict-20260103-000000-ABCDEFG.md"
  )
}

all_survive() {
  local f
  for f in "${CONFLICTS[@]}" "$FOLDER/note.md"; do
    [ -f "$f" ] || { echo "missing: $f"; return 1; }
  done
}

@test "--apply installs .stignore but keeps every conflict file" {
  run bash "$SCRIPT" --apply --folder "$FOLDER"
  [ "$status" -eq 0 ]
  grep -q 'BEGIN app-configs syncthing obsidian ignore' "$FOLDER/.stignore"
  all_survive
}

@test "--apply lists conflict files with resolve-by-hand guidance and no removal claim" {
  run bash "$SCRIPT" --apply --folder "$FOLDER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"note.sync-conflict-20260101-000000-ABCDEFG.md"* ]]
  [[ "$output" == *"data-sync-conflict.db"* ]]
  [[ "$output" == *"resolve by hand"* ]]
  [[ "$output" != *"Removed "* ]]
  [[ "$output" != *"removed "* ]]
}

@test "dry-run keeps conflict files and does not write .stignore" {
  run bash "$SCRIPT" --folder "$FOLDER"
  [ "$status" -eq 0 ]
  [ ! -e "$FOLDER/.stignore" ]
  all_survive
}

@test "there is no delete option" {
  run bash "$SCRIPT" --apply --delete-conflicts --folder "$FOLDER"
  [ "$status" -ne 0 ]
  all_survive
}

@test "a folder that is not targeted is untouched" {
  run bash "$SCRIPT" --apply --folder "$FOLDER"
  [ "$status" -eq 0 ]
  [ -f "$OTHER/keep.sync-conflict-20260103-000000-ABCDEFG.md" ]
  [ ! -e "$OTHER/.stignore" ]
}

# Run the real sys-update apply path with Syncthing folders given as arguments.
run_sys_update() {
  export SYS_UPDATE_STATE_DIR="$HOME/.local/state/sys-update"
  export HOST_PROFILE=linux-desktop
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  mkdir -p "$HOME/.config/syncthing"
  {
    printf '<configuration>'
    local d
    for d in "$@"; do printf '<folder id="%s" path="%s"/>' "$(basename "$d")" "$d"; done
    printf '</configuration>\n'
  } > "$HOME/.config/syncthing/config.xml"

  FAKE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FAKE/nix" "$FAKE/reference"
  cp -a "$REPO_ROOT/ops" "$FAKE/ops"
  cp -a "$REPO_ROOT/reference/syncthing" "$FAKE/reference/syncthing"
  printf '{"nodes":{}}\n' > "$FAKE/nix/flake.lock"
  printf '{ outputs = _: { }; }\n' > "$FAKE/nix/flake.nix"
  git -C "$FAKE" init -q
  git -C "$FAKE" add -A
  git -C "$FAKE" -c user.email=t@t -c user.name=t commit -q -m init

  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  for tool in nix chezmoi home-manager mise lefthook; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/$tool"
    chmod +x "$STUBS/$tool"
  done

  run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-all.sh" --apply --yes --no-cleanup --skip-verify
}

@test "sys-update apply path keeps conflict files" {
  run_sys_update "$FOLDER"
  # The syncthing step must have actually run, or this proves nothing.
  [ -f "$FOLDER/.stignore" ]
  all_survive
  [[ "$output" == *"conflict file(s) kept"* ]]
}

@test "sys-update reports the total across folders, not the first folder" {
  mkdir -p "$OTHER/.stfolder"
  printf 'x\n' > "$OTHER/two.sync-conflict-20260104-000000-ABCDEFG.md"
  # FOLDER holds 4 conflict files, OTHER holds 2: total 6, first folder 4.
  run_sys_update "$FOLDER" "$OTHER"
  [[ "$output" == *"6 conflict file(s) kept"* ]]
  [[ "$output" != *"4 conflict file(s) kept"* ]]
  all_survive
}

@test "managed template never marks conflict patterns deletable" {
  run grep -E '^\(\?d\).*sync-conflict' "$REPO_ROOT/reference/syncthing/obsidian.stignore"
  [ "$status" -ne 0 ]
  grep -qxF '**.sync-conflict-*' "$REPO_ROOT/reference/syncthing/obsidian.stignore"
}

@test "an old installed block with (?d) conflict rules is replaced, user rules kept" {
  cat > "$FOLDER/.stignore" <<'OLD'
# BEGIN app-configs syncthing obsidian ignore
(?d).obsidian
(?d)**.sync-conflict-*
(?d)**sync-conflict-*
(?d)**data-sync-conflict.*
# END app-configs syncthing obsidian ignore

my-own-rule
OLD
  run bash "$SCRIPT" --apply --folder "$FOLDER"
  [ "$status" -eq 0 ]
  run grep -E '^\(\?d\).*sync-conflict' "$FOLDER/.stignore"
  [ "$status" -ne 0 ]
  grep -qxF 'my-own-rule' "$FOLDER/.stignore"
  all_survive
}

@test "every conflict rule precedes every (?d) rule in the template (first match wins)" {
  local t="$REPO_ROOT/reference/syncthing/obsidian.stignore"
  local last_conflict first_d
  last_conflict="$(grep -nE '^[^#]*sync-conflict' "$t" | tail -1 | cut -d: -f1)"
  first_d="$(grep -nE '^\(\?d\)' "$t" | head -1 | cut -d: -f1)"
  [ -n "$last_conflict" ] && [ -n "$first_d" ]
  [ "$last_conflict" -lt "$first_d" ]
}

@test "an installed block with the old rule order is replaced by the new order" {
  cat > "$FOLDER/.stignore" <<'OLD'
# BEGIN app-configs syncthing obsidian ignore
(?d).obsidian
(?d).obsidian/**
**.sync-conflict-*
# END app-configs syncthing obsidian ignore
OLD
  run bash "$SCRIPT" --apply --folder "$FOLDER"
  [ "$status" -eq 0 ]
  local c d
  c="$(grep -nE '^[^#]*sync-conflict' "$FOLDER/.stignore" | tail -1 | cut -d: -f1)"
  d="$(grep -nE '^\(\?d\)' "$FOLDER/.stignore" | head -1 | cut -d: -f1)"
  [ "$c" -lt "$d" ]
}
