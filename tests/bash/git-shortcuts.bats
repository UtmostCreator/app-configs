#!/usr/bin/env bats
# Safety and hygiene contract for the git aliases in home/dot_gitconfig.tmpl.

# Render the template once per file; each test gets its own copy.
setup_file() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    : >"$BATS_FILE_TMPDIR/c.toml"
    chezmoi execute-template --config "$BATS_FILE_TMPDIR/c.toml" --source "$REPO_ROOT/home" \
        --override-data '{"name":"T","email":"t@example.test","signingKey":"","useGitDelta":false}' \
        --file "$REPO_ROOT/home/dot_gitconfig.tmpl" >"$BATS_FILE_TMPDIR/gitconfig"
}

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig" GIT_CONFIG_SYSTEM=/dev/null
    cp "$BATS_FILE_TMPDIR/gitconfig" "$GIT_CONFIG_GLOBAL"
}

value() { git config --global --get "alias.$1"; }

# load_aliases: ALIAS_NAMES / ALIAS_VALUES from one git call rather than one
# `git config` (plus greps) per alias.
load_aliases() {
    local record key
    ALIAS_NAMES=() ALIAS_VALUES=()
    while IFS= read -r -d '' record; do
        key="${record%%$'\n'*}"
        ALIAS_NAMES+=("${key#alias.}")
        ALIAS_VALUES+=("${record#*$'\n'}")
    done < <(git config --global -z --get-regexp '^alias\.')
    [ "${#ALIAS_NAMES[@]}" -gt 0 ]
}

@test "no alias shadows a git command (git would silently ignore it)" {
    load_aliases
    collisions="$(git --list-cmds=main,others | grep -xF -f <(printf '%s\n' "${ALIAS_NAMES[@]}") || true)"
    [ -z "$collisions" ] || { echo "collides: $collisions"; return 1; }
}

@test "no two aliases have the same definition" {
    load_aliases
    # one record per alias, whitespace runs folded to one space
    dupes="$(printf '%s\0' "${ALIAS_VALUES[@]}" | tr -s '[:space:]' ' ' | tr '\0' '\n' \
        | sed 's/^ //; s/ $//' | sort | uniq -d)"
    [ -z "$dupes" ] || { echo "duplicates: $dupes"; return 1; }
}

@test "no alias bypasses hooks or force-pushes without a lease" {
    load_aliases
    local force='push[^;|&]*( -f( |$)| --force( |$))' i a v
    for i in "${!ALIAS_NAMES[@]}"; do
        a="${ALIAS_NAMES[$i]}"
        # line by line, as grep matched it
        while IFS= read -r v; do
            if [[ "$v" == *--no-verify* ]]; then echo "bypasses hooks: $a"; return 1; fi
            if [[ "$v" =~ $force ]]; then echo "bare force push: $a"; return 1; fi
        done <<<"${ALIAS_VALUES[$i]}"
    done
}

@test "wt avoids the deprecated whatchanged" {
    [[ "$(value wt)" != *whatchanged* ]]
    git init -q -b main "$BATS_TEST_TMPDIR/r"; cd "$BATS_TEST_TMPDIR/r"
    echo a >f; git add f; git -c commit.gpgsign=false commit -q -m one
    run git wt -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"A"*"f"* ]]
    [[ "$output" != *"removed"* ]]
}

new_repo() {
    REPO="$BATS_TEST_TMPDIR/repo"; git init -q -b main "$REPO"; cd "$REPO"
    echo keep >tracked; git add tracked; git -c commit.gpgsign=false commit -q -m init
}

@test "cleanf shows what it would delete and deletes nothing unless confirmed" {
    new_repo
    echo junk >untracked; echo '.env' >.gitignore; echo secret >.env
    run sh -c 'echo n | git cleanf'
    [ "$status" -ne 0 ]
    [[ "$output" == *"Would remove"*".env"* ]]
    [ -f .env ] && [ -f untracked ]
    run sh -c 'echo y | git cleanf'
    [ "$status" -eq 0 ]
    [ ! -e .env ] && [ ! -e untracked ] && [ -f tracked ]
}

@test "undohard shows the changes it would drop and needs confirmation" {
    new_repo
    echo changed >tracked
    run sh -c 'echo n | git undohard'
    [ "$status" -ne 0 ]
    [[ "$output" == *"tracked"* ]]
    [ "$(cat tracked)" = "changed" ]
    run sh -c 'echo y | git undohard'
    [ "$status" -eq 0 ]
    [ "$(cat tracked)" = "keep" ]
}

@test "ppr pushes with hooks enabled" {
    [[ "$(value ppr)" != *--no-verify* ]]
    [[ "$(value ppr)" == *'git push'* ]]
}

@test "wtn creates a sibling worktree on a new branch from fresh origin/main" {
    ORIGIN="$BATS_TEST_TMPDIR/origin.git"; git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$BATS_TEST_TMPDIR/seed" 2>/dev/null
    git -C "$BATS_TEST_TMPDIR/seed" -c commit.gpgsign=false commit -q --allow-empty -m one
    git -C "$BATS_TEST_TMPDIR/seed" push -q origin main
    git clone -q "$ORIGIN" "$BATS_TEST_TMPDIR/app"; cd "$BATS_TEST_TMPDIR/app"
    git switch -q -c current; echo wip >wip.txt
    git -C "$BATS_TEST_TMPDIR/seed" -c commit.gpgsign=false commit -q --allow-empty -m two
    git -C "$BATS_TEST_TMPDIR/seed" push -q origin main
    run git wtn feat/login
    [ "$status" -eq 0 ]
    wt="$BATS_TEST_TMPDIR/app-feat-login"
    [ -d "$wt" ]
    [[ "$output" == *"$wt"* ]]
    [ "$(git -C "$wt" branch --show-current)" = "feat/login" ]
    [ "$(git -C "$wt" log -1 --format=%s)" = "two" ]
    [ -z "$(git -C "$wt" config --get branch.feat/login.merge)" ]   # --no-track
    # the current checkout is untouched
    [ "$(git branch --show-current)" = "current" ] && [ -f wip.txt ]
    run git wtn
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: git wtn"* ]]
}

@test "commit template is configured and contains only comments" {
    t="$(git config --global --get commit.template)"
    [ "$t" = "~/.config/git/commit-template.txt" ]
    f="$REPO_ROOT/home/dot_config/git/commit-template.txt"
    [ -f "$f" ]
    [ -z "$(grep -vE '^(#.*)?$' "$f")" ]
}

@test "acp stages tracked changes, commits with hooks, and pushes" {
    ORIGIN="$BATS_TEST_TMPDIR/o.git"; git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$BATS_TEST_TMPDIR/w" 2>/dev/null; cd "$BATS_TEST_TMPDIR/w"
    echo a >tracked; git add tracked; git -c commit.gpgsign=false commit -q -m init; git push -q origin main
    echo b >tracked; echo new >untracked
    run git -c commit.gpgsign=false acp "fix: change tracked"
    [ "$status" -eq 0 ]
    [ "$(git log -1 --format=%s origin/main)" = "fix: change tracked" ]
    [ "$(git show --name-only --format= HEAD)" = "tracked" ]      # untracked not swept in
    [[ "$(value acp)" != *--no-verify* ]]
    run git acp
    [ "$status" -ne 0 ]
    [[ "$output" == *'usage: git acp'* ]]
}
