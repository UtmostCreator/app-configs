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
    # The pre-push hook fails closed without a secret scanner. Tests that are
    # not about the scanner must pass on machines that have none; the scanner
    # tests below drop this variable again.
    export APP_CONFIGS_ALLOW_MISSING_SCANNER=1
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

# --- pre-commit: shared helpers ---------------------------------------------
# The hook resolves its repo from its own location, so copy it into the
# scratch repo. PATH is a stub dir holding only the tools the hook needs.
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

@test "pre-commit runs no secret scanner: it passes without one and never calls gitleaks" {
    precommit_env
    printf '#!/usr/bin/env bash\necho GITLEAKS-RAN\nexit 1\n' >"$STUB/gitleaks"
    chmod +x "$STUB/gitleaks"
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt
    run_precommit
    [ "$status" -eq 0 ]
    [[ "$output" == *"pre-commit passed"* ]]
    [[ "$output" != *"GITLEAKS-RAN"* ]]
    run grep -nE '^[[:space:]]*(gitleaks|trufflehog) ' "$REPO_ROOT/ops/hooks/pre-commit.sh"
    [ "$status" -eq 1 ]
}

# --- pre-push secret-scan gate ----------------------------------------------
# Secrets are scanned when commits are pushed, not at commit time: only the
# pushed commits, within a time budget. PATH is a stub dir, so each test
# decides whether a scanner is "installed".
prepush_env() {
    STUB="$BATS_TEST_TMPDIR/pbin"
    mkdir -p "$STUB"
    local t
    for t in bash env git grep mktemp rm cat dirname timeout tar sleep; do
        ln -sf "$(command -v "$t")" "$STUB/$t"
    done
    ZERO=0000000000000000000000000000000000000000
}

# run_prepush <local_sha> <remote_sha> [VAR=value ...]
run_prepush() {
    local l="$1" r="$2"
    shift 2
    run env -u APP_CONFIGS_ALLOW_MISSING_SCANNER PATH="$STUB" "$@" \
        bash -c "echo 'refs/heads/main $l refs/heads/main $r' | bash '$HOOKS/pre-push.sh'"
}

fake_key() { printf 'AKIA%s' "QZ7XK3M2PL5NW4RT"; } # built at runtime: no detectable key in this file

@test "pre-push fails when no secret scanner is installed" {
    prepush_env
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt && git commit -q -m "chore: a"
    run_prepush "$(git rev-parse HEAD)" "$ZERO"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no secret scanner"* ]]
    [[ "$output" == *"nix/modules/home/dev.nix"* ]]
    [[ "$output" == *"APP_CONFIGS_ALLOW_MISSING_SCANNER=1"* ]]
}

@test "pre-push bypass env lets a scanner-less push through with a loud warning" {
    prepush_env
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt && git commit -q -m "chore: a"
    run_prepush "$(git rev-parse HEAD)" "$ZERO" APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"NOT scanned"* ]]
}

@test "pre-push rejects a pushed commit that holds a fake secret" {
    command -v gitleaks >/dev/null 2>&1 || skip "gitleaks not installed"
    prepush_env
    ln -sf "$(command -v gitleaks)" "$STUB/gitleaks"
    cd "$WORK"
    printf 'aws_access_key_id = %s\n' "$(fake_key)" >creds.txt
    git add creds.txt && git commit -q -m "chore: creds"
    run_prepush "$(git rev-parse HEAD)" "$ZERO"
    [ "$status" -ne 0 ]
    [[ "$output" == *"secret"* ]]
}

@test "pre-push passes clean commits when gitleaks is present" {
    command -v gitleaks >/dev/null 2>&1 || skip "gitleaks not installed"
    prepush_env
    ln -sf "$(command -v gitleaks)" "$STUB/gitleaks"
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt && git commit -q -m "chore: a"
    run_prepush "$(git rev-parse HEAD)" "$ZERO"
    [ "$status" -eq 0 ]
}

@test "pre-push scans history, not just the tip: a secret added then removed in the pushed commits is rejected" {
    command -v gitleaks >/dev/null 2>&1 || skip "gitleaks not installed"
    prepush_env
    ln -sf "$(command -v gitleaks)" "$STUB/gitleaks"
    cd "$WORK"
    base="$(git rev-parse HEAD)"
    printf 'aws_access_key_id = %s\n' "$(fake_key)" >creds.txt
    git add creds.txt && git commit -q -m "chore: creds"
    git rm -q creds.txt && git commit -q -m "chore: remove creds"
    run_prepush "$(git rev-parse HEAD)" "$base"
    [ "$status" -ne 0 ]
}

@test "pre-push scans only the pushed commits: a secret already on the remote side of the range is not rescanned" {
    command -v gitleaks >/dev/null 2>&1 || skip "gitleaks not installed"
    prepush_env
    ln -sf "$(command -v gitleaks)" "$STUB/gitleaks"
    cd "$WORK"
    printf 'aws_access_key_id = %s\n' "$(fake_key)" >creds.txt
    git add creds.txt && git commit -q -m "chore: creds"
    remote="$(git rev-parse HEAD)"
    printf 'hello\n' >a.txt && git add a.txt && git commit -q -m "chore: a"
    run_prepush "$(git rev-parse HEAD)" "$remote"
    [ "$status" -eq 0 ]
}

@test "pre-push ignores uncommitted content: a secret only in the worktree does not block the push" {
    command -v gitleaks >/dev/null 2>&1 || skip "gitleaks not installed"
    prepush_env
    ln -sf "$(command -v gitleaks)" "$STUB/gitleaks"
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt && git commit -q -m "chore: a"
    printf 'aws_access_key_id = %s\n' "$(fake_key)" >uncommitted.txt
    run_prepush "$(git rev-parse HEAD)" "$ZERO"
    [ "$status" -eq 0 ]
}

