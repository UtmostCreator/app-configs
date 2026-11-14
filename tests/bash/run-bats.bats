#!/usr/bin/env bats
# Tests for ops/run-bats.sh, the body of the `mise run test:bash` task.
#
# Run:  bats tests/bash/run-bats.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/run-bats.sh"
    STUB="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB"
    local t
    for t in bash env dirname mktemp mkdir chmod rm; do
        ln -sf "$(command -v "$t")" "$STUB/$t"
    done
}

# stub <name> <body>: a fake command on the stub PATH.
stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$STUB/$1"
    chmod +x "$STUB/$1"
}

@test "mise test:bash task delegates to ops/run-bats.sh" {
    run grep -A4 '^\[tasks."test:bash"\]' "$REPO_ROOT/mise.toml"
    [[ "$output" == *"bash ops/run-bats.sh"* ]]
}

@test "run-bats fails with an install hint when bats is missing" {
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"bats not found"* ]]
    [[ "$output" == *"sys-update"* ]]
}

@test "run-bats runs bats on tests/bash and propagates its status" {
    stub bats 'echo "bats-stub $*"; exit 3'
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -eq 3 ]
    [[ "$output" == *"bats-stub tests/bash"* ]]
}

@test "run-bats also runs the logging suites under ops/projects/logging/test" {
    stub bats 'echo "bats-stub $*"'
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"bats-stub tests/bash ops/projects/logging/test"* ]]
}

@test "run-bats gives the suite a scratch HOME and git identity, then removes them" {
    stub bats 'printf "%s\n" "$HOME" "${XDG_CONFIG_HOME:-unset}" "${GIT_CONFIG_GLOBAL:-unset}" "$XDG_RUNTIME_DIR" "$TMUX_TMPDIR" "${TMUX:-none}" "${SSH_AUTH_SOCK:-none}"
[[ -d "$XDG_RUNTIME_DIR" && -d "$TMUX_TMPDIR" ]] || exit 9
grep -q "email = bats@example.invalid" "$HOME/.gitconfig" || exit 8'
    ln -sf "$(command -v grep)" "$STUB/grep"
    run env PATH="$STUB" HOME=/real/home XDG_CONFIG_HOME=/real/home/.config \
        GIT_CONFIG_GLOBAL=/real/home/.gitconfig TMUX=/tmp/real,1,0 SSH_AUTH_SOCK=/tmp/agent \
        TMPDIR="$BATS_TEST_TMPDIR" bash "$SCRIPT"
    [ "$status" -eq 0 ]
    mapfile -t env_lines <<<"$output"
    [[ "${env_lines[0]}" == "$BATS_TEST_TMPDIR"/run-bats.*/home ]]
    # XDG dirs and git config follow HOME, including a HOME a test sets itself
    [ "${env_lines[1]}" = unset ]
    [ "${env_lines[2]}" = unset ]
    [[ "${env_lines[3]}" == "$BATS_TEST_TMPDIR"/run-bats.*/runtime ]]
    [[ "${env_lines[4]}" == "$BATS_TEST_TMPDIR"/run-bats.*/tmux ]]
    [ "${env_lines[5]}" = none ]
    [ "${env_lines[6]}" = none ]
    # the scratch tree is cleaned up after the run
    ! compgen -G "$BATS_TEST_TMPDIR/run-bats.*"
}

@test "run-bats fails when a test leaves files in the shared HOME" {
    stub bats 'mkdir -p "$HOME/.cache/nix" "$HOME/.cache/fish"'
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -eq 0 ]

    stub bats 'mkdir -p "$HOME/.config/fish" "$HOME/.local/state"'
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"wrote outside their temp dirs"* ]]
    [[ "$output" == *"~/.config"* ]]
    [[ "$output" == *"~/.local"* ]]

    # a failing suite keeps its own exit status
    stub bats 'mkdir -p "$HOME/.config"; exit 4'
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -eq 4 ]
}
