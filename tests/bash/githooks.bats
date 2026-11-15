#!/usr/bin/env bats
# T-0051 no-stash guard: the tracked dispatchers in ops/githooks/ and the
# installer ops/install-git-hooks.sh. Every test runs in a scratch repository
# with a lefthook STUB that records its arguments, so nothing here touches the
# real repository's hooks, config or stash.
#
# Run:  bats tests/bash/githooks.bats

bats_require_minimum_version 1.5.0

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    export GIT_CONFIG_GLOBAL="$HOME/.gitconfig" GIT_CONFIG_NOSYSTEM=1
    printf '[user]\n\tname = T\n\temail = t@example.invalid\n[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n' \
        >"$GIT_CONFIG_GLOBAL"
    # A run inside a git hook must not leak its repository into these tests.
    unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE SKIP_HOOKS "${!LEFTHOOK@}"

    STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    # The stub's own variables must not start with LEFTHOOK: the dispatcher
    # refuses every such variable.
    cat >"$STUBS/lefthook" <<STUB
#!/usr/bin/env bash
{
  echo "args=\$*"
  echo "config=\${LEFTHOOK_CONFIG-}"
  echo "cwd=\$PWD"
} >>"$STUB_LOG"
if [ "\${2:-}" = pre-push ]; then echo "stdin=\$(cat)" >>"$STUB_LOG"; fi
exit 0
STUB
    chmod +x "$STUBS/lefthook"
    REAL_PATH="$PATH"
    export PATH="$STUBS:$PATH"
}

# mkrepo [name]: scratch repo. Commit 1 has only .lefthook.yml (an "old"
# commit, before ops/githooks existed); commit 2 adds the dispatchers and the
# installer. No hooks run while the repo is built.
mkrepo() {
    R="$BATS_TEST_TMPDIR/${1:-main}"
    mkdir -p "$R/ops/githooks"
    git -C "$R" init -q -b main
    printf 'pre-commit:\n  commands: {}\n' >"$R/.lefthook.yml"
    git -C "$R" add -A
    git -C "$R" commit -q -m "chore: base"
    cp -p "$REPO_ROOT"/ops/githooks/* "$R/ops/githooks/"
    cp -p "$REPO_ROOT/ops/install-git-hooks.sh" "$R/ops/"
    git -C "$R" add -A
    git -C "$R" commit -q -m "chore: hooks"
    COMMON="$(git -C "$R" rev-parse --path-format=absolute --git-common-dir)"
    DEST="$COMMON/app-configs-hooks"
}

install_hooks() { (cd "$R" && bash ops/install-git-hooks.sh "$@"); }

# Fresh repo with the hooks installed and a few committed files.
hooked() {
    mkrepo "$@"
    install_hooks >/dev/null
    printf 'one\n' >"$R/a.txt"
    printf 'two\n' >"$R/b.txt"
    git -C "$R" add -A
    git -C "$R" commit -q -m "chore: files"
    : >"$STUB_LOG"
}

# snap: everything the refusal invariant covers, as one comparable string.
snap() {
    {
        git -C "$R" ls-files -s
        git -C "$R" rev-parse HEAD
        git -C "$R" stash list
        (cd "$R" && find . -path ./.git -prune -o -type f -exec sha256sum {} +) | LC_ALL=C sort
        (cd "$R" && find . -path ./.git -prune -o -type l -exec sh -c 'for f; do echo "$f -> $(readlink "$f")"; done' sh {} +) | LC_ALL=C sort
    } 2>&1
}

dest_snap() { (cd "$DEST" && find . -type f -exec sha256sum {} + | LC_ALL=C sort; stat -c '%a' ./* | tr '\n' ' '); }

gc() { run git -C "$R" commit -q -m "feat: x" "$@"; }
refused() {
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused"* ]]
    [ ! -s "$STUB_LOG" ]
}
called() { grep -qxF "$1" "$STUB_LOG"; }

# ── static: tracked sources, modes, attributes ──────────────────────────────

@test "the dispatchers are tracked with LF attributes and the right modes" {
    cd "$REPO_ROOT"
    run git ls-files -s -- ops/githooks
    [ "$status" -eq 0 ]
    [[ "$output" == "100644 "*"	ops/githooks/_lefthook.sh"* ]]
    for h in pre-commit commit-msg pre-push post-merge; do
        [[ "$output" == *"100755 "*"	ops/githooks/$h"* ]]
    done
    grep -qxF 'ops/githooks/* text eol=lf' .gitattributes
    run git check-attr eol text -- ops/githooks/pre-commit
    [[ "$output" == *"eol: lf"* ]]
}

@test "the hook names in .lefthook.yml equal the dispatcher set" {
    cd "$REPO_ROOT"
    from_yaml="$(grep -E '^[a-z-]+:$' .lefthook.yml | tr -d ':' | LC_ALL=C sort | tr '\n' ' ')"
    from_tree="$(git ls-files -- ops/githooks | sed 's|.*/||' | grep -v '^_' | LC_ALL=C sort | tr '\n' ' ')"
    [ "$from_yaml" = "$from_tree" ]
}

