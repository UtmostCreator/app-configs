#!/usr/bin/env bats
# Cross-shell CLI helpers in home/dot_local/bin and the git aliases they use.
# Ported from personal runbooks and PR-tooling scripts; must behave the
# same on macOS and Linux/WSL2.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BIN="$REPO_ROOT/home/dot_local/bin"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    TOOLS="$BATS_TEST_TMPDIR/tools"
    mkdir -p "$STUBS" "$TOOLS"
    # Install the helpers the way chezmoi deploys them: deployed name, +x.
    for f in "$BIN"/executable_*; do
        [[ "$f" == *.tmpl ]] && continue
        n="${f##*/executable_}"
        cp "$f" "$TOOLS/$n"
        chmod +x "$TOOLS/$n"
    done
    : >"$BATS_TEST_TMPDIR/c.toml"
    GITCONFIG="$BATS_TEST_TMPDIR/gitconfig"
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/c.toml" --source "$REPO_ROOT/home" \
        --override-data '{"name":"T","email":"t@example.test","signingKey":"","useGitDelta":false}' \
        --file "$REPO_ROOT/home/dot_gitconfig.tmpl" >"$GITCONFIG"
    export GIT_CONFIG_GLOBAL="$GITCONFIG" GIT_CONFIG_SYSTEM=/dev/null
}

stub() { printf '#!/bin/sh\n%s\n' "$2" >"$STUBS/$1"; chmod +x "$STUBS/$1"; }
withpath() { PATH="$STUBS:$TOOLS:$PATH" run "$@"; }

