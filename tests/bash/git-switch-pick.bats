#!/usr/bin/env bats
# home/dot_local/bin/executable_git-switch-pick: the fzf branch pickers behind
# the gsw (local) and gswr (remote) shortcuts. fzf is replaced by a stub that
# records its arguments and stdin and prints a chosen line, so the tests see
# exactly what the picker would show and what it does with a selection.
#
# Fixture (ages are relative to the time of the test run):
#   local   main (current, 10d)  old (6d, Alice)  mid (4d)
#           zeta (tip 1h, local only: newest, and last alphabetically)
#           feat/new (tip 1d, Bob Builder; first commit off main 3d)
#   origin  main  feat/new  rem/only (2h, Carol)  dup (30m)   origin/HEAD -> main
#   up      dup (45m)
#   rem/only and dup have no local branch.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_git-switch-pick"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    STUBS="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$STUBS"
    export FZF_ARGS_OUT="$BATS_TEST_TMPDIR/fzf.args" FZF_STDIN_OUT="$BATS_TEST_TMPDIR/fzf.stdin"
    cat >"$STUBS/fzf" <<'SH'
#!/bin/sh
printf '%s\n' "$@" >"$FZF_ARGS_OUT"
cat >"$FZF_STDIN_OUT"
[ -n "${FZF_RC:-}" ] && exit "$FZF_RC"
grep -F -m1 -- "$FZF_PICK" "$FZF_STDIN_OUT"
SH
    chmod +x "$STUBS/fzf"

    NOW="$(date +%s)"
    git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
    git init -q --bare "$BATS_TEST_TMPDIR/up.git"
    W="$BATS_TEST_TMPDIR/work"
    git init -q -b main "$W"
    cd "$W"
    git remote add origin "$BATS_TEST_TMPDIR/origin.git"
    git remote add up "$BATS_TEST_TMPDIR/up.git"
    commit init 864000 Zed
    git push -q origin main
    git remote set-head origin main
    git switch -q -c old;      commit "old tip" 518400 Alice; git switch -q main
    git switch -q -c mid;      commit "mid tip" 345600 Mallory; git switch -q main
    git switch -q -c feat/new; commit "feat first" 259200 Bob; FIRST="$(git rev-parse HEAD)"
    commit "feat tip" 86400 "Bob Builder"; git push -q origin feat/new; git switch -q main
    git switch -q -c zeta;     commit "zeta tip" 3600 Zoe; git switch -q main
    git switch -q -c rem/only main; commit "remote only tip" 7200 Carol
    git push -q origin rem/only; git switch -q main; git branch -qD rem/only
    git switch -q -c dup main; commit "dup on origin" 1800 Dan
    git push -q origin dup; git switch -q -C dup main; commit "dup on up" 2700 Dan
    git push -q up dup; git switch -q main; git branch -qD dup
}

commit() { # subject seconds-ago author
    local d="$(( NOW - $2 )) +0000"
    GIT_AUTHOR_NAME="$3" GIT_COMMITTER_NAME="$3" GIT_AUTHOR_EMAIL=t@e.t GIT_COMMITTER_EMAIL=t@e.t \
        GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -q --allow-empty -m "$1"
}

pick() { # run the script in the work repo with the fzf stub first on PATH
    cd "$BATS_TEST_TMPDIR/work"
    run env PATH="$STUBS:$PATH" bash "$SCRIPT" "$@"
}

keys() { cut -f1 "$FZF_STDIN_OUT"; }
plain() { sed $'s/\033\\[[0-9;]*m//g' "$FZF_STDIN_OUT"; }
head_branch() { git -C "$BATS_TEST_TMPDIR/work" symbolic-ref --short HEAD; }

@test "gsw lists local branches newest first and leaves out the current branch" {
    FZF_PICK=refs/heads/mid pick
    [ "$status" -eq 0 ]
    [ "$(keys | paste -sd' ' -)" = "refs/heads/zeta refs/heads/feat/new refs/heads/mid refs/heads/old" ]
}

@test "gsw rows show last commit age, short hash, author, branch and subject" {
    FZF_PICK=refs/heads/mid pick
    row="$(plain | grep -F 'refs/heads/feat/new' | cut -f2-)"
    hash="$(git rev-parse --short feat/new)"
    for want in "24 hours ago" "$hash" "Bob Builder" "feat/new" "feat tip"; do
        [[ "$row" == *"$want"* ]] || { echo "missing '$want' in: $row"; return 1; }
    done
    [[ "$(plain | grep -F refs/heads/old | cut -f2-)" == *"6 days ago"*Alice*old*"old tip"* ]]
}