@test "dispatchers and installer never call git stash, add, checkout, restore, reset or update-index" {
    cd "$REPO_ROOT"
    # Executable lines only: comments and the user-facing messages may name them.
    code="$(cat ops/githooks/* ops/install-git-hooks.sh | grep -vE '^[[:space:]]*(#|echo |printf )')"
    run grep -nE '\bgit( +-[^ ]+( +[^ -][^ ]*)?)* +(stash|add|checkout|restore|reset|update-index)\b' <<<"$code"
    [ "$status" -eq 1 ]
    # The installer's own g() wrapper form.
    run grep -nE '\bg( +-[^ ]+)* +(stash|add|checkout|restore|reset|update-index)\b' <<<"$code"
    [ "$status" -eq 1 ]
    run grep -nE 'lefthook +(un)?install' <<<"$code"
    [ "$status" -eq 1 ]
}

@test "the dispatchers parse under bash and avoid bash 4 constructs" {
    cd "$REPO_ROOT"
    for f in ops/githooks/* ops/install-git-hooks.sh; do bash -n "$f"; done
    code="$(cat ops/githooks/* ops/install-git-hooks.sh | grep -vE '^[[:space:]]*#')"
    run grep -nE 'mapfile|readarray|declare +-A|local +-A|\$\{[a-z_]+(,,|\^\^)' <<<"$code"
    [ "$status" -eq 1 ]
}

@test "update-all runs the installer and then --check; uninstall unsets hooksPath and deletes dest" {
    cd "$REPO_ROOT"
    grep -q 'install-git-hooks.sh' ops/update-all.sh
    grep -q 'install-git-hooks.sh" --check' ops/update-all.sh
    grep -q 'core.hooksPath' ops/uninstall.sh
    grep -q 'app-configs-hooks' ops/uninstall.sh
    run grep -nE '^[^#]*lefthook +uninstall' ops/uninstall.sh
    [ "$status" -eq 1 ]
}

# ── pre-commit: refusal and the invariant ───────────────────────────────────

@test "a partially staged path with spaces, brackets and a star is refused; nothing changes" {
    hooked
    f='sp ace [x]*.txt'
    printf 'v1\n' >"$R/$f"
    git -C "$R" add -- "$f"
    git -C "$R" commit -q -m "chore: add"
    : >"$STUB_LOG"
    printf 'v2\n' >"$R/$f"
    git -C "$R" add -- "$f"
    printf 'v3\n' >"$R/$f"
    before="$(snap)"
    gc
    refused
    [[ "$output" == *"[pre-commit] refused: these paths have both staged and unstaged changes:"* ]]
    [[ "$output" == *"$f"* ]]
    [[ "$output" == *'git stash is shared by every worktree (AGENTS.md forbids it). Nothing was changed.'* ]]
    [[ "$output" == *'follow "Partial commits" in docs/getting-started/install.md.'* ]]
    [ "$(snap)" = "$before" ]
}

@test "a staged rename plus an unstaged edit is refused; nothing changes" {
    hooked
    git -C "$R" mv a.txt renamed.txt
    printf 'staged edit\n' >"$R/renamed.txt"
    git -C "$R" add renamed.txt
    printf 'unstaged edit\n' >"$R/renamed.txt"
    before="$(snap)"
    gc
    refused
    [[ "$output" == *"renamed.txt"* ]]
    [ "$(snap)" = "$before" ]
}

@test "a staged type change plus an unstaged edit is refused; nothing changes" {
    hooked
    rm "$R/a.txt"
    ln -s b.txt "$R/a.txt"
    git -C "$R" add a.txt
    rm "$R/a.txt"
    printf 'regular again\n' >"$R/a.txt"
    before="$(snap)"
    gc
    refused
    [[ "$output" == *"a.txt"* ]]
    [ "$(snap)" = "$before" ]
}

@test "only the offending paths are named" {
    hooked
    printf 'x\n' >"$R/a.txt"
    git -C "$R" add a.txt
    printf 'y\n' >"$R/a.txt"
    printf 'only staged\n' >"$R/b.txt"
    git -C "$R" add b.txt
    gc
    refused
    [[ "$output" == *$'\na.txt\n'* ]]
    [[ "$output" != *$'\nb.txt\n'* ]]
}

# ── pre-commit: allowed shapes ──────────────────────────────────────────────

@test "a fully staged commit with unrelated unstaged changes reaches lefthook with the pinned config" {
    hooked
    printf 'staged\n' >"$R/a.txt"
    git -C "$R" add a.txt
    printf 'unrelated\n' >"$R/b.txt"
    gc
    [ "$status" -eq 0 ]
    top="$(git -C "$R" rev-parse --show-toplevel)"
    called "args=run pre-commit --no-stage-fixed --no-auto-install"
    called "config=$top/.lefthook.yml"
    called "cwd=$top"
    # commit-msg got the message file argument.
    grep -q '^args=run commit-msg --no-auto-install .*COMMIT_EDITMSG$' "$STUB_LOG"
    [ "$(cat "$R/b.txt")" = unrelated ]
}

@test "git commit <path> works while another file is partially staged" {
    hooked
    printf 'x\n' >"$R/a.txt"
    git -C "$R" add a.txt
    printf 'y\n' >"$R/a.txt"
    printf 'only this\n' >"$R/b.txt"
    run git -C "$R" commit -q -m "feat: only b" -- b.txt
    [ "$status" -eq 0 ]
    called "args=run pre-commit --no-stage-fixed --no-auto-install"
}

@test "git commit -a is allowed" {
    hooked
    printf 'x\n' >"$R/a.txt"
    git -C "$R" add a.txt
    printf 'y\n' >"$R/a.txt"
    run git -C "$R" commit -q -a -m "feat: all"
    [ "$status" -eq 0 ]
    called "args=run pre-commit --no-stage-fixed --no-auto-install"
}

@test "git add -N (intent to add) is allowed" {
    hooked
    printf 'staged\n' >"$R/a.txt"
    git -C "$R" add a.txt
    printf 'new\n' >"$R/new.txt"
    git -C "$R" add -N new.txt
    gc
    [ "$status" -eq 0 ]
    called "args=run pre-commit --no-stage-fixed --no-auto-install"
}

@test "1000 staged long paths are checked in batches and pass; one unstaged edit among them is named" {
    hooked
    mkdir -p "$R/dir"
    pad="$(printf 'p%.0s' $(seq 1 90))"
    for i in $(seq 1 1000); do printf '%s\n' "$i" >"$R/dir/${pad}_$i.txt"; done
    git -C "$R" add dir
    gc
    [ "$status" -eq 0 ]
    called "args=run pre-commit --no-stage-fixed --no-auto-install"
    : >"$STUB_LOG"
    for i in $(seq 1 1000); do printf 'again %s\n' "$i" >"$R/dir/${pad}_$i.txt"; done
    git -C "$R" add dir
    printf 'late edit\n' >"$R/dir/${pad}_1000.txt"
    gc
    refused
    [[ "$output" == *"dir/${pad}_1000.txt"* ]]
    [[ "$output" != *"dir/${pad}_999.txt"* ]]
}

@test "a failure of the staged-name listing fails closed" {
    hooked
    printf 'staged\n' >"$R/a.txt"
    git -C "$R" add a.txt
    cat >"$STUBS/git" <<STUB
#!/usr/bin/env bash
case " \$* " in *" --cached "*) exit 3 ;; esac
exec "$(command -v git)" "\$@"
STUB
    chmod +x "$STUBS/git"
    # Run the dispatcher directly: git puts its own exec-path first when it
    # runs a hook, which would bypass the stub.
    cd "$R"
    run bash "$DEST/pre-commit"
    [ "$status" -ne 0 ]
    [ ! -s "$STUB_LOG" ]
}

# ── bypass attempts ─────────────────────────────────────────────────────────

stage_one() { printf 'staged\n' >"$R/a.txt"; git -C "$R" add a.txt; }

@test "LEFTHOOK, LEFTHOOK_EXCLUDE, a foreign LEFTHOOK_CONFIG and LEFTHOOK_BIN are all refused" {
    hooked
    stage_one
    for assign in LEFTHOOK=0 LEFTHOOK_EXCLUDE=x LEFTHOOK_CONFIG=/tmp/other.yml LEFTHOOK_BIN=/bin/true LEFTHOOK_OUTPUT=meta; do
        : >"$STUB_LOG"
        run env "$assign" git -C "$R" commit -q -m "feat: x"
        refused
        [[ "$output" == *"${assign%%=*}"* ]]
    done
}

@test "LEFTHOOK_VERBOSE and an already pinned LEFTHOOK_CONFIG are allowed" {
    hooked
    stage_one
    top="$(git -C "$R" rev-parse --show-toplevel)"
    run env LEFTHOOK_VERBOSE=1 LEFTHOOK_QUIET=true git -C "$R" commit -q -m "feat: x"
    [ "$status" -eq 0 ]
    printf 'again\n' >"$R/a.txt"
    git -C "$R" add a.txt
    run env LEFTHOOK_CONFIG="$top/.lefthook.yml" git -C "$R" commit -q -m "feat: y"
    [ "$status" -eq 0 ]
}

@test "every local-config form is refused" {
    hooked
    stage_one
    mkdir -p "$R/.config"
    for rel in lefthook-local.yml .lefthook-local.toml .config/lefthook-local.json .config/.lefthook-local.jsonc lefthook-local.yaml; do
        : >"$R/$rel"
        : >"$STUB_LOG"
        run git -C "$R" commit -q -m "feat: x"
        refused
        [[ "$output" == *"lefthook-local"* ]]
        rm -f "$R/$rel"
    done
    # A symlink, even a dangling one, counts.
    ln -s /nonexistent/target "$R/lefthook-local.yml"
    run git -C "$R" commit -q -m "feat: x"
    refused
    rm -f "$R/lefthook-local.yml"
    run git -C "$R" commit -q -m "feat: x"
    [ "$status" -eq 0 ]
}

@test "a missing .lefthook.yml is refused" {
    hooked
    stage_one
    rm "$R/.lefthook.yml"
    gc
    refused
    [[ "$output" == *".lefthook.yml"* ]]
}

@test "SKIP_HOOKS is refused (pending the user's decision on the pre-push escape hatch)" {
    hooked
    stage_one
    run env SKIP_HOOKS=1 git -C "$R" commit -q -m "feat: x"
    refused
    [[ "$output" == *"SKIP_HOOKS"* ]]
}

@test "lefthook missing: refused with the open-a-new-terminal message" {
    hooked
    stage_one
    rm "$STUBS/lefthook"
    # Hide any real lefthook too: keep only the tools the hook itself needs.
    mkdir -p "$BATS_TEST_TMPDIR/nolh"
    for t in bash git env sh cat rm mktemp dirname; do ln -sf "$(command -v "$t")" "$BATS_TEST_TMPDIR/nolh/$t"; done
    run env PATH="$BATS_TEST_TMPDIR/nolh" git -C "$R" commit -q -m "feat: x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"lefthook not found; commit blocked."* ]]
    [[ "$output" == *"open a new terminal"* ]]
    [[ "$output" == *"winget install --id evilmartians.lefthook --exact"* ]]
}

# ── other dispatchers ───────────────────────────────────────────────────────

@test "pre-push keeps stdin for lefthook" {
    hooked
    cd "$R"
    run bash -c "printf 'refs/heads/x aaa refs/heads/x bbb\n' | bash '$DEST/pre-push' origin url"
    [ "$status" -eq 0 ]
    called "args=run pre-push --no-auto-install origin url"
    called "stdin=refs/heads/x aaa refs/heads/x bbb"
}

@test "post-merge dispatches with --no-auto-install" {
    hooked
    cd "$R"
    run bash "$DEST/post-merge" 0
    [ "$status" -eq 0 ]
    called "args=run post-merge --no-auto-install 0"
}

@test "the other dispatchers refuse the same bypasses" {
    hooked
    cd "$R"
    run env LEFTHOOK=0 bash "$DEST/pre-push" origin url </dev/null
    [ "$status" -ne 0 ]
    run env SKIP_HOOKS=1 bash "$DEST/commit-msg" msgfile
    [ "$status" -ne 0 ]
    [ ! -s "$STUB_LOG" ]
}

# ── real lefthook ───────────────────────────────────────────────────────────

@test "with the real lefthook an untracked lefthook.yml does not shadow .lefthook.yml" {
    if ! PATH="$REAL_PATH" command -v lefthook >/dev/null 2>&1; then skip "lefthook not installed"; fi
    rm "$STUBS/lefthook"
    mkrepo real
    printf 'pre-commit:\n  commands:\n    real:\n      run: touch ran.marker\n' >"$R/.lefthook.yml"
    git -C "$R" add .lefthook.yml
    git -C "$R" commit -q -m "chore: real config"
    install_hooks >/dev/null
    printf 'pre-commit:\n  commands:\n    shadow:\n      run: touch shadow.marker\n' >"$R/lefthook.yml"
    printf 'x\n' >"$R/a.txt"
    git -C "$R" add a.txt
    run git -C "$R" commit -q -m "feat: x"
    echo "$output"
    [ "$status" -eq 0 ]
    [ -e "$R/ran.marker" ]
    [ ! -e "$R/shadow.marker" ]
}

@test "with the real lefthook a lefthook-local file would skip commands, so the guard must refuse it" {
    if ! PATH="$REAL_PATH" command -v lefthook >/dev/null 2>&1; then skip "lefthook not installed"; fi
    rm "$STUBS/lefthook"
    mkrepo real
    printf 'pre-commit:\n  commands:\n    real:\n      run: touch ran.marker\n' >"$R/.lefthook.yml"
    git -C "$R" add .lefthook.yml
    git -C "$R" commit -q -m "chore: real config"
    install_hooks >/dev/null
    mkdir -p "$R/.config"
    printf 'pre-commit:\n  commands:\n    real:\n      skip: true\n' >"$R/.config/lefthook-local.yml"
    printf 'x\n' >"$R/a.txt"
    git -C "$R" add a.txt
    run git -C "$R" commit -q -m "feat: x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"lefthook-local"* ]]
    [ ! -e "$R/ran.marker" ]
}

# ── literal pathspecs ───────────────────────────────────────────────────────

@test "the refusal holds under git --literal-pathspecs and GIT_LITERAL_PATHSPECS=1" {
    hooked
    printf 'x\n' >"$R/a.txt"
    git -C "$R" add a.txt
    printf 'y\n' >"$R/a.txt"
    run git --literal-pathspecs -C "$R" commit -q -m "feat: x"
    refused
    run env GIT_LITERAL_PATHSPECS=1 git -C "$R" commit -q -m "feat: x"
    refused
    run env GIT_GLOB_PATHSPECS=1 git -C "$R" commit -q -m "feat: x"
    refused
    [[ "$output" == *"these paths have both staged and unstaged changes:"* ]]
    [[ "$output" == *$'\na.txt\n'* ]]
}

@test "magic-looking, dash-leading and newline names are matched literally and named" {
    hooked
    lg() { GIT_LITERAL_PATHSPECS=1 git -C "$R" "$@"; }
    nl=$'nl\nname.txt'
    for f in ':(glob)x*' 'xdecoy' '-n' '-dash file.txt' "$nl"; do printf 'v1\n' >"$R/$f"; done
    lg add -- ':(glob)x*' xdecoy -n '-dash file.txt' "$nl"
    lg commit -q -m "chore: odd names"
    : >"$STUB_LOG"
    for f in ':(glob)x*' '-n' '-dash file.txt' "$nl"; do
        printf 'v2\n' >"$R/$f"
        lg add -- "$f"
        printf 'v3\n' >"$R/$f"
    done
    gc
    refused
    [[ "$output" == *$':(glob)x*\n'* ]]
    [[ "$output" == *$'\n-n\n'* ]]
    [[ "$output" == *$'\n-dash file.txt\n'* ]]
    [[ "$output" == *$'nl\nname.txt'* ]]
    [[ "$output" != *"xdecoy"* ]]
}

@test "a failing per-path comparison in the offender scan fails closed" {
    hooked
    printf 'x\n' >"$R/a.txt"
    printf 'x\n' >"$R/b.txt"
    git -C "$R" add a.txt b.txt
    printf 'y\n' >"$R/a.txt"
    cat >"$STUBS/git" <<STUB
#!/usr/bin/env bash
case " \$* " in
  *" --quiet "*)
    n=0; seen=0
    for a in "\$@"; do
      if [ "\$seen" = 1 ]; then n=\$((n + 1)); fi
      [ "\$a" = -- ] && seen=1
    done
    if [ "\$n" -gt 1 ]; then exit 1; else exit 3; fi ;;
esac
exec "$(command -v git)" "\$@"
STUB
    chmod +x "$STUBS/git"
    cd "$R"
    run bash "$DEST/pre-commit"
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not compare"* ]]
    [ ! -s "$STUB_LOG" ]
}

# ── worktrees ───────────────────────────────────────────────────────────────

@test "a linked worktree at the current commit commits through the installed dispatchers" {
    hooked
    git -C "$R" worktree add -q -b feat "$BATS_TEST_TMPDIR/wt"
    printf 'wt\n' >"$BATS_TEST_TMPDIR/wt/a.txt"
    git -C "$BATS_TEST_TMPDIR/wt" add a.txt
    run git -C "$BATS_TEST_TMPDIR/wt" commit -q -m "feat: wt"
    [ "$status" -eq 0 ]
    wtop="$(git -C "$BATS_TEST_TMPDIR/wt" rev-parse --show-toplevel)"
    called "config=$wtop/.lefthook.yml"
    called "cwd=$wtop"
}

@test "a worktree of an OLD commit without ops/githooks still runs the copied dispatcher in its own top" {
    hooked
    git -C "$R" worktree add -q -b old "$BATS_TEST_TMPDIR/old" HEAD~2
    [ ! -e "$BATS_TEST_TMPDIR/old/ops/githooks" ]
    printf 'old\n' >"$BATS_TEST_TMPDIR/old/f.txt"
    git -C "$BATS_TEST_TMPDIR/old" add f.txt
    run git -C "$BATS_TEST_TMPDIR/old" commit -q -m "feat: old"
    [ "$status" -eq 0 ]
    otop="$(git -C "$BATS_TEST_TMPDIR/old" rev-parse --show-toplevel)"
    called "config=$otop/.lefthook.yml"
    called "cwd=$otop"
}

@test "a worktree partial commit is refused too" {
    hooked
    git -C "$R" worktree add -q -b feat "$BATS_TEST_TMPDIR/wt"
    printf 'x\n' >"$BATS_TEST_TMPDIR/wt/a.txt"
    git -C "$BATS_TEST_TMPDIR/wt" add a.txt
    printf 'y\n' >"$BATS_TEST_TMPDIR/wt/a.txt"
    run git -C "$BATS_TEST_TMPDIR/wt" commit -q -m "feat: wt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused"* ]]
}

@test "the installer run from a linked worktree is refused and dest stays byte-unchanged" {
    hooked
    git -C "$R" worktree add -q -b feat "$BATS_TEST_TMPDIR/wt"
    before="$(dest_snap)"
    cfg="$(git -C "$R" config --local core.hooksPath)"
    run bash -c "cd '$BATS_TEST_TMPDIR/wt' && bash ops/install-git-hooks.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"run from the main worktree: $R"* ]]
    [ "$(dest_snap)" = "$before" ]
    [ "$(git -C "$R" config --local core.hooksPath)" = "$cfg" ]
}

@test "--check from a linked worktree passes when installed and fails when a copy is edited" {
    hooked
    git -C "$R" worktree add -q -b feat "$BATS_TEST_TMPDIR/wt"
    run bash -c "cd '$BATS_TEST_TMPDIR/wt' && bash ops/install-git-hooks.sh --check"
    [ "$status" -eq 0 ]
    # A linked worktree is not told to re-run the installer when its own HEAD differs.
    git -C "$BATS_TEST_TMPDIR/wt" commit -q --allow-empty -m "chore: empty"
    run bash -c "cd '$BATS_TEST_TMPDIR/wt' && bash ops/install-git-hooks.sh --check"
    [ "$status" -eq 0 ]
    echo '# tamper' >>"$DEST/pre-commit"
    run bash -c "cd '$BATS_TEST_TMPDIR/wt' && bash ops/install-git-hooks.sh --check"
    [ "$status" -eq 1 ]
}

# ── installer ───────────────────────────────────────────────────────────────

@test "the installer sets an absolute hooksPath, installs executable HEAD blobs and writes the manifest last" {
    mkrepo
    real_mv="$(command -v mv)"
    cat >"$STUBS/mv" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\${*: -1}" >>"$BATS_TEST_TMPDIR/mv.log"
exec "$real_mv" "\$@"
STUB
    chmod +x "$STUBS/mv"
    run install_hooks
    echo "$output"
    [ "$status" -eq 0 ]
    path="$(git -C "$R" config --local core.hooksPath)"
    [ "$path" = "$DEST" ]
    [[ "$path" == /* ]]
    for f in _lefthook.sh pre-commit commit-msg pre-push post-merge; do
        [ -x "$DEST/$f" ]
        [ "$(git hash-object "$DEST/$f")" = "$(git -C "$R" rev-parse "HEAD:ops/githooks/$f")" ]
    done
    [ -s "$DEST/.manifest" ]
    [[ "$(tail -n 1 "$BATS_TEST_TMPDIR/mv.log")" == */.manifest ]]
    grep -q "^commit $(git -C "$R" rev-parse HEAD)\$" "$DEST/.manifest"
    grep -q "^pre-commit $(git -C "$R" rev-parse HEAD:ops/githooks/pre-commit)\$" "$DEST/.manifest"
}

