#!/usr/bin/env bats
# Tests for home/dot_claude/executable_statusline.sh — the Claude Code status line.
#
# Deterministic: each test builds a throwaway git repo under BATS_TEST_TMPDIR,
# pipes canned statusLine JSON into the script, and pins the clock
# (STATUSLINE_NOW), timezone, and terminal width. Global git config is ignored.
#
# Run:  bats tests/bash/claude-statusline.bats

# 2025-02-01 14:26:40 UTC, a Saturday.
NOW=1738420000

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/home/dot_claude/executable_statusline.sh"
    [ -f "$SCRIPT" ]

    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    export STATUSLINE_NOW=$NOW TZ=UTC COLUMNS=200
    # No git-result caching by default (tests edit the tree between runs); the
    # cache tests turn it on. The cache dir stays inside the test sandbox.
    export STATUSLINE_GIT_TTL=0 XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
    mkdir -p "$XDG_RUNTIME_DIR"
    # Isolate from the real ~/.claude/sessions (Remote Control lookup).
    export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude"
    mkdir -p "$CLAUDE_CONFIG_DIR/sessions"
    WORK="$BATS_TEST_TMPDIR"
    REPO="$WORK/advanced-gym"
    make_repo "$REPO" main
}

# make_repo <dir> <branch>: a repo with one commit on <branch>.
make_repo() {
    git init -q -b "$2" "$1"
    git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}

# edit_tracked: commit a ten-line file, then change it so `git diff HEAD`
# reports +3/-2 (two lines replaced, one appended).
edit_tracked() {
    seq 1 10 >"$REPO/f.txt"
    git -C "$REPO" add f.txt
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m f
    { echo a; echo b; seq 3 10; echo c; } >"$REPO/f.txt"
}

# payload [override-json]: a 548k-token 1M-context Opus session in $REPO,
# deep-merged with the override.
payload() {
    local override=${1:-'{}'}
    jq -n --arg d "$REPO" --argjson o "$override" '{
        cwd: $d,
        model: {id: "claude-opus-5[1m]", display_name: "Opus 5 (1M context)"},
        workspace: {project_dir: $d, current_dir: $d},
        context_window: {total_input_tokens: 548000, context_window_size: 1000000,
                         used_percentage: 54.8},
        exceeds_200k_tokens: true
    } * $o'
}

# statusline [override-json]: run the script, ANSI colors stripped.
statusline() {
    payload "${1:-}" | bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g'
}

FULL='{
    "effort": {"level": "high"},
    "cost": {"total_lines_added": 428, "total_lines_removed": 91},
    "rate_limits": {
        "five_hour": {"used_percentage": 72.4, "resets_at": 1738425040},
        "seven_day": {"used_percentage": 41.2, "resets_at": 1738679200}
    }
}'
EXTRAS='{
    "worktree": {"name": "ui-redesign"},
    "pr": {"number": 184, "review_state": "approved"}
}'

# session_file <pid> <session-id> [bridge-session-id] [updated-at]: the state
# file Claude Code keeps per running session; bridgeSessionId is set while the
# session is connected to Remote Control.
session_file() {
    jq -n --argjson pid "$1" --arg id "$2" --arg bridge "${3:-}" --argjson at "${4:-1}" \
        '{pid: $pid, sessionId: $id, kind: "interactive", status: "idle", updatedAt: $at}
         + (if $bridge == "" then {} else {bridgeSessionId: $bridge} end)' \
        >"$CLAUDE_CONFIG_DIR/sessions/$1.json"
}

# --- Main line ----------------------------------------------------------------

@test "wide: dirty branch, diff, effort, real context %, LONG, 5h and 7d quota" {
    edit_tracked
    run statusline "$FULL"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "$output" = "advanced-gym ⎇ main* +3/-2 | Opus 5 · effort:high | Ctx 55% · 548k/1M · LONG | 5h 72% ↻1h24m · 7d 41% ↻Tue" ]
}

@test "clean tree has no dirty marker and no diff segment when nothing changed" {
    run statusline '{"cost": {"total_lines_added": 0, "total_lines_removed": 0}}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main | Opus 5 | "* ]]
}

@test "diff is the live working tree against HEAD, not the session's edit counters" {
    # The session counters claim edits, but the tree is clean: nothing to show.
    run statusline "$FULL"
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main | Opus 5 · effort:high | "* ]]
    # Staged and unstaged changes both count; committing clears the segment.
    edit_tracked
    git -C "$REPO" add f.txt
    echo d >>"$REPO/f.txt"
    run statusline "$FULL"
    [[ "$output" == "advanced-gym ⎇ main* +4/-2 | "* ]]
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -am edit
    run statusline "$FULL"
    [[ "$output" == "advanced-gym ⎇ main | Opus 5"* ]]
}

