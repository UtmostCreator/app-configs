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

@test "pre-push still rejects a conflict marker on line 1 of a huge diff" {
    # grep -q exits at the first match; under pipefail the SIGPIPE'd `git show`
    # then made the whole pipeline "fail" and the marker was ignored once the
    # diff exceeded the pipe buffer.
    cd "$WORK"
    { printf '<<<<<<< HEAD\n'; seq 1 200000; } >big.txt
    git add big.txt && git commit -q --no-verify -m "chore: big"
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

# --- pre-commit secret-scan gate -------------------------------------------
# The hook resolves its repo from its own location, so copy it into the
# scratch repo. PATH is a stub dir holding only the tools the hook needs, so
# each test decides whether a secret scanner is "installed".
precommit_env() {
    mkdir -p "$WORK/ops/hooks"
    cp "$HOOKS/pre-commit.sh" "$WORK/ops/hooks/pre-commit.sh"
    STUB="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB"
    local t
    for t in bash env git rg grep mktemp rm cat dirname; do
        ln -sf "$(command -v "$t")" "$STUB/$t"
    done
}

run_precommit() { run env PATH="$STUB" "$@" bash "$WORK/ops/hooks/pre-commit.sh"; }

@test "pre-commit fails when no secret scanner is installed" {
    precommit_env
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt
    run_precommit
    [ "$status" -ne 0 ]
    [[ "$output" == *"no secret scanner"* ]]
    [[ "$output" == *"nix/modules/home/dev.nix"* ]]
    [[ "$output" == *"APP_CONFIGS_ALLOW_MISSING_SCANNER=1"* ]]
    [[ "$output" != *"pre-commit passed"* ]]
}

@test "pre-commit bypass env lets a scanner-less commit through with a loud warning" {
    precommit_env
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"NOT scanned"* ]]
}

@test "pre-commit rejects a staged fake secret when gitleaks is present" {
    command -v gitleaks >/dev/null 2>&1 || skip "gitleaks not installed"
    precommit_env
    ln -sf "$(command -v gitleaks)" "$STUB/gitleaks"
    cd "$WORK"
    # Built at runtime so this file never contains a detectable key.
    key="AKIA""QZ7XK3M2PL5NW4RT"
    printf 'aws_access_key_id = %s\n' "$key" >creds.txt && git add creds.txt
    run_precommit
    [ "$status" -ne 0 ]
    [[ "$output" != *"pre-commit passed"* ]]
}

@test "pre-commit passes a clean change when gitleaks is present" {
    command -v gitleaks >/dev/null 2>&1 || skip "gitleaks not installed"
    precommit_env
    ln -sf "$(command -v gitleaks)" "$STUB/gitleaks"
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt
    run_precommit
    [ "$status" -eq 0 ]
    [[ "$output" == *"pre-commit passed"* ]]
}