@test "an uncommitted dispatcher edit is not installed" {
    mkrepo
    echo '# local edit' >>"$R/ops/githooks/pre-commit"
    run install_hooks
    [ "$status" -eq 0 ]
    [ "$(git hash-object "$DEST/pre-commit")" = "$(git -C "$R" rev-parse HEAD:ops/githooks/pre-commit)" ]
    run grep -c 'local edit' "$DEST/pre-commit"
    [ "$output" = 0 ]
}

@test "the installer is idempotent and --check passes afterwards" {
    mkrepo
    install_hooks >/dev/null
    first="$(dest_snap)"
    run install_hooks
    [ "$status" -eq 0 ]
    [ "$(dest_snap)" = "$first" ]
    [ "$(git -C "$R" config --local --get-all core.hooksPath | wc -l)" -eq 1 ]
    run install_hooks --check
    [ "$status" -eq 0 ]
}

@test "stale marker hooks are deleted, tracked dispatchers and non-marker hooks are kept" {
    mkrepo
    mkdir -p "$COMMON/hooks"
    printf '#!/bin/sh\n# call_lefthook\n' >"$COMMON/hooks/pre-commit"
    printf '#!/bin/sh\n# call_lefthook\n' >"$COMMON/hooks/post-merge"
    printf '#!/bin/sh\n# call_lefthook\n' >"$COMMON/hooks/prepare-commit-msg"
    printf '#!/bin/sh\necho mine\n' >"$COMMON/hooks/pre-push"
    run install_hooks
    [ "$status" -eq 0 ]
    [ ! -e "$COMMON/hooks/pre-commit" ]
    [ ! -e "$COMMON/hooks/post-merge" ]
    [ -e "$COMMON/hooks/prepare-commit-msg" ]
    [ -e "$COMMON/hooks/pre-push" ]
    [ "$(git hash-object "$DEST/pre-commit")" = "$(git -C "$R" rev-parse HEAD:ops/githooks/pre-commit)" ]
    : >"$STUB_LOG"
    run grep -c uninstall "$STUB_LOG"
    [ "$output" = 0 ]
}

