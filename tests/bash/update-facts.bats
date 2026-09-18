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
