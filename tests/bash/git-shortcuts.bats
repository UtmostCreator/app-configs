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
    [[ "$output" == *"Would remove"*"untracked"* ]]
    [[ "$output" != *".env"* ]]
    [ -f .env ]
    [ -f untracked ]
    run sh -c 'echo y | git cleanf'
    [ "$status" -eq 0 ]
    # ignored files (.env) are never deleted
    [ ! -e untracked ] && [ -f .env ] && [ -f tracked ]
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
    [ "$(git branch --show-current)" = "current" ]
    [ -f wip.txt ]
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

@test "linelog is git log -L: history of a line range, as git linelog START,END:path (no second alias for it)" {
    [ "$(value linelog)" = "log -L" ]
    new_repo
    printf 'one\ntwo\n' >f.txt
    git add f.txt && git commit -qm "add f"
    printf 'one\nTWO\n' >f.txt
    git commit -qam "change line 2"
    run git linelog 2,2:f.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"change line 2"* ]]
    [[ "$output" == *"add f"* ]]
}

@test "push.followTags is documented but not enabled (commented out)" {
    run git config --global --get push.followTags
    [ "$status" -eq 1 ]
    grep -Eq '^[[:space:]]*#[[:space:]]*followTags[[:space:]]*=[[:space:]]*true' "$BATS_FILE_TMPDIR/gitconfig"
}

# --- git up: no autostash, refuses a dirty tree (stash is shared by every worktree)

# up_fixture: bare remote, a work clone (cwd) and a second clone that can push.
up_fixture() {
    git init -q --bare -b main "$BATS_TEST_TMPDIR/remote.git"
    git clone -q "$BATS_TEST_TMPDIR/remote.git" "$BATS_TEST_TMPDIR/work" 2>/dev/null
    git clone -q "$BATS_TEST_TMPDIR/remote.git" "$BATS_TEST_TMPDIR/other" 2>/dev/null
    cd "$BATS_TEST_TMPDIR/work"
    git checkout -q -b main 2>/dev/null || true
    printf 'base\n' >f.txt; git add f.txt; git commit -qm base
    git push -q -u origin main 2>/dev/null
    git -C "$BATS_TEST_TMPDIR/other" pull -q origin main 2>/dev/null
}

# remote_commit FILE CONTENT MSG: commit and push from the second clone.
remote_commit() {
    printf '%s\n' "$2" >"$BATS_TEST_TMPDIR/other/$1"
    git -C "$BATS_TEST_TMPDIR/other" add "$1"
    git -C "$BATS_TEST_TMPDIR/other" commit -qm "$3"
    git -C "$BATS_TEST_TMPDIR/other" push -q origin HEAD:main 2>/dev/null
}

no_stash() {
    [ -z "$(git stash list)" ]
    ! git rev-parse --verify -q refs/stash >/dev/null
}

@test "up on a clean tree pulls and rebases" {
    up_fixture
    printf 'mine\n' >mine.txt; git add mine.txt; git commit -qm mine
    remote_commit theirs.txt theirs "their change"
    run git up
    [ "$status" -eq 0 ]
    [ -f theirs.txt ]
    [ "$(git log -1 --format=%s)" = "mine" ]
    no_stash
}

@test "up refuses a dirty tree (modified, staged or untracked), changing nothing" {
    up_fixture
    remote_commit theirs.txt theirs "their change"
    local kind
    for kind in modified staged untracked; do
        git reset -q --hard; git clean -fdq
        case "$kind" in
            modified)  echo more >>f.txt ;;
            staged)    echo more >>f.txt; git add f.txt ;;
            untracked) echo new >new.txt ;;
        esac
        before="$(git status --porcelain)"; head_before="$(git rev-parse HEAD)"
        run git up
        [ "$status" -ne 0 ]
        [[ "$output" == *"working tree not clean"* ]]
        [ "$(git status --porcelain)" = "$before" ]
        [ "$(git rev-parse HEAD)" = "$head_before" ]
        [ ! -f theirs.txt ]
        no_stash
    done
}

@test "a conflicting up stops in the rebase and leaves the stash list empty" {
    up_fixture
    printf 'mine\n' >f.txt; git commit -qam "mine edits f"
    remote_commit f.txt theirs "their edit of f"
    run git up
    [ "$status" -ne 0 ]
    [ -d "$(git rev-parse --git-path rebase-merge)" ] || [ -d "$(git rev-parse --git-path rebase-apply)" ]
    no_stash
}

@test "aborting an interrupted up rebase restores the tree and keeps the stash list unchanged" {
    up_fixture
    printf 'mine\n' >f.txt; git commit -qam "mine edits f"
    head_before="$(git rev-parse HEAD)"
    remote_commit f.txt theirs "their edit of f"
    run git up
    [ "$status" -ne 0 ]
    run git rebase --abort
    [ "$status" -eq 0 ]
    [ -z "$(git status --porcelain)" ]
    [ "$(git rev-parse HEAD)" = "$head_before" ]
    no_stash
}