@test "files in dest that are not in the source set are pruned" {
    mkrepo
    install_hooks >/dev/null
    : >"$DEST/stray"
    run install_hooks
    [ "$status" -eq 0 ]
    [ ! -e "$DEST/stray" ]
}

@test "lefthook uninstall is never called by the installer" {
    mkrepo
    mkdir -p "$COMMON/hooks"
    printf '#!/bin/sh\n# call_lefthook\n' >"$COMMON/hooks/pre-commit"
    run install_hooks
    [ "$status" -eq 0 ]
    if [ -e "$STUB_LOG" ]; then
        run grep -c 'uninstall' "$STUB_LOG"
        [ "$output" = 0 ]
    fi
}

@test "a foreign core.hooksPath is refused and left alone" {
    mkrepo
    git -C "$R" config --local core.hooksPath /somewhere/else
    run install_hooks
    [ "$status" -ne 0 ]
    [[ "$output" == *"core.hooksPath"* ]]
    [ "$(git -C "$R" config --local core.hooksPath)" = /somewhere/else ]
    [ ! -e "$DEST" ]
}

@test "a HEAD without ops/githooks is refused and dest is untouched (fresh and installed)" {
    mkrepo
    git -C "$R" rm -rq ops/githooks
    git -C "$R" commit -q -m "chore: drop hooks"
    run install_hooks
    [ "$status" -ne 0 ]
    [ ! -e "$DEST" ]
    [ -z "$(git -C "$R" config --local --get core.hooksPath || true)" ]
    # And with an earlier good install in place.
    git -C "$R" revert --no-edit HEAD >/dev/null
    install_hooks >/dev/null
    before="$(dest_snap)"
    git -C "$R" rm -rq ops/githooks
    git -C "$R" commit -q -m "chore: drop hooks again"
    run install_hooks
    [ "$status" -ne 0 ]
    [ "$(dest_snap)" = "$before" ]
}