@test "gsw starts fzf in the default layout, unsorted so the newest row stays next to the prompt" {
    FZF_PICK=refs/heads/mid pick
    args="$(cat "$FZF_ARGS_OUT")"
    for want in --ansi --no-sort "--with-nth=2.." $'--delimiter=\t' "switch> " --border "50%"; do
        grep -qxF -- "$want" <<<"$args" || { echo "missing arg: $want"; return 1; }
    done
    run grep -E -- '--layout|--reverse|--tac|--tiebreak' <<<"$args"
    [ "$status" -eq 1 ]
}

@test "gsw switches to the selected branch" {
    FZF_PICK=refs/heads/mid pick
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = mid ]
}

@test "a cancelled fzf switches nothing and fails" {
    FZF_RC=130 pick
    [ "$status" -ne 0 ]
    [ -e "$FZF_ARGS_OUT" ]
    [ "$(head_branch)" = main ]
    rm -f "$FZF_ARGS_OUT"
    FZF_RC=130 pick --remote
    [ "$status" -ne 0 ]
    [ -e "$FZF_ARGS_OUT" ]
    [ "$(head_branch)" = main ]
}

@test "without fzf it says missing: fzf and fails" {
    bin="$BATS_TEST_TMPDIR/nofzf"; mkdir -p "$bin"
    for t in git bash env sh awk sed grep cat cut sort head tail dirname basename tr mktemp rm; do
        p="$(command -v "$t")" && ln -s "$p" "$bin/$t"
    done
    cd "$BATS_TEST_TMPDIR/work"
    run env PATH="$bin" bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [ "$output" = "missing: fzf" ]
    run env PATH="$bin" bash "$SCRIPT" --remote
    [ "$output" = "missing: fzf" ]
}

@test "with no other branch it prints no branches and does not start fzf" {
    cd "$BATS_TEST_TMPDIR/work"
    git branch -D old mid feat/new zeta -q
    FZF_PICK=x pick
    [ "$status" -ne 0 ]
    [ "$output" = "no branches" ]
    [ ! -e "$FZF_ARGS_OUT" ]
}

@test "gsw with arguments skips fzf and passes them to git switch" {
    pick mid
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = mid ]
    [ ! -e "$FZF_ARGS_OUT" ]
    pick -c fresh main
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = fresh ]
    [ ! -e "$FZF_ARGS_OUT" ]
}

@test "gswr lists remote branches newest first, without HEAD, marking those with a local branch" {
    FZF_PICK=refs/remotes/origin/rem/only pick --remote
    [ "$status" -eq 0 ]
    [ "$(keys | paste -sd' ' -)" = "refs/remotes/origin/dup refs/remotes/up/dup refs/remotes/origin/rem/only refs/remotes/origin/feat/new refs/remotes/origin/main" ]
    run grep -c HEAD <(plain)
    [ "$output" = 0 ]
    plain | grep -F refs/remotes/origin/feat/new | grep -qF '✓ local'
    plain | grep -F refs/remotes/origin/main | grep -qF '✓ local'
    [ "$(plain | grep -F refs/remotes/origin/rem/only | grep -cF '✓ local')" = 0 ]
    grep -qxF "switch (remote)> " "$FZF_ARGS_OUT"
    row="$(plain | grep -F refs/remotes/origin/rem/only | cut -f2-)"
    for want in "2 hours ago" "Carol" "origin/rem/only" "remote only tip"; do
        [[ "$row" == *"$want"* ]] || { echo "missing '$want' in: $row"; return 1; }
    done
}

@test "gswr on a remote-only slashed branch creates a tracking branch named without the remote" {
    FZF_PICK=refs/remotes/origin/rem/only pick --remote
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = rem/only ]
    [ "$(git -C "$BATS_TEST_TMPDIR/work" config branch.rem/only.remote)" = origin ]
    [ "$(git -C "$BATS_TEST_TMPDIR/work" config branch.rem/only.merge)" = refs/heads/rem/only ]
}

@test "gswr on a branch that already exists locally switches to it without tracking" {
    FZF_PICK=refs/remotes/origin/feat/new pick --remote
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = feat/new ]
    run git -C "$BATS_TEST_TMPDIR/work" config branch.feat/new.remote
    [ "$status" -ne 0 ]
}

@test "gswr on a name that exists on two remotes follows the remote that was picked" {
    FZF_PICK=refs/remotes/up/dup pick --remote
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = dup ]
    [ "$(git -C "$BATS_TEST_TMPDIR/work" config branch.dup.remote)" = up ]
}

@test "gswr with a name skips fzf, strips an optional remote prefix and keeps slashes" {
    pick --remote rem/only
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = rem/only ]
    [ ! -e "$FZF_ARGS_OUT" ]
    git -C "$BATS_TEST_TMPDIR/work" switch -q main
    git -C "$BATS_TEST_TMPDIR/work" branch -qD rem/only
    pick --remote origin/rem/only
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = rem/only ]
    pick --remote main
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = main ]
}