@test "autostash is off: rebase.autoStash=false, merge.autoStash unset, no --autostash in an alias" {
    [ "$(git config --global --get rebase.autoStash)" = "false" ]
    run git config --global --get merge.autoStash
    [ "$status" -eq 1 ]
    run git config --global --get-regexp '^alias\.' 
    [[ "$output" != *"--autostash"* ]]
}

@test "stash aliases stay for humans, with a comment saying agents must not stash" {
    local a
    for a in sl ss sst sp sa stashp stashk stashs stashb fstash; do
        git config --global --get "alias.$a" >/dev/null
    done
    grep -qiE '^[[:space:]]*#.*humans? only.*(agents?|AGENTS\.md)' "$BATS_FILE_TMPDIR/gitconfig"
}

# --- rerere, histogram diffs, worktree remote guessing, autosquash

@test "rerere, histogram diff, worktree.guessRemote and rebase.autoSquash are enabled" {
    [ "$(git config --global --get rerere.enabled)" = "true" ]
    [ "$(git config --global --get diff.algorithm)" = "histogram" ]
    [ "$(git config --global --get worktree.guessRemote)" = "true" ]
    [ "$(git config --global --get rebase.autoSquash)" = "true" ]
    [ "$(git config --global --get rebase.updateRefs)" = "true" ]
}

@test "ri autosquashes a fixup! commit without an editor" {
    new_repo
    echo a >a; git add a; git commit -qm "add a"
    echo b >b; git add b; git commit -qm "add b"
    echo a2 >>a; git commit -qam "fixup! add a"
    GIT_SEQUENCE_EDITOR=true run git ri 3
    [ "$status" -eq 0 ]
    [ "$(git log --format=%s | head -n 2 | tr '\n' ,)" = "add b,add a," ]
    [ "$(git rev-list --count HEAD)" -eq 3 ]
}

# --- safety: fetch, clean, lost commits and new-file preview ----------------

@test "fp keeps local-only tags; fptags is the explicit tag-pruning variant" {
    up_fixture
    git tag local-only
    git fp
    git rev-parse -q --verify refs/tags/local-only >/dev/null
    [ "$(value fp)" = "fetch --prune" ]
    [ "$(value fptags)" = "fetch --prune --prune-tags" ]
    git fptags
    run git rev-parse -q --verify refs/tags/local-only
    [ "$status" -ne 0 ]
}

@test "cleann previews without ignored files and deletes nothing" {
    new_repo
    echo junk >untracked; echo '.env' >.gitignore; echo secret >.env
    run git cleann
    [[ "$output" == *"untracked"* ]]
    [[ "$output" != *".env"* ]]
    [ -f untracked ] && [ -f .env ]
}

@test "lostcommits lists a dropped commit and never writes .git/lost-found" {
    new_repo
    echo x >x; git add x; git commit -qm "dropped work"
    git reset -q --hard HEAD~1
    git reflog expire --expire=now --all
    run git lostcommits
    [ "$status" -eq 0 ]
    [[ "$output" == *"dropped work"* ]]
    [ ! -e .git/lost-found ]
}

@test "lostcommits prints nothing, not HEAD, when nothing is unreachable" {
    new_repo
    run git lostcommits
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e .git/lost-found ]
}

@test "dnew shows tracked stat and untracked files without touching the index" {
    new_repo
    echo more >>tracked; echo new >brandnew
    ls_before="$(git ls-files -s)"; sum_before="$(cksum <.git/index)"
    run git dnew
    [ "$status" -eq 0 ]
    [[ "$output" == *"tracked"* ]]
    [[ "$output" == *"brandnew"* ]]
    [ "$(git ls-files -s)" = "$ls_before" ]
    [ "$(cksum <.git/index)" = "$sum_before" ]
}

@test "acp, ppr and fco carry their guidance comments" {
    grep -qE '^[[:space:]]*#.*human-only convenience; agents never use (these|this)' "$BATS_FILE_TMPDIR/gitconfig"
    grep -qE '^[[:space:]]*#.*gsw.*gswr' "$BATS_FILE_TMPDIR/gitconfig"
}

@test "mainline lists first-parent history; cfgwhere shows where a setting comes from; filelog follows renames" {
    [ "$(value mainline)" = "log --first-parent --oneline --decorate -30" ]
    [ "$(value cfgwhere)" = "config --show-origin --show-scope --get" ]
    [ "$(value filelog)" = "log --follow -p --" ]
    new_repo
    echo a >old.txt; git add old.txt; git commit -qm "add old"
    git mv old.txt new.txt; git commit -qm "rename"
    run git mainline
    [[ "$output" == *"rename"* ]]
    run git cfgwhere user.name
    [ "$status" -eq 0 ]
    [[ "$output" == *"global"* ]]
    run git filelog new.txt
    [[ "$output" == *"add old"* ]]
}