@test "untracked files mark the tree dirty but add no line counts" {
    touch "$REPO/untracked.txt"
    run statusline "$FULL"
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main* | Opus 5"* ]]
}

@test "binary changes are skipped in the line counts" {
    printf '\0\1' >"$REPO/b.bin"
    git -C "$REPO" add b.bin
    run statusline
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main* | Opus 5"* ]]
}

@test "outside a git repo the diff falls back to the session's edit counters" {
    mkdir -p "$WORK/plain-dir"
    run statusline "$(jq -n --arg d "$WORK/plain-dir" '{workspace: {project_dir: $d, current_dir: $d},
        cost: {total_lines_added: 428, total_lines_removed: 91}}')"
    [ "$status" -eq 0 ]
    [[ "$output" == "plain-dir +428/-91 | Opus 5 | "* ]]
}

@test "below 200k: no LONG, 200k window, optional fields absent" {
    run statusline '{
        "model": {"display_name": "Sonnet 5"},
        "context_window": {"total_input_tokens": 16000, "context_window_size": 200000,
                           "used_percentage": 8},
        "exceeds_200k_tokens": false
    }'
    [ "$status" -eq 0 ]
    [ "$output" = "advanced-gym ⎇ main | Sonnet 5 | Ctx 8% · 16k/200k" ]
}

@test "null used_percentage is computed from tokens / window" {
    run statusline '{"context_window": {"used_percentage": null}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Ctx 55% · 548k/1M · LONG" ]]
}

@test "resets under an hour and a 7d reset within a day show countdowns" {
    run statusline '{"rate_limits": {
        "five_hour": {"used_percentage": 90, "resets_at": 1738422520},
        "seven_day": {"used_percentage": 99, "resets_at": 1738438600}
    }}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"| 5h 90% ↻42m · 7d 99% ↻5h10m" ]]
}

@test "only one quota window present shows only that window" {
    run statusline '{"rate_limits": {"seven_day": {"used_percentage": 12, "resets_at": 1738679200}}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"· LONG | 7d 12% ↻Tue" ]]
}

@test "wide: worktree and PR go on a second line" {
    run statusline "$EXTRAS"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[1]}" = "WT ui-redesign | PR #184 approved" ]
}

@test "PR without review state and git worktree name from workspace" {
    run statusline '{"workspace": {"git_worktree": "feature-xyz"}, "pr": {"number": 7}}'
    [ "$status" -eq 0 ]
    [ "${lines[1]}" = "WT feature-xyz | PR #7" ]
}

@test "narrow terminal: compact first line, diff/WT/PR on the second" {
    edit_tracked
    export COLUMNS=80
    run statusline "$(jq -n --argjson a "$FULL" --argjson b "$EXTRAS" '$a * $b')"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = "advanced-gym ⎇ main* | Opus 5:high | Ctx 55% | 5h 72% | 7d 41%" ]
    [ "${lines[1]}" = "+3/-2 · WT ui-redesign · PR #184 approved" ]
}

@test "narrow terminal with nothing extra prints a single line" {
    export COLUMNS=80
    run statusline
    [ "$status" -eq 0 ]
    [ "$output" = "advanced-gym ⎇ main | Opus 5 | Ctx 55%" ]
}

# --- Project / branch -----------------------------------------------------------

@test "branch follows current_dir (e.g. a worktree) while project stays the launch dir" {
    git -C "$REPO" worktree add -q -b wt-branch "$WORK/wt"
    run statusline "$(jq -n --arg c "$WORK/wt" '{workspace: {current_dir: $c}}')"
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ wt-branch | "* ]]
}

@test "detached HEAD shows the short commit hash" {
    git -C "$REPO" checkout -q --detach
    sha=$(git -C "$REPO" rev-parse --short HEAD)
    run statusline
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ $sha | "* ]]
}

@test "outside a git repo shows only the project name" {
    mkdir -p "$WORK/plain-dir"
    run statusline "$(jq -n --arg d "$WORK/plain-dir" '{workspace: {project_dir: $d, current_dir: $d}}')"
    [ "$status" -eq 0 ]
    [[ "$output" == "plain-dir | Opus 5 | "* ]]
}

