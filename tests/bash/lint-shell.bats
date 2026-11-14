#!/usr/bin/env bats
# ops/lint-shell.sh, the body of `mise run lint:shell`.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/lint-shell.sh"
    R="$BATS_TEST_TMPDIR/repo"; mkdir -p "$R/ops" "$R/home/dot_local/bin"
    cp "$SCRIPT" "$R/ops/lint-shell.sh"
    git -C "$R" init -q
    printf '#!/usr/bin/env bash\ntrue\n' >"$R/ops/good.sh"
    printf '#!/bin/sh\necho ok\n' >"$R/home/dot_local/bin/executable_tool"
    printf '#!/usr/bin/env python3\nprint(1)\n' >"$R/home/dot_local/bin/executable_py"
    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    printf '#!/bin/sh\necho "shellcheck $*" >>"%s"\n' "$BATS_TEST_TMPDIR/sc.log" >"$STUBS/shellcheck"
    chmod +x "$STUBS/shellcheck"
}

lint() { git -C "$R" add -A; PATH="$STUBS:$PATH" run bash "$R/ops/lint-shell.sh"; }

@test "a syntax error in ANY file fails, not just the first (bash -n a b only parses a)" {
    printf 'if then\n' >"$R/ops/z-broken.sh"
    lint
    [ "$status" -ne 0 ]
    [[ "$output" == *"ops/z-broken.sh"* ]]
}

@test "every broken file is reported, not only the first" {
    printf 'if then\n' >"$R/ops/a-broken.sh"
    printf 'case x in\n' >"$R/ops/b-broken.sh"
    lint
    [ "$status" -ne 0 ]
    [[ "$output" == *"ops/a-broken.sh"* && "$output" == *"ops/b-broken.sh"* ]]
}

@test "clean scripts pass and non-shell executables are skipped" {
    lint
    [ "$status" -eq 0 ]
    # good.sh, the copied lint-shell.sh, and the sh-shebang helper; not the .py one
    [[ "$output" == *"bash -n: 3 files"* ]]
}

@test "untracked files are not linted (only what is committed matters)" {
    printf 'if then\n' >"$R/ops/scratch.sh"
    git -C "$R" add ops/good.sh home   # scratch.sh stays untracked
    PATH="$STUBS:$PATH" run bash "$R/ops/lint-shell.sh"
    [ "$status" -eq 0 ]
}

@test "missing shellcheck fails instead of reporting success" {
    git -C "$R" add -A
    # A PATH with only what the script needs, so no shellcheck can be found.
    only="$BATS_TEST_TMPDIR/only"; mkdir -p "$only"
    for t in bash git head grep dirname; do ln -s "$(command -v "$t")" "$only/$t"; done
    run env PATH="$only" bash "$R/ops/lint-shell.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"shellcheck not found"* ]]
}

@test "mise lint:shell delegates to ops/lint-shell.sh" {
    run grep -A3 '^\[tasks."lint:shell"\]' "$REPO_ROOT/mise.toml"
    [[ "$output" == *"bash ops/lint-shell.sh"* ]]
}
