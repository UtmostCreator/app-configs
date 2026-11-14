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

@test "pre-push rejects conflict markers in a large commit (no SIGPIPE false pass)" {
    cd "$WORK"
    # Marker first, then well over the pipe buffer, so an early-exiting grep -q
    # would SIGPIPE git show and (under pipefail) make the check look clean.
    { printf '<<<<<<< HEAD\n'; seq 1 400000; } >big.txt
    git add big.txt && git commit -q --no-verify -m "chore: big bad"
    sha="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/main $sha refs/heads/main 0000000000000000000000000000000000000000' | bash '$HOOKS/pre-push.sh'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"conflict markers"* ]]
}

@test "pre-push rejects conflict markers that only a merge commit introduces" {
    cd "$WORK"
    base="$(git rev-parse HEAD)"
    git checkout -q -b side
    printf 's\n' >side.txt && git add side.txt && git commit -q -m "chore: side"
    git checkout -q main
    printf 'm\n' >main.txt && git add main.txt && git commit -q -m "chore: main"
    git merge -q --no-ff --no-commit side
    printf '<<<<<<< HEAD\nx\n' >evil.txt && git add evil.txt
    git commit -q --no-verify -m "Merge branch 'side'"
    sha="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/main $sha refs/heads/main $base' | bash '$HOOKS/pre-push.sh'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"conflict markers"* ]]
}

@test "pre-push fails closed when the pushed range cannot be listed" {
    cd "$WORK"
    sha="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/main $sha refs/heads/main 1111111111111111111111111111111111111111' | bash '$HOOKS/pre-push.sh'"
    [ "$status" -ne 0 ]
}

@test "pre-push rejects CRLF conflict markers" {
    cd "$WORK"
    printf '<<<<<<<\r\nx\r\n' >f.txt
    git add f.txt && git commit -q --no-verify -m "chore: crlf"
    sha="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/main $sha refs/heads/main 0000000000000000000000000000000000000000' | bash '$HOOKS/pre-push.sh'"
    [ "$status" -eq 1 ]
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

# --- pre-commit conflict-marker detection ------------------------------------
@test "pre-commit rejects staged conflict markers (<<<<<<< and >>>>>>>)" {
    precommit_env
    cd "$WORK"
    printf 'a\n<<<<<<< HEAD\nx\n' >c.txt && git add c.txt
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict markers"* ]]
    git reset -q
    printf 'a\n>>>>>>> branch\n' >c.txt && git add c.txt
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict markers"* ]]
}

@test "pre-commit rejects conflict markers in a large staged file (no SIGPIPE false pass)" {
    precommit_env
    cd "$WORK"
    { printf '<<<<<<< HEAD\n'; seq 1 400000; } >big.txt && git add big.txt
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict markers"* ]]
}

@test "pre-commit accepts a lone ======= line such as a Markdown heading underline" {
    precommit_env
    cd "$WORK"
    printf 'Title\n=======\n' >h.md && git add h.md
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [[ "$output" != *"conflict markers"* ]]
    [ "$status" -eq 0 ]
}

@test "pre-commit conflict check does not depend on rg being installed" {
    precommit_env
    rm -f "$STUB/rg"
    cd "$WORK"
    printf '<<<<<<< HEAD\n' >c.txt && git add c.txt
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict markers"* ]]
}

# --- pre-commit trufflehog fallback --------------------------------------------
@test "pre-commit trufflehog fallback scans the staged snapshot, not history" {
    precommit_env
    cat >"$STUB/trufflehog" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TRUFFLE_ARGS"
# Report a hit only if the scanned directory holds the staged content.
for a in "$@"; do
    if [[ -d "$a" ]] && grep -rq STAGED_SECRET_MARKER "$a"; then exit 183; fi
done
exit 0
EOS
    chmod +x "$STUB/trufflehog"
    cd "$WORK"
    printf 'STAGED_SECRET_MARKER\n' >s.txt && git add s.txt
    # Working tree differs from the index: only the staged snapshot has the marker.
    printf 'clean\n' >s.txt
    run_precommit TRUFFLE_ARGS="$BATS_TEST_TMPDIR/targs"
    [ "$status" -ne 0 ]
    [[ "$output" != *"pre-commit passed"* ]]
    ! grep -q -- '--since-commit' "$BATS_TEST_TMPDIR/targs"
}

@test "pre-commit rejects CRLF conflict markers" {
    precommit_env
    cd "$WORK"
    printf '<<<<<<<\r\nx\r\n' >c.txt && git add c.txt
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict markers"* ]]
}

@test "pre-commit handles non-ASCII filenames (clean passes, markers fail)" {
    precommit_env
    cd "$WORK"
    printf 'ok\n' >"caf\xc3\xa9.txt" && git add .
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -eq 0 ]
    git reset -q
    printf '<<<<<<< HEAD\n' >"caf\xc3\xa9.txt" && git add .
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict markers"* ]]
}

@test "pre-commit blocks a .env under a non-ASCII directory" {
    precommit_env
    cd "$WORK"
    mkdir "d\xc3\xa9p\xc3\xb4t"
    printf 'A=1\n' >"d\xc3\xa9p\xc3\xb4t/.env" && git add .
    run_precommit APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -ne 0 ]
    [[ "$output" == *"env file staged"* ]]
}
