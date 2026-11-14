#!/usr/bin/env bats
# dsh-remote-setup must not mutate tailscale/systemd on --help, a typo or a
# non-Linux host. All external tools are PATH stubs that log their calls.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="${DSH_SETUP_SCRIPT:-$REPO_ROOT/home/dot_local/bin/executable_dsh-remote-setup}"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    CALLS="$BATS_TEST_TMPDIR/calls"; : >"$CALLS"
    for t in tailscale systemctl ss journalctl jq; do
        printf '#!/bin/sh\necho "%s $*" >>"%s"\nexit 1\n' "$t" "$CALLS" >"$STUBS/$t"
        chmod +x "$STUBS/$t"
    done
    printf '#!/bin/sh\necho "${FAKE_UNAME:-Linux}"\n' >"$STUBS/uname"; chmod +x "$STUBS/uname"
}

@test "--help prints usage and calls nothing" {
    run env PATH="$STUBS:$PATH" bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [ ! -s "$CALLS" ]
}

@test "unknown arguments exit 2 and call nothing" {
    run env PATH="$STUBS:$PATH" bash "$SCRIPT" --dry-run
    [ "$status" -eq 2 ]
    [ ! -s "$CALLS" ]
}

@test "on macOS it refuses before any tailscale or systemctl call" {
    run env PATH="$STUBS:$PATH" FAKE_UNAME=Darwin bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Linux only"* ]]
    [ ! -s "$CALLS" ]
}

@test "the script is chezmoi-ignored on darwin only" {
    : >"$BATS_TEST_TMPDIR/c.toml"; mkdir -p "$BATS_TEST_TMPDIR/source"
    local os data
    for os in darwin linux; do
        data=$(printf '{"name":"T","email":"t@example.com","signingKey":"","hostProfile":"","gui":false,"chezmoi":{"os":"%s"}}' "$os")
        run chezmoi execute-template --config "$BATS_TEST_TMPDIR/c.toml" \
            --source "$BATS_TEST_TMPDIR/source" --override-data "$data" <"$REPO_ROOT/home/.chezmoiignore"
        [ "$status" -eq 0 ]
        if [ "$os" = darwin ]; then
            grep -qxF ".local/bin/dsh-remote-setup" <<<"$output"
        else
            run grep -cxF ".local/bin/dsh-remote-setup" <<<"$output"
            [ "$output" = "0" ]
        fi
    done
}
