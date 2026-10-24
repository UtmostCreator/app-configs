#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEMPLATE="$REPO_ROOT/home/dot_gitconfig.tmpl"
    SOURCE="$BATS_TEST_TMPDIR/source"
    RENDERED="$BATS_TEST_TMPDIR/gitconfig"

    command -v chezmoi >/dev/null
    [ -f "$TEMPLATE" ]
    mkdir -p "$SOURCE"
    cp "$TEMPLATE" "$SOURCE/dot_gitconfig.tmpl"
}

render_gitconfig() {
    local data="$1"

    chezmoi execute-template \
        --source "$SOURCE" \
        --override-data "$data" \
        --file "$SOURCE/dot_gitconfig.tmpl" >"$RENDERED"
}

@test "useGitDelta=false omits all delta configuration" {
    render_gitconfig '{"name":"Test User","email":"test@example.test","signingKey":"","useGitDelta":false}'

    run git config --file "$RENDERED" --get-regexp '^(core\.pager|interactive\.diffFilter|delta\.)'
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "useGitDelta=true enables delta configuration" {
    render_gitconfig '{"name":"Test User","email":"test@example.test","signingKey":"","useGitDelta":true}'

    run git config --file "$RENDERED" --get core.pager
    [ "$status" -eq 0 ]
    [ "$output" = "delta" ]

    run git config --file "$RENDERED" --get interactive.diffFilter
    [ "$status" -eq 0 ]
    [ "$output" = "delta --color-only" ]
}

@test "missing useGitDelta keeps the documented default" {
    render_gitconfig '{"name":"Test User","email":"test@example.test","signingKey":""}'

    run git config --file "$RENDERED" --get core.pager
    [ "$status" -eq 0 ]
    [ "$output" = "delta" ]
}

@test "example placeholders do not become Git identity" {
    render_gitconfig '{"name":"Your Full Name","email":"you@example.com","signingKey":"","useGitDelta":false}'

    run git config --file "$RENDERED" --get user.name
    [ "$status" -eq 1 ]

    run git config --file "$RENDERED" --get user.email
    [ "$status" -eq 1 ]
}

@test "configured identity is rendered" {
    render_gitconfig '{"name":"Test User","email":"test@example.test","signingKey":"","useGitDelta":false}'

    run git config --file "$RENDERED" --get user.name
    [ "$status" -eq 0 ]
    [ "$output" = "Test User" ]

    run git config --file "$RENDERED" --get user.email
    [ "$status" -eq 0 ]
    [ "$output" = "test@example.test" ]
}

@test "no plaintext credential store is configured" {
    render_gitconfig '{"name":"Test User","email":"test@example.test","signingKey":""}'
    ! grep -Eq '^[[:space:]]*helper[[:space:]]*=[[:space:]]*store' "$RENDERED"
}

@test "brgone previews gone upstreams without deleting branches or unique commits" {
    render_gitconfig '{"name":"Test User","email":"test@example.test","signingKey":"","useGitDelta":false}'
    local repo="$BATS_TEST_TMPDIR/repo"
    git init -q -b main "$repo"
    git -C "$repo" config user.name "Test User"
    git -C "$repo" config user.email "test@example.test"
    git -C "$repo" -c commit.gpgsign=false commit -q --allow-empty -m initial
    git -C "$repo" switch -q -c retired
    git -C "$repo" -c commit.gpgsign=false commit -q --allow-empty -m unique
    git -C "$repo" switch -q main
    # A missing remote path also ensures preview does not need a fetch.
    git -C "$repo" remote add origin "$BATS_TEST_TMPDIR/missing-remote"
    git -C "$repo" config branch.retired.remote origin
    git -C "$repo" config branch.retired.merge refs/heads/retired
    git -C "$repo" config branch.main.remote origin
    git -C "$repo" config branch.main.merge refs/heads/main
    local before
    before="$(git -C "$repo" show-ref)"

    run git -C "$repo" -c "include.path=$RENDERED" brgone
    [ "$status" -eq 0 ]
    [[ "$output" == *"[origin/retired: gone]"* ]]
    [[ "$output" == *"[origin/main: gone]"* ]]
    [ "$(git -C "$repo" show-ref)" = "$before" ]
}

@test "brgone succeeds with no gone upstreams" {
    render_gitconfig '{"name":"Test User","email":"test@example.test","signingKey":"","useGitDelta":false}'
    local repo="$BATS_TEST_TMPDIR/repo"
    git init -q -b main "$repo"

    run git -C "$repo" -c "include.path=$RENDERED" brgone
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
