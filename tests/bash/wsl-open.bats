#!/usr/bin/env bats
# home/dot_local/bin/executable_wsl-open: open URLs and paths with Windows
# from WSL2 (stands in for macOS `open` and the removed wslu `wslview`).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_wsl-open"
    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    LOG="$BATS_TEST_TMPDIR/log"
    for t in sh bash; do ln -s "$(command -v "$t")" "$STUBS/$t"; done
    # explorer.exe really exits 1 even when it succeeded.
    printf '#!/bin/sh\necho "explorer:$1" >>"%s"\nexit 1\n' "$LOG" >"$STUBS/explorer.exe"
    printf '#!/bin/sh\n[ "$1" = -w ] && echo "C:\\\\win\\\\${2##*/}"\n' >"$STUBS/wslpath"
    chmod +x "$STUBS/explorer.exe" "$STUBS/wslpath"
}

open_() { PATH="$STUBS" run "$STUBS/bash" "$SCRIPT" "$@"; }

@test "URL goes to explorer.exe unchanged and succeeds" {
    open_ "https://github.com/login/device"
    [ "$status" -eq 0 ]
    [ "$(cat "$LOG")" = "explorer:https://github.com/login/device" ]
}

@test "existing path is converted with wslpath -w" {
    mkdir -p "$BATS_TEST_TMPDIR/proj"
    open_ "$BATS_TEST_TMPDIR/proj"
    [ "$status" -eq 0 ]
    [ "$(cat "$LOG")" = 'explorer:C:\win\proj' ]
}

@test "no argument opens the current directory" {
    cd "$BATS_TEST_TMPDIR"
    open_
    [ "$status" -eq 0 ]
    [[ "$(cat "$LOG")" == 'explorer:C:\win\'* ]]
}

@test "missing path fails without calling explorer" {
    open_ "$BATS_TEST_TMPDIR/nope"
    [ "$status" -ne 0 ]
    [ ! -e "$LOG" ]
}

@test "without Windows interop it fails with a message" {
    rm "$STUBS/explorer.exe"
    open_ "https://example.com"
    [ "$status" -ne 0 ]
    [[ "$output" == *"explorer.exe"* ]]
}

@test "fish sets BROWSER and open only on WSL2" {
    # fish ships its own `open` on Linux; check that ours replaces it on WSL2.
    : >"$BATS_TEST_TMPDIR/c.toml"
    f="$BATS_TEST_TMPDIR/config.fish"
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/c.toml" --source "$REPO_ROOT/home" \
        --override-data '{"chezmoi":{"os":"linux"},"name":"T","email":"t@e.t","signingKey":""}' \
        --file "$REPO_ROOT/home/dot_config/fish/config.fish.tmpl" >"$f"
    sed -n '/^# ─── WSL2/,/^end/p' "$f" >"$BATS_TEST_TMPDIR/wsl.fish"
    run env WSL_DISTRO_NAME=Ubuntu fish --no-config -c "source $BATS_TEST_TMPDIR/wsl.fish; echo \$BROWSER; functions open | string match -q '*wsl-open*'; and echo open-ok"
    [ "${lines[0]}" = "wsl-open" ]
    [ "${lines[1]}" = "open-ok" ]
    run env -u WSL_DISTRO_NAME -u WSL_INTEROP fish --no-config -c "source $BATS_TEST_TMPDIR/wsl.fish; echo \"[\$BROWSER]\"; functions open 2>/dev/null | string match -q '*wsl-open*'; or echo no-open"
    [ "${lines[0]}" = "[]" ]
    [ "${lines[1]}" = "no-open" ]
}