@test "topn counts and ranks lines, default top 20" {
    withpath sh -c 'printf "a\nb\na\nc\na\nb\n" | topn 2'
    [ "$status" -eq 0 ]
    [ "$(echo "${lines[0]}" | awk '{print $1,$2}')" = "3 a" ]
    [ "$(echo "${lines[1]}" | awk '{print $1,$2}')" = "2 b" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "logtop ranks combined-log fields, plain and gzipped" {
    log="$BATS_TEST_TMPDIR/access.log"
    printf '%s\n' \
        '1.1.1.1 - - [10/Oct/2026:13:55:36 +0000] "GET /a HTTP/1.1" 200 1 "-" "UA1"' \
        '2.2.2.2 - - [10/Oct/2026:13:55:36 +0000] "GET /b HTTP/1.1" 404 1 "-" "UA2"' \
        '1.1.1.1 - - [10/Oct/2026:13:55:36 +0000] "GET /a HTTP/1.1" 200 1 "-" "UA1"' >"$log"
    cp "$log" "$log.1"; gzip "$log.1"
    withpath logtop ip 5 "$log" "$log.1.gz"
    [ "$status" -eq 0 ]
    [ "$(echo "${lines[0]}" | awk '{print $1,$2}')" = "4 1.1.1.1" ]
    withpath logtop pathstatus 1 "$log"
    [ "$(echo "${lines[0]}" | awk '{print $1,$2,$3}')" = "2 /a 200" ]
    withpath logtop ua 1 "$log"
    [[ "${lines[0]}" == *"UA1" ]]
    withpath logtop bogus 1 "$log"
    [ "$status" -ne 0 ]
}

@test "ports: with a port asks lsof for it; without uses ss when present" {
    stub lsof 'echo "lsof $*"'
    stub ss 'echo "ss $*"'
    withpath ports 8080
    [ "$output" = "lsof -nP -i :8080" ]
    withpath ports
    [ "$output" = "ss -lntup" ]
}

@test "ports: falls back to lsof listeners without ss (macOS)" {
    stub lsof 'echo "lsof $*"'
    PATH="$STUBS:$TOOLS:/nonexistent" run "$(command -v sh)" "$TOOLS/ports"
    [ "$output" = "lsof -nP -iTCP -sTCP:LISTEN" ]
}

@test "psmem uses ps -m on macOS and --sort=-rss on Linux" {
    stub ps 'echo "ps $*"'
    stub uname 'echo Darwin'
    withpath psmem 5
    [[ "$output" == "ps -axo "*" -m" ]]
    stub uname 'echo Linux'
    withpath psmem 5
    [[ "$output" == "ps -eo "*" --sort=-rss" ]]
}

@test "conns counts established peers by IP (ss)" {
    stub ss 'printf "%s\n" "0 0 10.0.0.1:443 9.9.9.9:5000" "0 0 10.0.0.1:443 9.9.9.9:5001" "0 0 10.0.0.1:22 [2001:db8::1]:6000"'
    withpath conns 5
    [ "$status" -eq 0 ]
    [ "$(echo "${lines[0]}" | awk '{print $1,$2}')" = "2 9.9.9.9" ]
    [ "$(echo "${lines[1]}" | awk '{print $1,$2}')" = "1 2001:db8::1" ]
}

@test "curl-timing passes the URL with timing format and timeouts" {
    stub curl 'printf "%s\n" "$@"'
    withpath curl-timing https://example.test
    [[ "$output" == *"--max-time"* ]]
    [[ "$output" == *"ttfb=%{time_starttransfer}"* ]]
    [ "${lines[-1]}" = "https://example.test" ]
}

make_repo() {
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q -b main "$REPO"
    git -C "$REPO" -c commit.gpgsign=false commit -q --allow-empty -m init
    mkdir -p "$REPO/sub"
    echo 'needle one' >"$REPO/tracked.txt"
    git -C "$REPO" add tracked.txt
    git -C "$REPO" -c commit.gpgsign=false commit -q -m tracked
    echo 'needle two' >>"$REPO/tracked.txt"           # modified
    echo 'needle staged' >"$REPO/sub/staged.txt"
    git -C "$REPO" add sub/staged.txt                  # staged
    echo 'needle new' >"$REPO/sub/new.txt"             # untracked
    echo 'needle old' >"$REPO/untouched.txt"
    git -C "$REPO" add untouched.txt
    git -C "$REPO" -c commit.gpgsign=false commit -q -m untouched -- untouched.txt
}

@test "git changed lists modified, staged and untracked files once" {
    make_repo
    run sh -c "git -C '$REPO' changed | tr '\0' '\n'"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'sub/new.txt\nsub/staged.txt\ntracked.txt')" ]
}

@test "rgc searches only changed files, from any subdirectory" {
    make_repo
    cd "$REPO/sub"
    withpath rgc -l needle
    [ "$status" -eq 0 ]
    [[ "$output" == *"tracked.txt"* && "$output" == *"sub/new.txt"* && "$output" == *"sub/staged.txt"* ]]
    [[ "$output" != *"untouched.txt"* ]]
}

@test "rgc with nothing changed says so" {
    REPO="$BATS_TEST_TMPDIR/clean"; git init -q -b main "$REPO"
    git -C "$REPO" -c commit.gpgsign=false commit -q --allow-empty -m init
    cd "$REPO"
    withpath rgc needle
    [ "$status" -ne 0 ]
    [[ "$output" == *"no changed files"* ]]
}

@test "git merged-prs lists merged PR branches between refs" {
    REPO="$BATS_TEST_TMPDIR/m"; git init -q -b main "$REPO"; cd "$REPO"
    git -c commit.gpgsign=false commit -q --allow-empty -m init; git tag base
    git switch -q -c feat/a; git -c commit.gpgsign=false commit -q --allow-empty -m a; git switch -q main
    git -c commit.gpgsign=false merge -q --no-ff feat/a -m 'Merge pull request #12 from someone/feat/a'
    run git merged-prs base
    [ "$output" = "feat/a" ]
}

@test "git worktree and PR aliases expand as documented" {
    [ "$(git config --get alias.wta)" = "worktree add" ]
    [ "$(git config --get alias.wtl)" = "worktree list" ]
    [ "$(git config --get alias.wtp)" = "worktree prune" ]
    stub gh 'echo "gh $*"'
    REPO="$BATS_TEST_TMPDIR/p"; git init -q "$REPO"; cd "$REPO"
    PATH="$STUBS:$PATH" run git prreview
    [ "$output" = "gh pr list --search is:open review-requested:@me" ]
    PATH="$STUBS:$PATH" run git prfiles 7
    [ "$output" = "gh pr diff --name-only 7" ]
}

with_origin() { # a clone of a bare origin whose default branch is main
    ORIGIN="$BATS_TEST_TMPDIR/origin.git"; SEED="$BATS_TEST_TMPDIR/seed"
    git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$SEED" 2>/dev/null
    git -C "$SEED" -c commit.gpgsign=false commit -q --allow-empty -m one
    git -C "$SEED" push -q origin main
    git clone -q "$ORIGIN" "$BATS_TEST_TMPDIR/work"
    cd "$BATS_TEST_TMPDIR/work"
}
upstream_commit() {
    git -C "$SEED" -c commit.gpgsign=false commit -q --allow-empty -m "$1"
    git -C "$SEED" push -q origin main
}

@test "git sync updates main while staying on a feature branch" {
    with_origin
    git switch -q -c feat
    upstream_commit two
    run git sync
    [ "$status" -eq 0 ]
    [ "$(git branch --show-current)" = "feat" ]
    [ "$(git log -1 --format=%s main)" = "two" ]
}

@test "git sync on main pulls" {
    with_origin
    upstream_commit two
    run git sync
    [ "$status" -eq 0 ]
    [ "$(git log -1 --format=%s)" = "two" ]
}

@test "git nb branches from fresh origin/main; git rbd rebases onto it" {
    with_origin
    upstream_commit two
    run git nb feat
    [ "$status" -eq 0 ]
    [ "$(git branch --show-current)" = "feat" ]
    [ "$(git log -1 --format=%s)" = "two" ]
    git -c commit.gpgsign=false commit -q --allow-empty -m mine
    upstream_commit three
    run git rbd
    [ "$status" -eq 0 ]
    [ "$(git log -2 --format=%s | tr '\n' ' ')" = "mine three " ]
    run git nb
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: git nb"* ]]
}

@test "git git <cmd> runs <cmd>; mistyped commands are offered a fix" {
    REPO="$BATS_TEST_TMPDIR/g"; git init -q -b main "$REPO"; cd "$REPO"
    run git git rev-parse --is-inside-work-tree
    [ "$output" = "true" ]
    [ "$(git config --get help.autocorrect)" = "prompt" ]
    [ "$(git config --get alias.s)" = "status -sb" ]
    [ "$(git config --get alias.pnv)" = "push --no-verify" ]
}

@test "killport signals only listeners on the port, after showing them" {
    stub lsof 'case "$*" in *-t*) echo 4242 ;; *) echo "node 4242 LISTEN" ;; esac'
    stub kill 'echo "kill $*" >>"'"$BATS_TEST_TMPDIR"'/killed"'
    withpath killport 3000
    [ "$status" -eq 0 ]
    [[ "$output" == *"node 4242 LISTEN"* ]]
    [ "$(cat "$BATS_TEST_TMPDIR/killed")" = "kill -s TERM 4242" ]
    stub lsof 'exit 1'
    withpath killport 3000
    [ "$status" -ne 0 ]
    [[ "$output" == *"nothing listens on 3000"* ]]
}