@test "the installer requires lefthook" {
    mkrepo
    rm "$STUBS/lefthook"
    mkdir -p "$BATS_TEST_TMPDIR/nolh"
    for t in bash git env sh cat rm mv mkdir chmod mktemp; do ln -sf "$(command -v "$t")" "$BATS_TEST_TMPDIR/nolh/$t"; done
    run env PATH="$BATS_TEST_TMPDIR/nolh" bash -c "cd '$R' && bash ops/install-git-hooks.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"lefthook"* ]]
    [ ! -e "$DEST" ]
}

@test "the installer end to end: hooks fire in the installed repo" {
    mkrepo
    install_hooks >/dev/null
    printf 'x\n' >"$R/new.txt"
    git -C "$R" add new.txt
    run git -C "$R" commit -q -m "feat: new"
    [ "$status" -eq 0 ]
    called "args=run pre-commit --no-stage-fixed --no-auto-install"
}

@test "stale marker hooks are removed last: a blocked dest leaves them in place" {
    mkrepo
    mkdir -p "$COMMON/hooks"
    printf '#!/bin/sh\n# call_lefthook\n' >"$COMMON/hooks/pre-commit"
    : >"$DEST" # a file where the directory must go
    run install_hooks
    [ "$status" -ne 0 ]
    [ -e "$COMMON/hooks/pre-commit" ]
    [ -z "$(git -C "$R" config --local --get core.hooksPath || true)" ]
}

