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

# Autostart is opt-in: only --autostart may call `systemctl --user enable`.
ok_stubs() {
    local t
    for t in tailscale systemctl journalctl jq; do
        {
            printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$t" "$CALLS"
            case "$t" in
                systemctl) printf '%s\n' \
                    '[ "$2" = is-active ] && exit "${FAKE_ACTIVE:-1}"' \
                    '[ "$2" = is-enabled ] && { echo "${FAKE_ENABLED:-disabled}"; [ "${FAKE_ENABLED:-disabled}" = enabled ]; exit; }' ;;
                jq) printf 'echo host.example.ts.net\n' ;;
            esac
            printf 'exit 0\n'
        } >"$STUBS/$t"
        chmod +x "$STUBS/$t"
    done
    printf '#!/bin/sh\n[ -n "${FAKE_PORT_OWNED:-}" ] && { echo LISTEN; exit 0; }\nexit 1\n' >"$STUBS/ss"; chmod +x "$STUBS/ss"
}

@test "default run starts for this session and never enables autostart" {
    ok_stubs
    run env PATH="$STUBS:$PATH" bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -qxF "systemctl --user start dsh-remote.service" "$CALLS"
    [[ "$output" == *"--autostart"* ]]
    run grep -c "systemctl.* enable" "$CALLS"; [ "$output" = 0 ]
}

@test "--autostart runs enable --now" {
    ok_stubs
    run env PATH="$STUBS:$PATH" bash "$SCRIPT" --autostart
    [ "$status" -eq 0 ]
    grep -qxF "systemctl --user enable --now dsh-remote.service" "$CALLS"
}

@test "--help documents --autostart and calls nothing" {
    run env PATH="$STUBS:$PATH" bash "$SCRIPT" --help
    [[ "$output" == *"--autostart"* ]]
    [ ! -s "$CALLS" ]
}

@test "status reports autostart and active state with the commands" {
    ok_stubs
    run env PATH="$STUBS:$PATH" bash "$REPO_ROOT/home/dot_local/bin/executable_dsh-remote-status"
    [[ "$output" == *"Autostart at login: disabled"* ]]
    [[ "$output" == *"Active now:"* ]]
    [[ "$output" == *"systemctl --user start dsh-remote.service"* ]]
    [[ "$output" == *"dsh-remote-setup --autostart"* ]]
    run grep -c "systemctl.* enable" "$CALLS"; [ "$output" = 0 ]
}

@test "status shows autostart enabled" {
    ok_stubs
    run env PATH="$STUBS:$PATH" FAKE_ENABLED=enabled bash "$REPO_ROOT/home/dot_local/bin/executable_dsh-remote-status"
    [[ "$output" == *"Autostart at login: enabled"* ]]
    [[ "$output" == *"systemctl --user disable --now dsh-remote.service"* ]]
}

# already-active and port-owned branches: enable only with --autostart, once.
@test "already active or port-owned: no enable by default, one enable with --autostart" {
    local mode
    for mode in "FAKE_ACTIVE=0" "FAKE_PORT_OWNED=1"; do
        ok_stubs
        : >"$CALLS"
        run env PATH="$STUBS:$PATH" "$mode" bash "$SCRIPT"
        [ "$status" -eq 0 ]
        run grep -c "systemctl.* enable" "$CALLS"; [ "$output" = 0 ]
        : >"$CALLS"
        run env PATH="$STUBS:$PATH" "$mode" bash "$SCRIPT" --autostart
        [ "$status" -eq 0 ]
        run grep -c "systemctl.* enable" "$CALLS"; [ "$output" = 1 ]
    done
}

@test "final autostart line reports the real is-enabled state" {
    ok_stubs
    run env PATH="$STUBS:$PATH" FAKE_ENABLED=enabled bash "$SCRIPT"
    [[ "$output" == *"Autostart at login: enabled"* ]]
    [[ "$output" == *"systemctl --user disable dsh-remote.service"* ]]
    run env PATH="$STUBS:$PATH" bash "$SCRIPT"
    [[ "$output" == *"Autostart at login: off"* ]]
}

@test "status offers stop when active" {
    ok_stubs
    run env PATH="$STUBS:$PATH" FAKE_ACTIVE=0 bash "$REPO_ROOT/home/dot_local/bin/executable_dsh-remote-status"
    [[ "$output" == *"Stop:               systemctl --user stop dsh-remote.service"* ]]
}
