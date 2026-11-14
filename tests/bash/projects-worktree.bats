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
    echo base >"$MAIN/file"
    git -C "$MAIN" add file
    git -C "$MAIN" commit -q -m init
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

# Push a new commit to origin/main from a scratch clone; echo its SHA.
advance_origin() {
    local up="$BATS_TEST_TMPDIR/up"
    [ -d "$up" ] || git clone -q "$ORIGIN" "$up" 2>/dev/null
    git -C "$up" pull -q --ff-only origin main
    git -C "$up" commit -q --allow-empty -m "upstream $RANDOM"
    git -C "$up" push -q origin main
    git -C "$up" rev-parse HEAD
}

sha() { git -C "$1" rev-parse "${2:-HEAD}"; }
branch() { git -C "$1" branch --show-current; }

sync_main() {
    run bash "$REPO_ROOT/ops/projects/github/sync-main.sh" "$@"
}

@test "sync-main.sh does not skip a linked worktree" {
    sync_main wt
    [[ "$output" != *"skip wt (no .git"* ]]
    [[ "$output" == *"=== wt ==="* ]]
}

@test "sync-main: feature worktree, main checked out nowhere -> main ref fast-forwarded" {
    git -C "$MAIN" switch -q -c other
    local wt_before new
    wt_before="$(sha "$WT")"
    new="$(advance_origin)"

    sync_main wt
    [ "$status" -eq 0 ]
    [ "$(branch "$WT")" = feature ]
    [ "$(sha "$WT")" = "$wt_before" ]
    [ "$(sha "$MAIN" refs/heads/main)" = "$new" ]
    [ "$(branch "$MAIN")" = other ]
}

@test "sync-main: main checked out in another clean worktree -> updated there" {
    local wt_before new
    wt_before="$(sha "$WT")"
    new="$(advance_origin)"

    sync_main wt
    [ "$status" -eq 0 ]
    [ "$(branch "$WT")" = feature ]
    [ "$(sha "$WT")" = "$wt_before" ]
    [ "$(branch "$MAIN")" = main ]
    [ "$(sha "$MAIN")" = "$new" ]
    [ -z "$(git -C "$MAIN" status --porcelain)" ]
}

@test "sync-main: main checked out elsewhere and dirty -> failure, nothing moved" {
    echo dirty >"$MAIN/file"
    local wt_before main_before
    wt_before="$(sha "$WT")"
    main_before="$(sha "$MAIN")"
    advance_origin >/dev/null

    sync_main wt
    [ "$status" -ne 0 ]
    [[ "$output" == *"main"* && "$output" == *"uncommitted"* ]]
    [ "$(branch "$WT")" = feature ]
    [ "$(sha "$WT")" = "$wt_before" ]
    [ "$(branch "$MAIN")" = main ]
    [ "$(sha "$MAIN")" = "$main_before" ]
    [ "$(cat "$MAIN/file")" = dirty ]
}

@test "sync-main: diverged main (checked out nowhere) -> failure, nothing moved" {
    git -C "$MAIN" commit -q --allow-empty -m local-only
    git -C "$MAIN" switch -q -c other
    local wt_before main_before
    wt_before="$(sha "$WT")"
    main_before="$(sha "$MAIN" refs/heads/main)"
    advance_origin >/dev/null

    sync_main wt
    [ "$status" -ne 0 ]
    [[ "$output" == *"fast-forward"* ]]
    [ "$(branch "$WT")" = feature ]
    [ "$(sha "$WT")" = "$wt_before" ]
    [ "$(sha "$MAIN" refs/heads/main)" = "$main_before" ]
}

@test "sync-main: diverged main checked out in clean worktree -> failure, nothing moved" {
    git -C "$MAIN" commit -q --allow-empty -m local-only
    local wt_before main_before
    wt_before="$(sha "$WT")"
    main_before="$(sha "$MAIN")"
    advance_origin >/dev/null

    sync_main wt
    [ "$status" -ne 0 ]
    [[ "$output" == *"fast-forward"* ]]
    [ "$(sha "$WT")" = "$wt_before" ]
    [ "$(branch "$WT")" = feature ]
    [ "$(sha "$MAIN")" = "$main_before" ]
}

@test "sync-main: failed fetch -> failure, nothing moved" {
    git -C "$WT" remote set-url origin "$BATS_TEST_TMPDIR/missing.git"
    local wt_before main_before
    wt_before="$(sha "$WT")"
    main_before="$(sha "$MAIN")"

    sync_main wt
    [ "$status" -ne 0 ]
    [[ "$output" == *"fetch"* ]]
    [ "$(branch "$WT")" = feature ]
    [ "$(sha "$WT")" = "$wt_before" ]
    [ "$(sha "$MAIN")" = "$main_before" ]
}

@test "sync-main: on main itself -> fast-forward" {
    cat >"$PROJECTS_CONFIG" <<EOF
projects:
  m: {dir: $MAIN}
EOF
    local wt_before new
    wt_before="$(sha "$WT")"
    new="$(advance_origin)"

    sync_main m
    [ "$status" -eq 0 ]
    [ "$(branch "$MAIN")" = main ]
    [ "$(sha "$MAIN")" = "$new" ]
    [ "$(sha "$WT")" = "$wt_before" ]
}

@test "sync-main: one failing project does not stop the others; overall exit non-zero" {
    echo dirty >"$MAIN/file"
    cat >"$PROJECTS_CONFIG" <<EOF
project_order: [wt, m2]
projects:
  wt: {dir: $WT}
  m2: {dir: $BATS_TEST_TMPDIR/m2}
EOF
    git clone -q "$ORIGIN" "$BATS_TEST_TMPDIR/m2" 2>/dev/null
    local new
    new="$(advance_origin)"

    sync_main
    [ "$status" -ne 0 ]
    [[ "$output" == *"=== m2 ==="* ]]
    [ "$(sha "$BATS_TEST_TMPDIR/m2")" = "$new" ]
}