@test "a moved clone (our directory name, directory missing) is repaired, not refused" {
    mkrepo
    git -C "$R" config --local core.hooksPath /old/place/.git/app-configs-hooks
    run install_hooks
    [ "$status" -eq 0 ]
    [ "$(git -C "$R" config --local core.hooksPath)" = "$DEST" ]
    run install_hooks --check
    [ "$status" -eq 0 ]
}

@test "our directory name with a live directory elsewhere is still foreign" {
    mkrepo
    mkdir -p "$BATS_TEST_TMPDIR/other/app-configs-hooks"
    git -C "$R" config --local core.hooksPath "$BATS_TEST_TMPDIR/other/app-configs-hooks"
    run install_hooks
    [ "$status" -ne 0 ]
    [ "$(git -C "$R" config --local core.hooksPath)" = "$BATS_TEST_TMPDIR/other/app-configs-hooks" ]
}

@test "the installer and --check warn about an overridden global hooksPath and leftover non-marker hooks" {
    mkrepo
    git config --global core.hooksPath /global/hooks
    mkdir -p "$COMMON/hooks"
    printf '#!/bin/sh\necho mine\n' >"$COMMON/hooks/prepare-commit-msg"
    run install_hooks
    [ "$status" -eq 0 ]
    [[ "$output" == *"global core.hooksPath (/global/hooks)"* ]]
    [[ "$output" == *"prepare-commit-msg is not used"* ]]
    run install_hooks --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"global core.hooksPath"* ]]
}