@test "falls back to cwd when workspace and context_window are absent" {
    run bash -c "jq -n --arg c '$REPO' '{cwd: \$c, model: {display_name: \"Sonnet\"}}' | bash '$SCRIPT' | sed 's/\x1b\[[0-9;]*m//g'"
    [ "$status" -eq 0 ]
    [ "$output" = "advanced-gym ⎇ main | Sonnet | Ctx 0% · 0/200k" ]
}

# --- Remote Control -------------------------------------------------------------

@test "remote control: a connected session is tagged RC at the start of line 1" {
    session_file 111 other-session session_01Other
    session_file 222 sess-1 session_01Abc
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "RC | advanced-gym ⎇ main | Opus 5 | "* ]]
}

@test "remote control: narrow terminal keeps the tag" {
    export COLUMNS=80
    session_file 222 sess-1 session_01Abc
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [ "$output" = "RC | advanced-gym ⎇ main | Opus 5 | Ctx 55%" ]
}

@test "remote control: a session that is not connected has no tag" {
    session_file 222 sess-1
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main | "* ]]
}

@test "remote control: another session's connection does not tag this one" {
    session_file 111 other-session session_01Other
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main | "* ]]
}

@test "remote control: the most recently updated file for the session wins" {
    session_file 111 sess-1 session_01Old 100   # stale file from before a resume
    session_file 222 sess-1 "" 200
    run statusline '{"session_id": "sess-1"}'
    [[ "$output" == "advanced-gym ⎇ main | "* ]]
    session_file 333 sess-1 session_01New 300
    run statusline '{"session_id": "sess-1"}'
    [[ "$output" == "RC | advanced-gym"* ]]
}

@test "remote control: unreadable session files and a missing dir are ignored" {
    printf '{ not json' >"$CLAUDE_CONFIG_DIR/sessions/333.json"
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main | "* ]]
    rm -rf "$CLAUDE_CONFIG_DIR/sessions"
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main | "* ]]
}

# --- Remaining context tokens -----------------------------------------------------

@test "wide: remaining tokens come from remaining_percentage and sit before LONG" {
    run statusline '{"context_window": {"remaining_percentage": 45.2}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Ctx 55% · 548k/1M · 452k left · LONG"* ]]
}

@test "remaining tokens are hidden when remaining_percentage is absent or null" {
    run statusline '{"context_window": {"remaining_percentage": null}}'
    [ "$status" -eq 0 ]
    [[ "$output" != *left* ]]
    run statusline
    [[ "$output" != *left* ]]
}

# --- Context pressure colours -----------------------------------------------------

# ctx_color <used_percentage>: the escape sequence that starts the Ctx segment.
ctx_color() {
    payload "{\"context_window\": {\"used_percentage\": $1}}" | bash "$SCRIPT" \
        | grep -o $'\033\\[[0-9;]*mCtx' | sed 's/Ctx$//'
}

@test "context pressure colours switch at 75, 85 and 95 percent" {
    green=$'\033[0;32m' yellow=$'\033[0;33m' orange=$'\033[38;5;208m' red=$'\033[1;31m'
    [ "$(ctx_color 74)" = "$green" ]
    [ "$(ctx_color 75)" = "$yellow" ]
    [ "$(ctx_color 84)" = "$yellow" ]
    [ "$(ctx_color 85)" = "$orange" ]
    [ "$(ctx_color 94)" = "$orange" ]
    [ "$(ctx_color 95)" = "$red" ]
}

# --- Git counts and ahead/behind ---------------------------------------------------

@test "git: staged, unstaged and untracked path counts when more than one path changed" {
    touch "$REPO/a" "$REPO/b"
    git -C "$REPO" add a b
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m ab
    echo x >"$REPO/a"; git -C "$REPO" add a      # staged
    echo y >"$REPO/b"                            # unstaged
    touch "$REPO/u1" "$REPO/u2"                  # untracked
    run statusline
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main* ●1 ✚1 …2 +2/-0 | "* ]]
}

@test "git: a single changed path keeps the plain marker (no count breakdown)" {
    touch "$REPO/u1"
    run statusline
    [[ "$output" == "advanced-gym ⎇ main* | "* ]]
}

# remote_setup: bare origin, main pushed and tracked.
remote_setup() {
    git init -q --bare "$WORK/origin.git"
    git -C "$REPO" remote add origin "$WORK/origin.git"
    git -C "$REPO" push -q -u origin main 2>/dev/null
}