@test "pre-push blocks, and says so, when the secret scan exceeds its time budget" {
    prepush_env
    printf '#!/usr/bin/env bash\nsleep 5\nexit 0\n' >"$STUB/gitleaks"
    chmod +x "$STUB/gitleaks"
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt && git commit -q -m "chore: a"
    run_prepush "$(git rev-parse HEAD)" "$ZERO" APP_CONFIGS_SECRET_SCAN_TIMEOUT=1
    [ "$status" -ne 0 ]
    [[ "$output" == *"time budget"* ]]
    [[ "$output" == *"APP_CONFIGS_SECRET_SCAN_TIMEOUT"* ]]
}

@test "pre-push uses the supported gitleaks git subcommand, limited to the pushed range" {
    prepush_env
    cat >"$STUB/gitleaks" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$GITLEAKS_ARGS"
exit 0
EOS
    chmod +x "$STUB/gitleaks"
    cd "$WORK"
    base="$(git rev-parse HEAD)"
    printf 'hello\n' >a.txt && git add a.txt && git commit -q -m "chore: a"
    tip="$(git rev-parse HEAD)"
    run_prepush "$tip" "$base" GITLEAKS_ARGS="$BATS_TEST_TMPDIR/gargs"
    [ "$status" -eq 0 ]
    [ "$(sed -n 1p "$BATS_TEST_TMPDIR/gargs")" = git ]
    grep -qx -- "--log-opts=$base..$tip" "$BATS_TEST_TMPDIR/gargs"
    grep -qx -- '--redact' "$BATS_TEST_TMPDIR/gargs"
    run grep -nE '^[[:space:]]*gitleaks protect' "$HOOKS/pre-push.sh"
    [ "$status" -eq 1 ]
}

# --- pre-push workflow lint ---------------------------------------------------
# actionlint and zizmor run in one place only: a push that changes a GitHub
# workflow file. Stubs record their calls; the scanner is bypassed here.
lint_stubs() {
    prepush_env
    export LINT_CALLS="$BATS_TEST_TMPDIR/lint-calls"
    : >"$LINT_CALLS"
    local t
    for t in actionlint zizmor; do
        printf '#!/usr/bin/env bash\necho "%s $*" >>"$LINT_CALLS"\nexit "${%s_RC:-0}"\n' "$t" "${t^^}" >"$STUB/$t"
        chmod +x "$STUB/$t"
    done
}

commit_workflow() {
    mkdir -p .github/workflows
    printf 'name: x\non: push\njobs: {}\n' >.github/workflows/x.yml
    git add .github/workflows/x.yml && git commit -q -m "ci: x"
}

@test "pre-push does not run actionlint or zizmor when no workflow file is pushed" {
    lint_stubs
    cd "$WORK"
    printf 'hello\n' >a.txt && git add a.txt && git commit -q -m "chore: a"
    run_prepush "$(git rev-parse HEAD)" "$ZERO" APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -eq 0 ]
    [ ! -s "$LINT_CALLS" ]
}

@test "pre-push runs actionlint and zizmor when a pushed commit changes a workflow" {
    lint_stubs
    cd "$WORK"
    commit_workflow
    run_prepush "$(git rev-parse HEAD)" "$ZERO" APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -eq 0 ]
    grep -q '^actionlint ' "$LINT_CALLS"
    grep -q '^zizmor .*--offline' "$LINT_CALLS"
}

@test "pre-push blocks when actionlint or zizmor reports a problem in a pushed workflow" {
    lint_stubs
    cd "$WORK"
    commit_workflow
    run_prepush "$(git rev-parse HEAD)" "$ZERO" APP_CONFIGS_ALLOW_MISSING_SCANNER=1 ACTIONLINT_RC=1
    [ "$status" -ne 0 ]
    [[ "$output" == *"actionlint"* ]]
    run_prepush "$(git rev-parse HEAD)" "$ZERO" APP_CONFIGS_ALLOW_MISSING_SCANNER=1 ZIZMOR_RC=14
    [ "$status" -ne 0 ]
    [[ "$output" == *"zizmor"* ]]
}

@test "pre-push only notes a missing workflow linter; it does not block the push" {
    prepush_env
    cd "$WORK"
    commit_workflow
    run_prepush "$(git rev-parse HEAD)" "$ZERO" APP_CONFIGS_ALLOW_MISSING_SCANNER=1
    [ "$status" -eq 0 ]
    [[ "$output" == *"actionlint not installed"* ]]
    [[ "$output" == *"zizmor not installed"* ]]
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

# --- pre-push trufflehog fallback ------------------------------------------------
@test "pre-push trufflehog fallback scans a snapshot of the pushed commit, not the worktree" {
    prepush_env
    cat >"$STUB/trufflehog" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TRUFFLE_ARGS"
# Report a hit only if the scanned directory holds the committed content.
for a in "$@"; do
    if [[ -d "$a" ]] && grep -rq PUSHED_SECRET_MARKER "$a"; then exit 183; fi
done
exit 0
EOS
    chmod +x "$STUB/trufflehog"
    cd "$WORK"
    printf 'PUSHED_SECRET_MARKER\n' >s.txt && git add s.txt && git commit -q -m "chore: s"
    # Worktree differs from the commit: only the pushed snapshot has the marker.
    printf 'clean\n' >s.txt
    run_prepush "$(git rev-parse HEAD)" "$ZERO" TRUFFLE_ARGS="$BATS_TEST_TMPDIR/targs"
    [ "$status" -ne 0 ]
    [ "$(sed -n 1p "$BATS_TEST_TMPDIR/targs")" = filesystem ]
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
