#!/usr/bin/env bats
# Tests for ops/run-bats.sh, the body of the `mise run test:bash` task.
#
# Run:  bats tests/bash/run-bats.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/ops/run-bats.sh"
    STUB="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB"
    # the outer run's own setting must not leak into these runs
    unset RUN_BATS_JOBS
    export APP_CONFIGS_TEST_SANDBOXED=1
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
    stub bats 'printf "%s\n" "$HOME" "${XDG_CONFIG_HOME:-unset}" "${GIT_CONFIG_GLOBAL:-unset}" "$XDG_RUNTIME_DIR" "$TMUX_TMPDIR" "${TMUX:-none}" "${SSH_AUTH_SOCK:-none}" "${XDG_CACHE_HOME:-unset}"
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
    # set, not empty: GNU parallel would export it empty and Nix would then
    # write its caches into the repository
    [ "${env_lines[7]}" = "${env_lines[0]}/.cache" ]
    # the scratch tree is cleaned up after the run
    ! compgen -G "$BATS_TEST_TMPDIR/run-bats.*"
}

@test "run-bats fails when a test leaves files in the shared HOME" {
    stub bats 'mkdir -p "$HOME/.cache/nix" "$HOME/.cache/fish" "$HOME/.parallel"'
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

@test "run-bats: parallel mode -> every suite listed once, SLOW_FIRST files first, job count from nproc or RUN_BATS_JOBS" {
    stub bats 'echo "bats-stub $*"'
    stub parallel 'echo "GNU parallel 20260822"'
    stub nproc 'echo 6'
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -eq 0 ]
    local -a got slow
    read -r -a got <<<"$output"
    [ "${got[0]}" = bats-stub ]
    [ "${got[1]}" = --jobs ]
    [ "${got[2]}" = 6 ]
    got=("${got[@]:3}")

    # every tests/bash suite appears exactly once, the logging suite is included
    local f
    for f in "$REPO_ROOT"/tests/bash/*.bats; do
        f="tests/bash/${f##*/}"
        [ "$(printf '%s\n' "${got[@]}" | grep -cxF "$f")" -eq 1 ] || { echo "not exactly once: $f"; return 1; }
    done
    [ "$(printf '%s\n' "${got[@]}" | grep -cxF ops/projects/logging/test)" -eq 1 ]
    [ "${#got[@]}" -eq "$(( $(printf '%s\n' "$REPO_ROOT"/tests/bash/*.bats | wc -l) + 1 ))" ]

    # the SLOW_FIRST files, as the script lists them, come first and in order
    read -r -a slow <<<"$(sed -n 's/^ *SLOW_FIRST=(\(.*\))$/\1/p' "$SCRIPT")"
    [ "${#slow[@]}" -ge 4 ]
    local i
    for i in "${!slow[@]}"; do
        [ "${got[$i]}" = "tests/bash/${slow[$i]}.bats" ] || { echo "position $i: ${got[$i]}"; return 1; }
    done
    [[ " ${slow[*]} " == *" selection-diff "* ]]

    run env PATH="$STUB" RUN_BATS_JOBS=3 bash "$SCRIPT"
    [[ "$output" == "bats-stub --jobs 3 "* ]]
}

@test "run-bats fails when a SLOW_FIRST file is missing, instead of silently dropping it" {
    stub bats 'echo "bats-stub $*"'
    stub parallel 'echo "GNU parallel 20260822"'
    stub nproc 'echo 6'
    # a copy of the script over a tests/bash without selection.bats
    local root="$BATS_TEST_TMPDIR/root"
    mkdir -p "$root/ops" "$root/tests/bash" "$root/tests/lib"
    cp "$SCRIPT" "$root/ops/run-bats.sh"
    cp "$REPO_ROOT/tests/lib/isolation.sh" "$root/tests/lib/isolation.sh"
    touch "$root/tests/bash/update-all-apply.bats" "$root/tests/bash/install-selection.bats" "$root/tests/bash/other.bats"
    run env PATH="$STUB" bash "$root/ops/run-bats.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"SLOW_FIRST names a missing file: tests/bash/selection.bats"* ]]
    [[ "$output" != *"bats-stub"* ]]
}

@test "run-bats stays sequential without GNU parallel, with RUN_BATS_JOBS=1, or when -j is given" {
    stub bats 'echo "bats-stub $*"'
    stub nproc 'echo 6'
    run env PATH="$STUB" bash "$SCRIPT"
    [[ "$output" == "bats-stub tests/bash ops/projects/logging/test" ]]

    # moreutils' parallel is not GNU parallel and bats cannot drive it
    stub parallel 'echo "parallel: moreutils"'
    run env PATH="$STUB" bash "$SCRIPT"
    [[ "$output" == "bats-stub tests/bash ops/projects/logging/test" ]]

    stub parallel 'echo "GNU parallel 20260822"'
    run env PATH="$STUB" RUN_BATS_JOBS=1 bash "$SCRIPT"
    [[ "$output" == "bats-stub tests/bash ops/projects/logging/test" ]]

    run env PATH="$STUB" bash "$SCRIPT" -j 2
    [[ "$output" == "bats-stub tests/bash ops/projects/logging/test -j 2" ]]
}

@test "run-bats puts a deny guard first on PATH, sets isolated mode, and blocks a real brew" {
    printf '#!/bin/sh\necho REAL-BREW-RAN\n' >"$STUB/brew"
    chmod +x "$STUB/brew"
    stub bats 'echo "mode=$APP_CONFIGS_TEST_MODE"
echo "first=${PATH%%:*}"
brew update
echo "brew-rc=$?"'
    run env PATH="$STUB" bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mode=isolated"* ]]
    [[ "$output" == *"first="*"/run-bats."*"/guard-bin"* ]]
    [[ "$output" == *"[test-guard] blocked real brew update"* ]]
    [[ "$output" == *"brew-rc=97"* ]]
    [[ "$output" != *"REAL-BREW-RAN"* ]]
}

@test "run-bats fails when the host fingerprint changes during the run" {
    stub bats 'mkdir -p "$ISOLATION_TEST_PREFIX/Cellar/tool/2.0"'
    mkdir -p "$BATS_TEST_TMPDIR/prefix/Cellar/tool/1.0" "$BATS_TEST_TMPDIR/prefix/bin"
    for t in find shasum cut sort git ls; do ln -sf "$(command -v "$t")" "$STUB/$t"; done
    run env PATH="$STUB" ISOLATION_BREW_PREFIX="$BATS_TEST_TMPDIR/prefix" ISOLATION_TEST_PREFIX="$BATS_TEST_TMPDIR/prefix" bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"the host changed during the run"* ]]
}

@test "run-bats says so when tests/lib/isolation.sh is missing" {
    stub bats 'echo "bats-stub $*"'
    local root="$BATS_TEST_TMPDIR/root-no-lib"
    mkdir -p "$root/ops" "$root/tests/bash"
    cp "$SCRIPT" "$root/ops/run-bats.sh"
    run env PATH="$STUB" bash "$root/ops/run-bats.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"tests/lib/isolation.sh is missing"* ]]
    [[ "$output" != *"bats-stub"* ]]
}
