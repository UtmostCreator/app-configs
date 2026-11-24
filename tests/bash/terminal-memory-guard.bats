#!/usr/bin/env bats
# macOS terminal memory guard: the same percentage limits as the Linux systemd
# caps (tab soft 40% / hard 50%, all tabs soft 60% / hard 70% of RAM).
# Uses a ps fixture, so it never reads or signals real processes.
#
# Run:  bats tests/bash/terminal-memory-guard.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    GUARD="$REPO_ROOT/home/dot_local/bin/executable_terminal-memory-guard"
    BASH_BIN=/bin/bash
    [ -x "$BASH_BIN" ] || BASH_BIN="$(command -v bash)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    export MEMORY_GUARD_MEMSIZE=$((10 * 1024 * 1024 * 1024)) # 10 GiB: 10240 MiB
    export MEMORY_GUARD_NOTIFY=0
    export MEMORY_GUARD_PS_FILE="$BATS_TEST_TMPDIR/ps.txt"
    cat >"$BATS_TEST_TMPDIR/kill" <<'K'
#!/bin/sh
echo "$@" >>"$KILL_LOG"
K
    chmod +x "$BATS_TEST_TMPDIR/kill"
    export MEMORY_GUARD_KILL="$BATS_TEST_TMPDIR/kill"
    export KILL_LOG="$BATS_TEST_TMPDIR/kill.log"
    : >"$KILL_LOG"
}

# fixture <tab1 hog MiB> <tab2 hog MiB>: one Ghostty, two tabs, a hog in each
fixture() {
    cat >"$MEMORY_GUARD_PS_FILE" <<PS
  100     1   50000 Mon Jan  1 00:00:00 2024 /Applications/Ghostty.app/Contents/MacOS/ghostty
  200   100    4000 Mon Jan  1 00:00:01 2024 /usr/bin/login
  201   200     800 Mon Jan  1 00:00:02 2024 -/bin/zsh
  202   201 $(($1 * 1024)) Mon Jan  1 00:00:03 2024 /opt/homebrew/bin/node
  300   100    4000 Mon Jan  1 00:00:04 2024 /usr/bin/login
  301   300     800 Mon Jan  1 00:00:05 2024 -/bin/zsh
  302   301 $(($2 * 1024)) Mon Jan  1 00:00:06 2024 /usr/bin/python3
  900     1 9999999 Mon Jan  1 00:00:07 2024 /Applications/Other.app/Contents/MacOS/other
PS
}

@test "guard help works and unknown options are rejected" {
    run "$BASH_BIN" "$GUARD" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    run "$BASH_BIN" "$GUARD" --apply
    [ "$status" -eq 64 ]
}

@test "guard states the Linux percentages: tab 40/50, group 60/70" {
    fixture 100 100
    run "$BASH_BIN" "$GUARD"
    [ "$status" -eq 0 ]
    [[ "$output" == *"(40%/50%)"* && "$output" == *"(60%/70%)"* ]]
    [[ "$output" == *"tab soft/hard=4096/5120 MiB"* ]]
    [[ "$output" == *"group soft/hard=6144/7168 MiB"* ]]
}

@test "under the limits: no signal" {
    fixture 1000 1000
    run "$BASH_BIN" "$GUARD" --enforce
    [ "$status" -eq 0 ]
    [[ "$output" != *SOFT* && "$output" != *HARD* ]]
    [ ! -s "$KILL_LOG" ]
}

@test "tab over soft only: reports SOFT, sends no signal" {
    fixture 4200 100
    run "$BASH_BIN" "$GUARD" --enforce
    [[ "$output" == *"SOFT tab 200"* ]]
    [[ "$output" != *HARD* ]]
    [ ! -s "$KILL_LOG" ]
}

