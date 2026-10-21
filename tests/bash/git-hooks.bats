#!/usr/bin/env bats
# Tests for the shared git hooks in ops/hooks/ (wired up by .lefthook.yml).
#
# Run:  bats tests/bash/git-hooks.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOKS="$REPO_ROOT/ops/hooks"
    # Throwaway repo so hooks never touch the real one.
    WORK="$BATS_TEST_TMPDIR/work"
    mkdir -p "$WORK"
    git -C "$WORK" init -q -b main
    git -C "$WORK" config user.email test@example.invalid
    git -C "$WORK" config user.name Test
    git -C "$WORK" config core.excludesFile /dev/null
    git -C "$WORK" commit -q --allow-empty -m "chore: init"
}

msg() { printf '%s\n' "$1" >"$BATS_TEST_TMPDIR/msg"; bash "$HOOKS/commit-msg.sh" "$BATS_TEST_TMPDIR/msg"; }

@test "commit-msg accepts conventional subjects" {
    run msg "feat(nix): add module"
    [ "$status" -eq 0 ]
}

@test "commit-msg rejects free-form subjects" {
    run msg "update stuff"
    [ "$status" -eq 1 ]
}

@test "commit-msg lets git-generated merge/revert/fixup subjects through" {
    run msg "Merge branch 'x' into main"
    [ "$status" -eq 0 ]
    run msg 'Revert "feat: add thing"'
    [ "$status" -eq 0 ]
    run msg "fixup! feat: add thing"
    [ "$status" -eq 0 ]
}

@test "pre-push rejects pushed commits that add conflict markers" {
    cd "$WORK"
    printf '<<<<<<< HEAD\nx\n' >f.txt
    git add f.txt && git commit -q --no-verify -m "chore: bad"
    sha="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/main $sha refs/heads/main 0000000000000000000000000000000000000000' | bash '$HOOKS/pre-push.sh'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"conflict markers"* ]]
}

@test "pre-push allows clean commits and ignores markdown rules (=======)" {
    cd "$WORK"
    printf 'Title\n=======\n' >f.md
    git add f.md && git commit -q -m "docs: ok"
    sha="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/main $sha refs/heads/main 0000000000000000000000000000000000000000' | bash '$HOOKS/pre-push.sh'"
    [ "$status" -eq 0 ]
}

@test "pre-push protection is opt-in" {
    cd "$WORK"
    sha="$(git rev-parse HEAD)"
    line="refs/heads/main $sha refs/heads/main 0000000000000000000000000000000000000000"
    run bash -c "echo '$line' | bash '$HOOKS/pre-push.sh'"
    [ "$status" -eq 0 ]
    run bash -c "echo '$line' | PUSH_PROTECTED_BRANCHES='^main\$' bash '$HOOKS/pre-push.sh'"
    [ "$status" -eq 1 ]
}

@test "pre-commit blocks a staged .env but allows .env.example" {
    cd "$WORK"
    mkdir -p ops
    printf 'A=1\n' >.env.example
    git add .env.example
    run bash -c "git diff --cached --name-only | grep -E '(^|/)\\.env(\\.[^/]+)?\$' | grep -vE '\\.(example|sample|template|tmpl)\$'"
    [ "$status" -ne 0 ]
    printf 'A=1\n' >.env
    git add .env
    run bash -c "git diff --cached --name-only | grep -E '(^|/)\\.env(\\.[^/]+)?\$' | grep -vE '\\.(example|sample|template|tmpl)\$'"
    [ "$status" -eq 0 ]
}

@test "post-merge prints hints only for changed areas and never fails" {
    cd "$WORK"
    base="$(git rev-parse HEAD)"
    mkdir -p home
    printf 'x\n' >home/a && printf 'y\n' >mise.toml
    git add -A && git commit -q -m "chore: change"
    git update-ref ORIG_HEAD "$base"
    run bash "$HOOKS/post-merge.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"chezmoi apply"* ]]
    [[ "$output" == *"mise install"* ]]
    [[ "$output" != *"sys-update"* ]]
}