@test "update-all installs the hooks before its COMMIT phase" {
    cd "$REPO_ROOT"
    inst="$(grep -n 'install-git-hooks.sh' ops/update-all.sh | head -1 | cut -d: -f1)"
    commit="$(grep -n 'commit --only "${COMMIT_ARGS\[@\]}"' ops/update-all.sh | head -1 | cut -d: -f1)"
    [ -n "$inst" ]
    [ -n "$commit" ]
    [ "$inst" -lt "$commit" ]
}

# ── --check ─────────────────────────────────────────────────────────────────

@test "--check passes on a fresh install" {
    mkrepo
    install_hooks >/dev/null
    run install_hooks --check
    [ "$status" -eq 0 ]
}

@test "--check fails when hooksPath is unset or points elsewhere" {
    mkrepo
    install_hooks >/dev/null
    git -C "$R" config --local core.hooksPath /elsewhere
    run install_hooks --check
    [ "$status" -eq 1 ]
    git -C "$R" config --local --unset core.hooksPath
    run install_hooks --check
    [ "$status" -eq 1 ]
}

@test "--check fails on an empty or missing manifest" {
    mkrepo
    install_hooks >/dev/null
    cp "$DEST/.manifest" "$BATS_TEST_TMPDIR/manifest.bak"
    : >"$DEST/.manifest"
    run install_hooks --check
    [ "$status" -eq 1 ]
    printf 'garbage line\n' >"$DEST/.manifest"
    run install_hooks --check
    [ "$status" -eq 1 ]
    rm "$DEST/.manifest"
    run install_hooks --check
    [ "$status" -eq 1 ]
}

@test "--check fails on a manifest name-set mismatch" {
    mkrepo
    install_hooks >/dev/null
    grep -v '^post-merge ' "$DEST/.manifest" >"$BATS_TEST_TMPDIR/m"
    cp "$BATS_TEST_TMPDIR/m" "$DEST/.manifest"
    run install_hooks --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"post-merge"* ]]
}