@test "gswr with an ambiguous or unknown name fails without switching" {
    pick --remote dup
    [ "$status" -ne 0 ]
    [[ "$output" == *ambiguous* ]]
    [[ "$output" == *origin/dup* && "$output" == *up/dup* ]]
    [ "$(head_branch)" = main ]
    pick --remote origin/dup
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = dup ]
    git -C "$BATS_TEST_TMPDIR/work" switch -q main
    pick --remote nope
    [ "$status" -ne 0 ]
    [ "$(head_branch)" = main ]
}

@test "--help prints usage and exits 0; gswr rejects an unknown flag" {
    pick --help
    [ "$status" -eq 0 ]
    [[ "$output" == *Usage* ]]
    pick --remote --definitely-not-a-flag
    [ "$status" -ne 0 ]
}

@test "the preview shows the log graph, the first commit off the default branch and the reflog entry" {
    FZF_PICK=refs/heads/mid pick
    preview="$(grep -A1 -x -- '--preview' "$FZF_ARGS_OUT" | tail -n1)"
    [[ "$preview" == *"{1}"* ]]
    cd "$BATS_TEST_TMPDIR/work"
    run bash -c "${preview//\{1\}/\'refs/heads/feat/new\'}"
    [ "$status" -eq 0 ]
    out="$(printf '%s' "$output" | sed $'s/\033\\[[0-9;]*m//g')"
    first_date="$(git log -1 --format=%cs "$FIRST")"
    [[ "$out" == *"$first_date $(git rev-parse --short "$FIRST") Bob"* ]] || { echo "$out"; return 1; }
    [[ "$out" == *"origin/main"* ]]
    [[ "$out" == *"feat/new@{"*"branch: Created from"* ]] || { echo "$out"; return 1; }
    [[ "$out" == *"* "*"feat tip"* && "$out" == *"feat first"* && "$out" == *"init"* ]]
}

@test "the preview of a remote branch has no reflog line" {
    FZF_PICK=refs/heads/mid pick --remote
    preview="$(grep -A1 -x -- '--preview' "$FZF_ARGS_OUT" | tail -n1)"
    cd "$BATS_TEST_TMPDIR/work"
    run bash -c "${preview//\{1\}/\'refs/remotes/origin/rem/only\'}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"remote only tip"* ]]
    [[ "$output" == *"Reflog"*"n/a"* ]]
}

@test "gswr handles a remote whose name contains a slash" {
    cd "$BATS_TEST_TMPDIR/work"
    git init -q --bare "$BATS_TEST_TMPDIR/team.git"
    git remote add team/a "$BATS_TEST_TMPDIR/team.git"
    git switch -q -c tb main; commit "tb tip" 600 Tess; git push -q team/a tb
    git switch -q -c tl main; commit "tl tip" 300 Tess; git push -q team/a tl
    git switch -q main; git branch -qD tb
    FZF_PICK=refs/remotes/team/a/tb pick --remote
    [ "$status" -eq 0 ]
    [ "$(plain | grep -F refs/remotes/team/a/tl | grep -cF '✓ local')" = 1 ]
    [ "$(plain | grep -F refs/remotes/team/a/tb | grep -cF '✓ local')" = 0 ]
    [[ "$(plain | grep -F refs/remotes/team/a/tb | cut -f2-)" == *" team/a/tb "* ]]
    [ "$(head_branch)" = tb ]
    [ "$(git config branch.tb.remote)" = team/a ]
    [ "$(git config branch.tb.merge)" = refs/heads/tb ]
    git switch -q main; git branch -qD tb
    pick --remote team/a/tb
    [ "$status" -eq 0 ]
    [ "$(head_branch)" = tb ]
    git switch -q main; git branch -qD tb
    pick --remote tb
    [ "$status" -eq 0 ]
    [ "$(git config branch.tb.remote)" = team/a ]
}

@test "gsw marks branches checked out in another worktree but keeps them listed" {
    cd "$BATS_TEST_TMPDIR/work"
    git worktree add -q "$BATS_TEST_TMPDIR/wt-old" old
    FZF_RC=130 pick
    [ "$(plain | grep -F refs/heads/old | grep -cF '⊕ wt')" = 1 ]
    [ "$(plain | grep -F refs/heads/mid | grep -cF '⊕ wt')" = 0 ]
    [ "$(keys | grep -c refs/heads/old)" = 1 ]
    # from inside that worktree its own branch is the current one: not listed, not marked
    cd "$BATS_TEST_TMPDIR/wt-old"
    run env PATH="$STUBS:$PATH" FZF_RC=130 bash "$SCRIPT"
    [ "$(keys | grep -c refs/heads/old)" = 0 ]
    [ "$(plain | grep -F refs/heads/mid | grep -cF '⊕ wt')" = 0 ]
}
