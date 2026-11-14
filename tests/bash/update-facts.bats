#!/usr/bin/env bats
#
# Pure fact-gathering helpers behind ops/update-all.sh. Everything tested here
# is side-effect free: it must be safe to call before any mutation happens.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=ops/lib/update-facts.sh
  source "$REPO_ROOT/ops/lib/update-facts.sh"
}

# ── store path parsing ──────────────────────────────────────────────────────

@test "parses pname and version out of a store path" {
  run nix_parse_store_name /nix/store/hkclq7d0j10l7gk1v2hpif398dvnq6lz-ripgrep-15.2.0
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'ripgrep\t15.2.0')" ]
}

@test "strips multi-output suffixes so man/bin outputs fold into one package" {
  run nix_parse_store_name /nix/store/bmvqa5ym318mymhxlwwmxq8wxal958p4-gnumake-4.4.1-man
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'gnumake\t4.4.1')" ]
}

@test "keeps a dash-suffixed pname when nothing looks like a version" {
  run nix_parse_store_name /nix/store/088a3qz9z3m0908j79j9bg7pgzqlazkj-vicinae-resize
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'vicinae-resize\t')" ]
}

@test "handles pnames that themselves contain digits" {
  run nix_parse_store_name /nix/store/3nncs81ffv4zqsz4fm7myq9bpgznrk3y-python3.14-lizard-1.24.0
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'python3.14-lizard\t1.24.0')" ]
}

@test "keeps unstable date versions intact" {
  run nix_parse_store_name /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-tlottie-0-unstable-2026-09-11
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'tlottie\t0-unstable-2026-09-11')" ]
}

@test "collapses the outputs of one package into a single entry" {
  run bash -c '
    source "$1/ops/lib/update-facts.sh"
    printf "%s\n" \
      /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-gnupg-2.4.9-man \
      /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-gnupg-2.4.9 \
      /nix/store/cccccccccccccccccccccccccccccccc-jq-1.8.2-bin \
      | nix_packages_from_paths
  ' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 2 ]
  [[ "$output" == *"gnupg	2.4.9"* ]]
  [[ "$output" == *"jq	1.8.2"* ]]
}

@test "ignores closure noise that is not a real package name" {
  run bash -c '
    source "$1/ops/lib/update-facts.sh"
    printf "%s\n" \
      /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-source \
      /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-ripgrep-15.2.0 \
      | nix_packages_from_paths
  ' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'ripgrep\t15.2.0')" ]
}

# ── package delta ───────────────────────────────────────────────────────────

@test "classifies upgrades, additions and removals with a summary line" {
  before="$(printf 'firefox\t155.0.1\nfish\t4.9.2\nclaude-code\t2.1.263')"
  after="$(printf 'firefox\t156.0\nfish\t4.9.2\ntlottie\t0-unstable')"
  run package_delta "$before" "$after"
  [ "$status" -eq 0 ]
  [[ "$output" == *"upgraded	firefox	155.0.1	156.0"* ]]
  [[ "$output" == *"added	tlottie		0-unstable"* ]]
  [[ "$output" == *"removed	claude-code	2.1.263	"* ]]
  [[ "$output" == *"summary	1	1	1	1"* ]]
}

@test "reports a zero delta when both sides match" {
  same="$(printf 'fish\t4.9.2')"
  run package_delta "$same" "$same"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'summary\t0\t0\t0\t1')" ]
}

# ── git worktree state ──────────────────────────────────────────────────────

@test "reports a clean worktree" {
  repo="$BATS_TEST_TMPDIR/clean"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  run git_worktree_state "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'clean\t0\t0')" ]
}

@test "counts modified and untracked files separately" {
  repo="$BATS_TEST_TMPDIR/dirty"
  mkdir -p "$repo"
  git -C "$repo" init -q
  printf 'a\n' > "$repo/tracked"
  git -C "$repo" add tracked
  git -C "$repo" -c user.email=t@t -c user.name=t commit -q -m init
  printf 'b\n' > "$repo/tracked"
  printf 'c\n' > "$repo/untracked-one"
  printf 'd\n' > "$repo/untracked-two"
  run git_worktree_state "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'dirty\t1\t2')" ]
}

@test "reports a non-repository without failing" {
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  run git_worktree_state "$BATS_TEST_TMPDIR/plain"
  [ "$status" -eq 0 ]
  [[ "$output" == no-repo* ]]
}

# ── warning classification ──────────────────────────────────────────────────

@test "downgrades cross-platform flake check noise to information" {
  run classify_warning "warning: The check omitted these incompatible systems: aarch64-darwin"
  [ "$status" -eq 0 ]
  [[ "$output" == info* ]]
  [[ "$output" == *"aarch64-darwin"* ]]
}

@test "summarises Home Manager news as one informational line" {
  run classify_warning "There are 394 unread and relevant news items."
  [ "$status" -eq 0 ]
  [[ "$output" == info* ]]
  [[ "$output" == *"394"* ]]
}

