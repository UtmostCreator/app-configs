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