@test "git: ahead and behind the upstream, shown only when non-zero" {
    remote_setup
    run statusline
    [[ "$output" == "advanced-gym ⎇ main | "* ]]
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m local
    run statusline
    [[ "$output" == "advanced-gym ⎇ main ↑1 | "* ]]
    # Another clone pushes; the script does not fetch, so it stays unaware.
    git clone -q -b main "$WORK/origin.git" "$WORK/other" 2>/dev/null
    git -C "$WORK/other" -c user.name=t -c user.email=t@t commit -q --allow-empty -m r1
    git -C "$WORK/other" -c user.name=t -c user.email=t@t commit -q --allow-empty -m r2
    git -C "$WORK/other" push -q origin HEAD:main
    run statusline
    [[ "$output" == "advanced-gym ⎇ main ↑1 | "* ]]
    git -C "$REPO" fetch -q origin
    run statusline
    [[ "$output" == "advanced-gym ⎇ main ↑1↓2 | "* ]]
}

@test "git: the script never fetches or pulls" {
    ! grep -Eq '^[^#]*git[^#]*(fetch|pull)' "$SCRIPT"
}

@test "git results are cached for the TTL in a per-repo file under XDG_RUNTIME_DIR" {
    export STATUSLINE_GIT_TTL=5
    run statusline
    [[ "$output" == "advanced-gym ⎇ main | "* ]]
    touch "$REPO/a"
    run statusline
    [[ "$output" == "advanced-gym ⎇ main | "* ]]          # still cached
    [ -n "$(find "$XDG_RUNTIME_DIR" -type f | head -1)" ]
    STATUSLINE_NOW=$((NOW + 6)) run statusline
    [[ "$output" == "advanced-gym ⎇ main* | "* ]]         # expired
}

@test "git cache is per repo" {
    export STATUSLINE_GIT_TTL=5
    make_repo "$WORK/second" trunk
    run statusline
    run statusline "$(jq -n --arg d "$WORK/second" '{workspace: {project_dir: $d, current_dir: $d}}')"
    [[ "$output" == "second ⎇ trunk | "* ]]
}

# --- Session cost and duration ------------------------------------------------------

@test "cost and duration go on the second line only when present" {
    run statusline '{"cost": {"total_cost_usd": 1.234, "total_duration_ms": 3725000}}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[1]}" = '$1.23 · 1h02m' ]
    run statusline '{"cost": {"total_cost_usd": 0.5, "total_duration_ms": 45000}}'
    [ "${lines[1]}" = '$0.50 · 45s' ]
    run statusline '{"cost": {"total_duration_ms": 720000}}'
    [ "${lines[1]}" = "12m" ]
    run statusline '{"cost": {"total_lines_added": 1}}'
    [ "${#lines[@]}" -eq 1 ]
}

# --- Cache health -------------------------------------------------------------------

@test "cache health shows the hit ratio, or cold, only when caching is observed" {
    run statusline '{"prompt_cache": {"caching_observed": true, "warm": true, "hit_ratio": 0.91}}'
    [ "${lines[1]}" = "Cache 91%" ]
    run statusline '{"prompt_cache": {"caching_observed": true, "warm": false, "hit_ratio": 0.91}}'
    [ "${lines[1]}" = "Cache 91% cold" ]
    run statusline '{"prompt_cache": {"caching_observed": true, "warm": true, "hit_ratio": null}}'
    [ "${#lines[@]}" -eq 1 ]
    run statusline '{"prompt_cache": {"caching_observed": false, "warm": false, "hit_ratio": 0}}'
    [ "${#lines[@]}" -eq 1 ]
}

@test "worktree, PR, cost and cache share the second line" {
    run statusline "$(jq -n --argjson b "$EXTRAS" '$b * {
        cost: {total_cost_usd: 2, total_duration_ms: 60000},
        prompt_cache: {caching_observed: true, warm: true, hit_ratio: 0.5}}')"
    [ "${lines[1]}" = 'WT ui-redesign | PR #184 approved | $2.00 · 1m · Cache 50%' ]
}

# --- Width adaptation ---------------------------------------------------------------

# width <text>: display columns of one line (ANSI already stripped; UTF-8
# continuation bytes do not count).
width() {
    printf %s "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
}

FULLER='{"context_window": {"remaining_percentage": 45.2}}'

