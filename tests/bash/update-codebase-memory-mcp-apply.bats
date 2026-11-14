#!/usr/bin/env bats
#
# ops/update-codebase-memory-mcp.sh rewrites a tracked file from an unattended
# weekly timer. Like sys-update it must never leave that file modified: the
# dirty-worktree gate would stop the next sys-update on this script's output.
# Everything runs against a scratch repo copy, a scratch HOME and PATH stubs.

# `! cmd` in the middle of a bats test does not fail it (set -e ignores a
# negated command), so assert absence explicitly.
refute_grep() { if grep -q "$@"; then echo "unexpected match: $*" >&2; return 1; fi; }

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export HOST_PROFILE=linux-desktop
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  export CALL_LOG="$BATS_TEST_TMPDIR/calls"; : > "$CALL_LOG"
  export MKTEMP_LOG="$BATS_TEST_TMPDIR/mktemp-calls"; : > "$MKTEMP_LOG"

  LOCK_REL=nix/packages/codebase-memory-mcp/release.json
  FAKE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FAKE/nix/packages/codebase-memory-mcp"
  cp -a "$REPO_ROOT/ops" "$FAKE/ops"
  cp "$REPO_ROOT/$LOCK_REL" "$FAKE/$LOCK_REL"
  export RELEASE_FIXTURE="$BATS_TEST_TMPDIR/release.json"
  jq '{tag_name: ("v" + .version), draft: false, prerelease: false,
       assets: [.archives[] | {name: (.url | split("/") | last),
         browser_download_url: .url, digest: ("sha256:" + .hash)}]}' \
    "$FAKE/$LOCK_REL" > "$RELEASE_FIXTURE"
  # The repo starts with an OLD lock, so the stable release is an update.
  jq '.version = "0.0.1"' "$FAKE/$LOCK_REL" > "$FAKE/$LOCK_REL.tmp" && mv "$FAKE/$LOCK_REL.tmp" "$FAKE/$LOCK_REL"
  git -C "$FAKE" init -q
  git -C "$FAKE" add -A
  git -C "$FAKE" -c user.email=t@t -c user.name=t commit -q -m init

  STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
  printf '#!/usr/bin/env bash\ncat "$RELEASE_FIXTURE"\n' > "$STUBS/curl"
  printf '#!/usr/bin/env bash\necho "codebase-memory-mcp 0.0.1"\n' > "$STUBS/codebase-memory-mcp"
  printf '#!/usr/bin/env bash\nprintf "home-manager %%s\\n" "$*" >> "$CALL_LOG"\nexit "${FAIL_SWITCH:-0}"\n' > "$STUBS/home-manager"
  printf '#!/usr/bin/env bash\nprintf "systemctl %%s\\n" "$*" >> "$CALL_LOG"\n' > "$STUBS/systemctl"
  real_mktemp="$(command -v mktemp)"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$MKTEMP_LOG"\nexec %s "$@"\n' "$real_mktemp" > "$STUBS/mktemp"
  chmod +x "$STUBS"/*
  PATH="$STUBS:$PATH"
}

update() { run env PATH="$STUBS:$PATH" bash "$FAKE/ops/update-codebase-memory-mcp.sh" "$@"; }
commits() { git -C "$FAKE" rev-list --count HEAD; }
lock_version() { jq -r .version "$FAKE/$LOCK_REL"; }

@test "report mode prints the release but leaves the lock alone" {
  update
  [ "$status" -eq 0 ]
  [[ "$output" == *"would change"* ]]
  [ "$(lock_version)" = 0.0.1 ]
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
}

@test "extra arguments are refused" {
  update --apply --anything
  [ "$status" -eq 2 ]
  update --bogus
  [ "$status" -eq 2 ]
  update --apply extra
  [ "$status" -eq 2 ]
  [ ! -s "$CALL_LOG" ]
}

@test "an applied release commits the lock and leaves the worktree clean" {
  update --apply
  [ "$status" -eq 0 ]
  [ "$(lock_version)" = "$(jq -r '.tag_name | ltrimstr("v")' "$RELEASE_FIXTURE")" ]
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
  [ "$(commits)" -eq 2 ]
  [ "$(git -C "$FAKE" diff --name-only HEAD~1 HEAD)" = "$LOCK_REL" ]
  [[ "$(git -C "$FAKE" log -1 --format=%s)" == "chore(nix): update codebase-memory-mcp release to "* ]]
}

@test "the switch is the shared one: -b hm-bak, then the dashboard restart" {
  update --apply
  [ "$status" -eq 0 ]
  grep -qx "home-manager switch -b hm-bak --flake path:$FAKE/nix#linux-desktop" "$CALL_LOG"
  grep -q 'systemctl --user restart codebase-memory-mcp-ui.service' "$CALL_LOG"
}

@test "a failed switch puts the old lock back and commits nothing" {
  export FAIL_SWITCH=1
  update --apply
  [ "$status" -ne 0 ]
  [ "$(lock_version)" = 0.0.1 ]
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
  [ "$(commits)" -eq 1 ]
  refute_grep systemctl "$CALL_LOG"
}

@test "a lock that had local edits before the update is not committed for you" {
  jq '.version = "0.0.2"' "$FAKE/$LOCK_REL" > "$FAKE/$LOCK_REL.tmp" && mv "$FAKE/$LOCK_REL.tmp" "$FAKE/$LOCK_REL"
  update --apply
  [ "$status" -eq 0 ]
  [ "$(commits)" -eq 1 ]
  [[ "$output" == *"not committed"* ]]
}

@test "only the lock is committed, whatever else is staged" {
  printf 'x\n' > "$FAKE/other"
  git -C "$FAKE" add other
  update --apply
  [ "$status" -eq 0 ]
  [ "$(git -C "$FAKE" diff --name-only HEAD~1 HEAD)" = "$LOCK_REL" ]
  [ "$(git -C "$FAKE" status --porcelain)" = "A  other" ]
}

@test "scratch files are created outside the repository" {
  update --apply
  [ "$status" -eq 0 ]
  [ -s "$MKTEMP_LOG" ]
  refute_grep "$FAKE" "$MKTEMP_LOG"
  [ "$(ls "$FAKE/nix/packages/codebase-memory-mcp")" = release.json ]
}

@test "it stops while sys-update (or another run) holds the shared lock" {
  mkdir -p "$XDG_STATE_HOME/sys-update"
  exec 8>"$XDG_STATE_HOME/sys-update/lock"
  flock -n 8
  update --apply
  exec 8>&-
  [ "$status" -ne 0 ]
  [[ "$output" == *"Another"* ]]
  [ "$(lock_version)" = 0.0.1 ]
  [ ! -s "$CALL_LOG" ]
}

@test "an already-current install still commits a changed lock" {
  printf '#!/usr/bin/env bash\njq -r '"'"'"codebase-memory-mcp " + (.tag_name | ltrimstr("v"))'"'"' "$RELEASE_FIXTURE"\n' > "$STUBS/codebase-memory-mcp"
  update --apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"already current"* ]]
  refute_grep '^home-manager' "$CALL_LOG"
  [ -z "$(git -C "$FAKE" status --porcelain)" ]
  [ "$(commits)" -eq 2 ]
}