@test "tab over hard: --check only reports, --enforce signals the hog, not the shell" {
    fixture 5300 100
    run "$BASH_BIN" "$GUARD" --check
    [[ "$output" == *"HARD tab 200: would SIGTERM pid 202"* ]]
    [ ! -s "$KILL_LOG" ]
    run "$BASH_BIN" "$GUARD" --enforce
    [[ "$output" == *"HARD tab 200: SIGTERM pid 202"* ]]
    [ "$(cat "$KILL_LOG")" = "-TERM 202" ]
}

@test "group over hard with each tab under its own hard limit: stops the largest process" {
    fixture 3900 3600 # 7500 MiB plus overhead > 7168, each tab < 5120
    run "$BASH_BIN" "$GUARD" --enforce
    [[ "$output" == *"HARD all tabs: SIGTERM pid 202"* ]]
    [ "$(cat "$KILL_LOG")" = "-TERM 202" ]
}

@test "overlapping tab and group hard limits signal the same victim only once" {
    fixture 6000 2000
    run "$BASH_BIN" "$GUARD" --enforce
    [ "$status" -eq 0 ]
    [ "$(cat "$KILL_LOG")" = "-TERM 202" ]
}

@test "group limit signals a different victim after a tab limit" {
    fixture 3000 4000
    printf '  203   201 %d Mon Jan  1 00:00:08 2024 /opt/homebrew/bin/other\n' "$((2300 * 1024))" >>"$MEMORY_GUARD_PS_FILE"
    run "$BASH_BIN" "$GUARD" --enforce
    [ "$status" -eq 0 ]
    [ "$(cat "$KILL_LOG")" = "$(printf '%s\n' '-TERM 202' '-TERM 302')" ]
}

@test "failed tab signal is not repeated for the group in the same cycle" {
    fixture 6000 2000
    printf '#!/bin/sh\necho "$@" >>"$KILL_LOG"\nexit 1\n' >"$MEMORY_GUARD_KILL"
    run "$BASH_BIN" "$GUARD" --enforce
    [ "$status" -eq 0 ]
    [[ "$output" == *"could not signal pid 202"* ]]
    [ "$(cat "$KILL_LOG")" = "-TERM 202" ]
}

@test "changed process identity or ancestry is not signalled" {
    fixture 5300 100
    export MEMORY_GUARD_VERIFY_PS_FILE="$BATS_TEST_TMPDIR/fresh-ps.txt"
    sed 's/00:00:03 2024/00:00:09 2024/' "$MEMORY_GUARD_PS_FILE" >"$MEMORY_GUARD_VERIFY_PS_FILE"
    run "$BASH_BIN" "$GUARD" --enforce
    [ "$status" -eq 0 ]
    [[ "$output" == *"pid 202 changed or left Ghostty; skipped"* ]]
    [ ! -s "$KILL_LOG" ]
    sed 's/201   200/201   900/' "$MEMORY_GUARD_PS_FILE" >"$MEMORY_GUARD_VERIFY_PS_FILE"
    run "$BASH_BIN" "$GUARD" --enforce
    [ "$status" -eq 0 ]
    [[ "$output" == *"pid 202 changed or left Ghostty; skipped"* ]]
    [ ! -s "$KILL_LOG" ]
}

@test "processes outside Ghostty are never counted or signalled" {
    fixture 100 100 # pid 900 holds ~9.5 GiB but is not below Ghostty
    run "$BASH_BIN" "$GUARD" --enforce
    [ ! -s "$KILL_LOG" ]
}

@test "guard refuses non-macOS hosts without a fixture" {
    unset MEMORY_GUARD_PS_FILE
    [[ "$(uname -s)" != Darwin ]] || skip "macOS host"
    run "$BASH_BIN" "$GUARD"
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires macOS"* ]]
}

@test "launch agent runs --enforce on an interval and Linux ignores the script" {
    plist="$REPO_ROOT/home/Library/LaunchAgents/com.local.terminal-memory-guard.plist.tmpl"
    grep -q -- '--enforce' "$plist"
    grep -q '<key>StartInterval</key>' "$plist"
    grep -qx '.local/bin/terminal-memory-guard' "$REPO_ROOT/home/.chezmoiignore"
}
