#!/usr/bin/env bats
# Tests for ops/hooks/no-personal-yaml.sh (the pre-commit guard in .lefthook.yml).
#
# Run:  bats tests/bash/hook-no-personal-yaml.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # The hook cds to its own repo root, so run a copy inside a throwaway repo.
    WORK="$BATS_TEST_TMPDIR/work"
    mkdir -p "$WORK/ops/hooks"
    cp "$REPO_ROOT/ops/hooks/no-personal-yaml.sh" "$WORK/ops/hooks/"
    git -C "$WORK" init -q -b main
    git -C "$WORK" config user.email test@example.invalid
    git -C "$WORK" config user.name Test
    git -C "$WORK" config core.excludesFile /dev/null
    git -C "$WORK" commit -q --allow-empty -m "chore: init"
    cd "$WORK"
}

stage() {
    mkdir -p "$(dirname "$1")"
    echo x >"$1"
    git add -f "$1"
}

@test "no-personal-yaml passes with nothing staged" {
    run bash ops/hooks/no-personal-yaml.sh
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no-personal-yaml passes for an ordinary staged file" {
    stage docs/readme.md
    run bash ops/hooks/no-personal-yaml.sh
    [ "$status" -eq 0 ]
}

@test "no-personal-yaml refuses each private data file" {
    for f in personal.yaml personal.local.yaml projects.yaml; do
        git reset -q
        stage "home/.chezmoidata/$f"
        run bash ops/hooks/no-personal-yaml.sh
        [ "$status" -eq 1 ]
        [[ "$output" == *"ERROR: private per-host data is staged: home/.chezmoidata/$f"* ]]
        [[ "$output" == *"must never be committed."* ]]
        [[ "$output" == *"Run: git restore --staged home/.chezmoidata/$f"* ]]
    done
}

@test "no-personal-yaml allows similarly named paths" {
    stage home/.chezmoidata/personal.yaml.example
    stage home/personal.yaml.example
    stage home/.chezmoidata/other.yaml
    stage sub/home/.chezmoidata/personal.yaml
    run bash ops/hooks/no-personal-yaml.sh
    [ "$status" -eq 0 ]
}

@test "no-personal-yaml refuses from a subdirectory" {
    stage home/.chezmoidata/personal.yaml
    mkdir -p docs
    cd docs
    run bash ../ops/hooks/no-personal-yaml.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: private per-host data is staged: home/.chezmoidata/personal.yaml"* ]]
}

@test "no-personal-yaml refuses in a linked worktree whose path has a space" {
    git commit -q --allow-empty -m "chore: second"
    wt="$BATS_TEST_TMPDIR/work tree"
    git worktree add -q --detach "$wt"
    mkdir -p "$wt/ops/hooks"
    cp ops/hooks/no-personal-yaml.sh "$wt/ops/hooks/"
    cd "$wt"
    stage home/.chezmoidata/personal.yaml
    run bash ops/hooks/no-personal-yaml.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: private per-host data is staged: home/.chezmoidata/personal.yaml"* ]]
    [[ "$output" == *"must never be committed."* ]]
    [[ "$output" == *"Run: git restore --staged home/.chezmoidata/personal.yaml"* ]]
}

# A missing or failing git must refuse the commit: the guard cannot check
# what it cannot read, so it fails closed.
@test "no-personal-yaml refuses when git is not on PATH" {
    stub="$BATS_TEST_TMPDIR/nogit"
    mkdir -p "$stub"
    for t in bash dirname grep; do ln -s "$(command -v "$t")" "$stub/$t"; done
    PATH="$stub" run bash ops/hooks/no-personal-yaml.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"no-personal-yaml: git not found; refusing the commit"* ]]
}

@test "no-personal-yaml refuses when git itself fails" {
    stub="$BATS_TEST_TMPDIR/badgit"
    mkdir -p "$stub"
    for t in bash dirname grep; do ln -s "$(command -v "$t")" "$stub/$t"; done
    printf '#!/bin/sh\nexit 2\n' >"$stub/git"
    chmod +x "$stub/git"
    PATH="$stub" run bash ops/hooks/no-personal-yaml.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"no-personal-yaml: git failed; refusing the commit"* ]]
}