@test "--check fails on an edited copy, a missing copy and a missing exec bit" {
    mkrepo
    install_hooks >/dev/null
    chmod -x "$DEST/pre-push"
    run install_hooks --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"pre-push"* ]]
    chmod +x "$DEST/pre-push"
    echo '# edit' >>"$DEST/commit-msg"
    run install_hooks --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"commit-msg"* ]]
    install_hooks >/dev/null
    rm "$DEST/post-merge"
    run install_hooks --check
    [ "$status" -eq 1 ]
}

@test "--check fails after HEAD moved a dispatcher blob, and says to re-run the installer" {
    mkrepo
    install_hooks >/dev/null
    echo '# newer' >>"$R/ops/githooks/post-merge"
    git -C "$R" add ops/githooks/post-merge
    git -C "$R" commit -q -m "chore: newer dispatcher"
    run install_hooks --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"re-run the installer"* ]]
    run install_hooks
    [ "$status" -eq 0 ]
    run install_hooks --check
    [ "$status" -eq 0 ]
}

@test "--check fails when dest is deleted" {
    mkrepo
    install_hooks >/dev/null
    rm -rf "$DEST"
    run install_hooks --check
    [ "$status" -eq 1 ]
}

@test "--check warns about stale marker hooks but still passes" {
    mkrepo
    install_hooks >/dev/null
    mkdir -p "$COMMON/hooks"
    printf '#!/bin/sh\n# call_lefthook\n' >"$COMMON/hooks/pre-commit"
    run install_hooks --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale"* ]]
}

@test "an unknown argument is rejected" {
    mkrepo
    run install_hooks --bogus
    [ "$status" -eq 64 ]
}

# ── doctor and readiness wiring ─────────────────────────────────────────────

@test "doctor warns (and its exit status is unaffected) when the hook check fails" {
    mkrepo
    mkdir -p "$R/ops/lib"
    cp "$REPO_ROOT/ops/doctor.sh" "$R/ops/"
    install_hooks >/dev/null
    run --separate-stderr bash "$R/ops/doctor.sh"
    good_status="$status"
    [[ "$output" == *"[OK] git hooks installed and intact"* ]]
    rm -rf "$DEST"
    run --separate-stderr bash "$R/ops/doctor.sh"
    [ "$status" -eq "$good_status" ]
    [[ "$output" == *"[WARN] git hooks not intact (run: bash ops/install-git-hooks.sh"* ]]
    [[ "$stderr" != *"[ERROR] git hooks"* ]]
}

@test "readiness reports [MISS] when the hook check fails (dest deleted)" {
    mkrepo
    cp "$REPO_ROOT/ops/readiness.sh" "$REPO_ROOT/ops/detect-host.sh" "$R/ops/"
    install_hooks >/dev/null
    rm -rf "$DEST"
    run env HOST_PROFILE=linux-cli bash "$R/ops/readiness.sh"
    [[ "$output" == *"[MISS] git hooks"* ]]
    install_hooks >/dev/null
    run env HOST_PROFILE=linux-cli bash "$R/ops/readiness.sh"
    [[ "$output" == *"[OK]   git hooks"* ]]
}

# ── uninstall ───────────────────────────────────────────────────────────────

@test "uninstall --apply unsets hooksPath, deletes dest and marker hooks, and never runs lefthook uninstall" {
    mkrepo
    mkdir -p "$R/ops/lib"
    cp "$REPO_ROOT/ops/uninstall.sh" "$R/ops/"
    cp "$REPO_ROOT"/ops/lib/preflight.sh "$R/ops/lib/"
    install_hooks >/dev/null
    printf '#!/bin/sh\n# call_lefthook\n' >"$COMMON/hooks/pre-commit"
    printf '#!/bin/sh\necho mine\n' >"$COMMON/hooks/pre-push"
    for t in chezmoi home-manager darwin-rebuild mise; do printf '#!/bin/sh\nexit 0\n' >"$STUBS/$t"; chmod +x "$STUBS/$t"; done
    run bash "$R/ops/uninstall.sh" --apply --yes
    echo "$output"
    [ "$status" -eq 0 ]
    [ -z "$(git -C "$R" config --local --get core.hooksPath || true)" ]
    [ ! -e "$DEST" ]
    [ ! -e "$COMMON/hooks/pre-commit" ]
    [ -e "$COMMON/hooks/pre-push" ]
    if [ -e "$STUB_LOG" ]; then
        run grep -c 'uninstall' "$STUB_LOG"
        [ "$output" = 0 ]
    fi
}

@test "uninstall leaves a foreign hooksPath alone" {
    mkrepo
    mkdir -p "$R/ops/lib"
    cp "$REPO_ROOT/ops/uninstall.sh" "$R/ops/"
    cp "$REPO_ROOT"/ops/lib/preflight.sh "$R/ops/lib/"
    git -C "$R" config --local core.hooksPath /somewhere/else
    for t in chezmoi home-manager darwin-rebuild mise; do printf '#!/bin/sh\nexit 0\n' >"$STUBS/$t"; chmod +x "$STUBS/$t"; done
    run bash "$R/ops/uninstall.sh" --apply --yes
    [ "$status" -eq 0 ]
    [ "$(git -C "$R" config --local core.hooksPath)" = /somewhere/else ]
}
