#!/usr/bin/env bats
# Project scripts must accept linked git worktrees, where `.git` is a file
# (gitdir: ...) rather than a directory.
#
# Run:  bats tests/bash/projects-worktree.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    command -v yq >/dev/null 2>&1 || skip "yq not installed"

    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.test
    export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.test

    ORIGIN="$BATS_TEST_TMPDIR/origin.git"
    MAIN="$BATS_TEST_TMPDIR/main"
    WT="$BATS_TEST_TMPDIR/wt"

    git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$MAIN" 2>/dev/null
    git -C "$MAIN" commit -q --allow-empty -m init
    git -C "$MAIN" push -q origin main
    git -C "$MAIN" worktree add -q -b feature "$WT"
    [ -f "$WT/.git" ]

    export PROJECTS_CONFIG="$BATS_TEST_TMPDIR/config.yaml"
    cat >"$PROJECTS_CONFIG" <<EOF
projects:
  wt: {dir: $WT}
EOF
}

@test "repo-checks.sh inspects a linked worktree" {
    run bash "$REPO_ROOT/ops/projects/repo-checks.sh" wt
    [ "$status" -eq 0 ]
    [[ "$output" != *"not a git repository"* ]]
    [[ "$output" == *"branch: feature"* ]]
}

@test "sync-main.sh does not skip a linked worktree" {
    # The main checkout already holds `main`, so the switch fails — what
    # matters is that the worktree is processed rather than skipped.
    run bash "$REPO_ROOT/ops/projects/github/sync-main.sh" wt
    [[ "$output" != *"skip wt (no .git"* ]]
    [[ "$output" == *"=== wt ==="* ]]
}