@test "keeps deprecation notices as warnings" {
  run classify_warning "warning: 'install' is a deprecated alias for 'add'"
  [ "$status" -eq 0 ]
  [[ "$output" == warn* ]]
}

@test "explains npm peer dependency conflicts" {
  run classify_warning "npm warn ERESOLVE overriding peer dependency"
  [ "$status" -eq 0 ]
  [[ "$output" == warn* ]]
  [[ "$output" == *"peer dependency"* ]]
}

@test "ignores ordinary output lines" {
  run classify_warning "building /nix/store/xxx.drv"
  [ "$status" -ne 0 ]
}

# ── T-0011 regressions ──────────────────────────────────────────────────────

@test "nix_parse_store_name survives set -e" {
  run bash -c '
    set -e
    source "$1/ops/lib/update-facts.sh"
    nix_parse_store_name /nix/store/hkclq7d0j10l7gk1v2hpif398dvnq6lz-ripgrep-15.2.0
  ' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'ripgrep\t15.2.0')" ]
}

@test "letter-prefixed versions split from the pname" {
  run nix_parse_store_name /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo-v1.2.3
  [ "$output" = "$(printf 'foo\tv1.2.3')" ]
  run nix_parse_store_name /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo-unstable-2026-09-11
  [ "$output" = "$(printf 'foo\tunstable-2026-09-11')" ]
}

@test "package filters look at the basename, not the parsed pname" {
  run bash -c '
    source "$1/ops/lib/update-facts.sh"
    printf "%s\n" \
      /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo-1.0.drv \
      /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-python3-3.12.1-env \
      /nix/store/cccccccccccccccccccccccccccccccc-config-1.json \
      /nix/store/dddddddddddddddddddddddddddddddd-ripgrep-15.2.0 \
      | nix_packages_from_paths
  ' _ "$REPO_ROOT"
  [ "$output" = "$(printf 'ripgrep\t15.2.0')" ]
}

@test "nix_toplevel_packages fails when nix-store fails" {
  mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/prof"
  printf '#!/bin/sh\necho /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-ripgrep-15.2.0\nexit 1\n' \
    > "$BATS_TEST_TMPDIR/bin/nix-store"
  chmod +x "$BATS_TEST_TMPDIR/bin/nix-store"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run nix_toplevel_packages "$BATS_TEST_TMPDIR/prof"
  [ "$status" -ne 0 ]
}

@test "package_delta counts duplicate rows once" {
  same="$(printf 'fish\t4.9.2\nfish\t4.9.2\npy\t1\npy\t2')"
  run package_delta "$same" "$same"
  [ "$output" = "$(printf 'summary\t0\t0\t0\t2')" ]
}

@test "package_delta puts the summary last even after sorting" {
  run package_delta "$(printf 'zlib\t1')" "$(printf 'zlib\t2')"
  [ "${lines[-1]}" = "$(printf 'summary\t1\t0\t0\t0')" ]
}

@test "package_delta compares several versions of one pname regardless of row order" {
  run package_delta "$(printf 'py\t2\npy\t1')" "$(printf 'py\t1\npy\t2')"
  [ "$output" = "$(printf 'summary\t0\t0\t0\t1')" ]
}

@test "a failing git status is an error state, not clean" {
  repo="$BATS_TEST_TMPDIR/broken"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  printf 'garbage' > "$repo/.git/index"
  run git_worktree_state "$repo"
  [ "$status" -ne 0 ]
  [[ "$output" == error* ]]
}

@test "untracked files inside a new directory are counted individually" {
  repo="$BATS_TEST_TMPDIR/deep"
  mkdir -p "$repo/d"
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  touch "$repo/d/a" "$repo/d/b"
  run git_worktree_state "$repo"
  [ "$output" = "$(printf 'dirty\t0\t2')" ]
}

@test "git_upstream: no upstream is empty success, failure is an error" {
  repo="$BATS_TEST_TMPDIR/up"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  run git_upstream "$repo"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # Configured but unresolvable upstream is a failure, not "none".
  br="$(git -C "$repo" symbolic-ref --short HEAD)"
  git -C "$repo" config "branch.$br.remote" origin
  git -C "$repo" config "branch.$br.merge" refs/heads/gone
  run git_upstream "$repo"
  [ "$status" -eq 1 ]
  run git_upstream "$BATS_TEST_TMPDIR/not-a-repo"
  [ "$status" -eq 2 ]
}

@test "error lines are classified as errors" {
  run classify_warning "error: builder for foo failed"
  [ "$status" -eq 0 ]
  [[ "$output" == error* ]]
  [[ "$output" == *"builder for foo failed"* ]]
}

@test "a single news item uses singular wording" {
  run classify_warning "There is 1 unread and relevant news item."
  [[ "$output" == *"1 unread news entry"* ]]
}

@test "news count is taken from the sentence, not a leading timestamp" {
  run classify_warning "[2026-11-14 10:00:01] There are 394 unread and relevant news items."
  [[ "$output" == *"394 unread"* ]]
}