@test "wide: drops remaining tokens first, then reset times, then 7d" {
    git -C "$REPO" checkout -q -b feature/statusline-upgrade-with-a-rather-long-name
    edit_tracked
    full="$(jq -n --argjson a "$FULL" --argjson b "$FULLER" '$a * $b')"
    run statusline "$full"
    [[ "${lines[0]}" == *"452k left"* ]]
    export COLUMNS=$(( $(width "${lines[0]}") - 1 ))
    run statusline "$full"
    [ "${lines[0]}" = "advanced-gym ⎇ feature/statusline-upgrade-with-a-rather-long-name* +3/-2 | Opus 5 · effort:high | Ctx 55% · 548k/1M · LONG | 5h 72% ↻1h24m · 7d 41% ↻Tue" ]
    export COLUMNS=$(( $(width "${lines[0]}") - 1 ))
    run statusline "$full"
    [[ "${lines[0]}" != *left* && "${lines[0]}" != *"↻"* && "${lines[0]}" == *"7d 41%"* ]]
    export COLUMNS=$(( $(width "${lines[0]}") - 1 ))
    run statusline "$full"
    [[ "${lines[0]}" != *"7d"* && "${lines[0]}" == *"5h 72%"* ]]
}

@test "every line fits the terminal for widths down to 60" {
    edit_tracked
    full="$(jq -n --argjson a "$FULL" --argjson b "$FULLER" --argjson c "$EXTRAS" '$a * $b * $c')"
    for cols in 200 140 125 119 100 90 80 70 60; do
        COLUMNS=$cols run statusline "$full"
        [ "$status" -eq 0 ]
        for l in "${lines[@]}"; do
            [ "$(width "$l")" -le "$cols" ] || { echo "cols=$cols width=$(width "$l"): $l"; false; }
        done
    done
}

@test "narrow line drops 7d, then 5h, as the terminal shrinks" {
    export COLUMNS=45
    run statusline "$FULL"
    [ "$output" = "advanced-gym ⎇ main | Opus 5:high | Ctx 55%" ]
    export COLUMNS=56
    run statusline "$FULL"
    [ "$output" = "advanced-gym ⎇ main | Opus 5:high | Ctx 55% | 5h 72%" ]
}

@test "the statusline does not print the permission/auto mode (native footer owns it)" {
    run statusline '{"permission_mode": "auto", "vim": {"mode": "NORMAL"}}'
    [[ "$output" != *auto* ]]
}

@test "one invocation stays fast" {
    start=$SECONDS
    for _ in 1 2 3 4 5; do statusline "$FULL" >/dev/null; done
    [ $(( SECONDS - start )) -le 3 ]
}

# --- Cache hardening ----------------------------------------------------------------

# cache_file <repo-dir>: where the script keeps that directory's cached line.
cache_file() {
    local key
    key=$(printf %s "$1" | cksum)
    printf '%s/claude-statusline-%s/%s' "$XDG_RUNTIME_DIR" "$(id -u)" "${key%% *}"
}

@test "cache: a crafted line is a miss and nothing in it is ever evaluated" {
    export STATUSLINE_GIT_TTL=5
    marker="$WORK/pwned"
    file=$(cache_file "$REPO")
    mkdir -p -m 700 "$(dirname "$file")"
    printf '%s\tmain\tX[$(touch %s)]\t0\t0\t0\t0\t0\t0\t0\n' "$NOW" "$marker" >"$file"
    run statusline
    [ "$status" -eq 0 ]
    [ ! -e "$marker" ]
    [[ "$output" == "advanced-gym ⎇ main | "* ]]
    # The first field is checked too.
    printf 'NOW[$(touch %s)]\tmain\t0\t0\t0\t0\t0\t0\t0\t0\n' "$marker" >"$file"
    run statusline
    [ ! -e "$marker" ]
}

@test "cache: a line with control characters in the branch is a miss" {
    export STATUSLINE_GIT_TTL=5
    file=$(cache_file "$REPO")
    mkdir -p -m 700 "$(dirname "$file")"
    printf '%s\tevil\033[31mbranch\t0\t0\t0\t0\t0\t0\t0\t0\n' "$NOW" >"$file"
    run bash -c "jq -n --arg d '$REPO' '{workspace: {project_dir: \$d, current_dir: \$d}}' | bash '$SCRIPT'"
    [[ "$output" != *evil* ]]
}

@test "cache: a symlinked cache directory is not followed or chmodded" {
    export STATUSLINE_GIT_TTL=5 TMPDIR="$WORK/tmpd"
    unset XDG_RUNTIME_DIR
    mkdir -p "$TMPDIR" "$WORK/victim"
    chmod 755 "$WORK/victim"
    ln -s "$WORK/victim" "$TMPDIR/claude-statusline-$(id -u)"
    run statusline
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main | "* ]]
    [ -n "$(find "$WORK/victim" -maxdepth 0 -perm 755)" ]
    [ -z "$(find "$WORK/victim" -type f)" ]
}
