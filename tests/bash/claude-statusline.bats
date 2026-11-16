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
    export STATUSLINE_NOW=$NOW TZ=UTC COLUMNS=200 LC_ALL=C.UTF-8
    unset NO_COLOR CLAUDE_STATUSLINE_MODE
    # The two-row wide layout switches on automatically from 160 columns; the
    # pre-existing tests assert the three-row layout at 160 and 200, so they
    # pin the auto breakpoint out of reach. The wide tests unset it.
    export CLAUDE_STATUSLINE_WIDE_MIN=100000
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

@test "full: dirty branch, diff, effort, real context %, bars, 5h and 7d quota" {
    edit_tracked
    run statusline "$FULL"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 3 ]
    [ "${lines[0]}" = "advanced-gym ⎇ main* │ Opus 5 high" ]
    [ "${lines[1]}" = "Ctx ██████░░░░ 55% · 548k/1M │ 5h 72% ↻1h24m · 7d ████░░░░░░ 41% ↻Tue" ]
    [ "${lines[2]}" = "Git +3/-2" ]
}

@test "clean tree has no dirty marker and no diff segment when nothing changed" {
    run statusline '{"cost": {"total_lines_added": 0, "total_lines_removed": 0}}'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "advanced-gym ⎇ main │ Opus 5" ]
    [[ "$output" != *Git* ]]
}

@test "diff is the live working tree against HEAD, not the session's edit counters" {
    # The session counters claim edits, but the tree is clean: nothing to show.
    run statusline "$FULL"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "advanced-gym ⎇ main │ Opus 5 high" ]
    [[ "$output" != *Git* ]]
    # Staged and unstaged changes both count; committing clears the segment.
    edit_tracked
    git -C "$REPO" add f.txt
    echo d >>"$REPO/f.txt"
    run statusline "$FULL"
    [ "${lines[0]}" = "advanced-gym ⎇ main* │ Opus 5 high" ]
    [[ "$output" == *"Git +4/-2" ]]
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -am edit
    run statusline "$FULL"
    [[ "$output" == "advanced-gym ⎇ main │ Opus 5"* && "$output" != *Git* ]]
}

@test "untracked files mark the tree dirty but add no line counts" {
    touch "$REPO/untracked.txt"
    run statusline "$FULL"
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main* │ Opus 5"* ]]
}

@test "binary changes are skipped in the line counts" {
    printf '\0\1' >"$REPO/b.bin"
    git -C "$REPO" add b.bin
    run statusline
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main* │ Opus 5"* ]]
}

@test "outside a git repo the diff falls back to the session's edit counters" {
    mkdir -p "$WORK/plain-dir"
    run statusline "$(jq -n --arg d "$WORK/plain-dir" '{workspace: {project_dir: $d, current_dir: $d},
        cost: {total_lines_added: 428, total_lines_removed: 91}}')"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "plain-dir │ Opus 5" ]
    [[ "$output" == *"Git +428/-91" ]]
}

@test "200k window, optional fields absent" {
    run statusline '{
        "model": {"display_name": "Sonnet 5"},
        "context_window": {"total_input_tokens": 16000, "context_window_size": 200000,
                           "used_percentage": 8},
        "exceeds_200k_tokens": false
    }'
    [ "$status" -eq 0 ]
    [ "$output" = "advanced-gym ⎇ main │ Sonnet 5
Ctx █░░░░░░░░░ 8% · 16k/200k" ]
}

@test "null used_percentage is computed from tokens / window" {
    run statusline '{"context_window": {"used_percentage": null}}'
    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == "Ctx ██████░░░░ 55% · 548k/1M" ]]
}

@test "resets under an hour and a 7d reset within a day show countdowns" {
    run statusline '{"rate_limits": {
        "five_hour": {"used_percentage": 90, "resets_at": 1738422520},
        "seven_day": {"used_percentage": 99, "resets_at": 1738438600}
    }}'
    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == *"│ 5h 90% ↻42m · 7d ██████████ 99% ↻5h10m" ]]
}

@test "only one quota window present shows only that window" {
    run statusline '{"rate_limits": {"seven_day": {"used_percentage": 12, "resets_at": 1738679200}}}'
    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == *"548k/1M │ 7d █░░░░░░░░░ 12% ↻Tue" ]]
}

@test "full: worktree and PR go on the third row" {
    run statusline "$EXTRAS"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 3 ]
    [ "${lines[2]}" = "WT ui-redesign · PR #184 approved" ]
}

@test "PR without review state and git worktree name from workspace" {
    run statusline '{"workspace": {"git_worktree": "feature-xyz"}, "pr": {"number": 7}}'
    [ "$status" -eq 0 ]
    [ "${lines[2]}" = "WT feature-xyz · PR #7" ]
}

@test "compact layout (80-119 columns): identity and pressure share row 1, Git/WT/PR on row 2" {
    edit_tracked
    export COLUMNS=80
    run statusline "$(jq -n --argjson a "$FULL" --argjson b "$EXTRAS" '$a * $b')"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = "advanced-gym main* │ Opus 5:H │ Ctx 55% │ 5h 72% · 7d 41%" ]
    [ "${lines[1]}" = "Git +3/-2 │ WT ui-redesign · PR #184 approved" ]
}

@test "narrow terminal with nothing extra prints a single line" {
    export COLUMNS=80
    run statusline
    [ "$status" -eq 0 ]
    [ "$output" = "advanced-gym main │ Opus 5 │ Ctx 55%" ]
}

# --- Project / branch -----------------------------------------------------------

@test "branch follows current_dir (e.g. a worktree) while project stays the launch dir" {
    git -C "$REPO" worktree add -q -b wt-branch "$WORK/wt"
    run statusline "$(jq -n --arg c "$WORK/wt" '{workspace: {current_dir: $c}}')"
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ wt-branch │ "* ]]
}

@test "detached HEAD shows the short commit hash" {
    git -C "$REPO" checkout -q --detach
    sha=$(git -C "$REPO" rev-parse --short HEAD)
    run statusline
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ $sha │ "* ]]
}

@test "outside a git repo shows only the project name" {
    mkdir -p "$WORK/plain-dir"
    run statusline "$(jq -n --arg d "$WORK/plain-dir" '{workspace: {project_dir: $d, current_dir: $d}}')"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "plain-dir │ Opus 5" ]
}

@test "falls back to cwd when workspace and context_window are absent" {
    run bash -c "jq -n --arg c '$REPO' '{cwd: \$c, model: {display_name: \"Sonnet\"}}' | bash '$SCRIPT' | sed 's/\x1b\[[0-9;]*m//g'"
    [ "$status" -eq 0 ]
    # Was "Ctx 0% · 0/200k": a missing context_window must not render as 0%.
    [ "$output" = "advanced-gym ⎇ main │ Sonnet
Ctx —" ]
}

# --- Remote Control -------------------------------------------------------------

@test "remote control: a connected session is tagged RC at the start of line 1" {
    session_file 111 other-session session_01Other
    session_file 222 sess-1 session_01Abc
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "RC │ advanced-gym ⎇ main │ Opus 5" ]
}

@test "remote control: narrow terminal keeps the tag" {
    export COLUMNS=80
    session_file 222 sess-1 session_01Abc
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [ "$output" = "RC │ advanced-gym main │ Opus 5 │ Ctx 55%" ]
}

@test "remote control: a session that is not connected has no tag" {
    session_file 222 sess-1
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]
}

@test "remote control: another session's connection does not tag this one" {
    session_file 111 other-session session_01Other
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]
}

@test "remote control: the most recently updated file for the session wins" {
    session_file 111 sess-1 session_01Old 100   # stale file from before a resume
    session_file 222 sess-1 "" 200
    run statusline '{"session_id": "sess-1"}'
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]
    session_file 333 sess-1 session_01New 300
    run statusline '{"session_id": "sess-1"}'
    [[ "$output" == "RC │ advanced-gym"* ]]
}

@test "remote control: unreadable session files and a missing dir are ignored" {
    printf '{ not json' >"$CLAUDE_CONFIG_DIR/sessions/333.json"
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]
    rm -rf "$CLAUDE_CONFIG_DIR/sessions"
    run statusline '{"session_id": "sess-1"}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]
}

# --- Remaining context tokens -----------------------------------------------------

@test "full: remaining tokens come from remaining_percentage and sit after the token count" {
    run statusline '{"context_window": {"remaining_percentage": 45.2}}'
    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == "Ctx ██████░░░░ 55% · 548k/1M · ~452k left" ]]
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
    [ "${lines[0]}" = "advanced-gym ⎇ main* │ Opus 5" ]
    [ "${lines[2]}" = "Git ●1 ✚1 …2 +2/-0" ]
}

@test "git: a single changed path keeps the plain marker (no count breakdown)" {
    touch "$REPO/u1"
    run statusline
    [[ "$output" == "advanced-gym ⎇ main* │ "* ]]
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
    [ "${lines[0]}" = "advanced-gym ⎇ main │ Opus 5" ]
    [[ "$output" != *Git* ]]
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m local
    run statusline
    [ "${lines[2]}" = "Git ↑1" ]
    # Another clone pushes; the script does not fetch, so it stays unaware.
    git clone -q -b main "$WORK/origin.git" "$WORK/other" 2>/dev/null
    git -C "$WORK/other" -c user.name=t -c user.email=t@t commit -q --allow-empty -m r1
    git -C "$WORK/other" -c user.name=t -c user.email=t@t commit -q --allow-empty -m r2
    git -C "$WORK/other" push -q origin HEAD:main
    run statusline
    [ "${lines[2]}" = "Git ↑1" ]
    git -C "$REPO" fetch -q origin
    run statusline
    [ "${lines[2]}" = "Git ↑1↓2" ]
}

@test "git: the script never fetches or pulls" {
    ! grep -Eq '^[^#]*git[^#]*(fetch|pull)' "$SCRIPT"
}

@test "git results are cached for the TTL in a per-repo file under XDG_RUNTIME_DIR" {
    export STATUSLINE_GIT_TTL=5
    run statusline
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]
    touch "$REPO/a"
    run statusline
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]          # still cached
    [ -n "$(find "$XDG_RUNTIME_DIR" -type f | head -1)" ]
    STATUSLINE_NOW=$((NOW + 6)) run statusline
    [[ "$output" == "advanced-gym ⎇ main* │ "* ]]         # expired
}

@test "git cache is per repo" {
    export STATUSLINE_GIT_TTL=5
    make_repo "$WORK/second" trunk
    run statusline
    run statusline "$(jq -n --arg d "$WORK/second" '{workspace: {project_dir: $d, current_dir: $d}}')"
    [[ "$output" == "second ⎇ trunk │ "* ]]
}

# --- Session cost and duration ------------------------------------------------------

@test "cost and duration go on the third row only when present" {
    run statusline '{"cost": {"total_cost_usd": 1.234, "total_duration_ms": 3725000}}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 3 ]
    [ "${lines[2]}" = '$1.23 · 1h02m' ]
    run statusline '{"cost": {"total_cost_usd": 0.5, "total_duration_ms": 45000}}'
    [ "${lines[2]}" = '$0.50 · 45s' ]
    run statusline '{"cost": {"total_duration_ms": 720000}}'
    [ "${lines[2]}" = "12m" ]
    run statusline '{"cost": {"total_lines_added": 1}}'
    [ "${#lines[@]}" -eq 2 ]
}

# --- Cache health -------------------------------------------------------------------

@test "cache health shows the hit ratio, or cold, only when caching is observed" {
    run statusline '{"prompt_cache": {"caching_observed": true, "warm": true, "hit_ratio": 0.91}}'
    [ "${lines[2]}" = "Cache 91%" ]
    run statusline '{"prompt_cache": {"caching_observed": true, "warm": false, "hit_ratio": 0.91}}'
    [ "${lines[2]}" = "Cache 91% cold" ]
    run statusline '{"prompt_cache": {"caching_observed": true, "warm": true, "hit_ratio": null}}'
    [ "${#lines[@]}" -eq 2 ]
    run statusline '{"prompt_cache": {"caching_observed": false, "warm": false, "hit_ratio": 0}}'
    [ "${#lines[@]}" -eq 2 ]
}

@test "worktree, PR, cost and cache share the third row" {
    run statusline "$(jq -n --argjson b "$EXTRAS" '$b * {
        cost: {total_cost_usd: 2, total_duration_ms: 60000},
        prompt_cache: {caching_observed: true, warm: true, hit_ratio: 0.5}}')"
    [ "${lines[2]}" = 'WT ui-redesign · PR #184 approved │ $2.00 · 1m · Cache 50%' ]
}

# --- Width adaptation ---------------------------------------------------------------

# width <text>: display columns of one line (ANSI already stripped; UTF-8
# continuation bytes do not count).
width() {
    printf %s "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
}

FULLER='{"context_window": {"remaining_percentage": 45.2}}'

@test "full layout: precision goes first, bars, then reset times (layout pinned to full)" {
    export CLAUDE_STATUSLINE_MODE=full
    git -C "$REPO" checkout -q -b feature/statusline-upgrade-with-a-rather-long-name
    edit_tracked
    full="$(jq -n --argjson a "$FULL" --argjson b "$FULLER" '$a * $b')"
    run statusline "$full"
    [ "${lines[1]}" = "Ctx ██████░░░░ 55% · 548k/1M · ~452k left │ 5h 72% ↻1h24m · 7d ████░░░░░░ 41% ↻Tue" ]
    export COLUMNS=$(( $(width "${lines[1]}") - 1 ))
    run statusline "$full"
    [ "${lines[1]}" = "Ctx 55% · 548k/1M · ~452k left │ 5h 72% ↻1h24m · 7d 41% ↻Tue" ]
    export COLUMNS=$(( $(width "${lines[1]}") - 1 ))
    run statusline "$full"
    [ "${lines[1]}" = "Ctx 55% · 548k/1M · ~452k left │ 5h 72% · 7d 41%" ]
}

@test "layouts step down with the width: full, compact, minimal" {
    full="$(jq -n --argjson a "$FULL" --argjson b "$FULLER" '$a * $b')"
    COLUMNS=120 run statusline "$full"
    [ "${#lines[@]}" -eq 2 ]
    [[ "${lines[1]}" == "Ctx █"* ]]
    COLUMNS=119 run statusline "$full"
    [ "${lines[0]}" = "advanced-gym main │ Opus 5:H │ Ctx 55% · 452k left │ 5h 72% · 7d 41%" ]
    COLUMNS=79 run statusline "$full"
    [ "${lines[0]}" = "advanced-gym main │ Opus:H │ Ctx 55% │ 5h 72% · 7d 41%" ]
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

@test "minimal layout gives up effort first, then the lower quota, then the other" {
    export COLUMNS=53
    run statusline "$FULL"
    [ "$output" = "advanced-gym main │ Opus │ Ctx 55% │ 5h 72% · 7d 41%" ]
    export COLUMNS=44
    run statusline "$FULL"
    [ "$output" = "advanced-gym main │ Opus │ Ctx 55% │ 5h 72%" ]
    export COLUMNS=42
    run statusline "$FULL"
    [ "$output" = "advanced-gym main │ Opus │ Ctx 55%" ]
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
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]
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
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]
    [ -n "$(find "$WORK/victim" -maxdepth 0 -perm 755)" ]
    [ -z "$(find "$WORK/victim" -type f)" ]
}

# --- Session agent (`claude --agent`) -------------------------------------------
# Payload field per the statusline docs: agent.name (only when an agent is active).

@test "agent: a --agent session shows a coloured tag at the start of line 1" {
    run statusline '{"agent": {"name": "orchestrator"}}'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "◆ orchestrator │ advanced-gym ⎇ main │ Opus 5" ]
    raw=$(payload '{"agent": {"name": "orchestrator"}}' | bash "$SCRIPT" | head -1)
    [[ "$raw" == $'\033[38;5;140m◆ orchestrator\033[0m │ '* ]]
}

@test "agent: an unknown type still has a colour, and the tag follows RC and survives narrow widths" {
    export COLUMNS=70
    session_file 222 sess-1 session_01Abc
    run statusline '{"session_id": "sess-1", "agent": {"name": "mystery"}}'
    [ "$output" = "RC │ ◆ mystery │ advanced-gym main │ Opus │ Ctx 55%" ]
    raw=$(payload '{"agent": {"name": "mystery"}}' | bash "$SCRIPT" | head -1)
    [[ "$raw" == $'\033[38;5;'*$'m◆ mystery\033[0m │ '* ]]
    # The compact layout (80-119 columns) keeps the tag too.
    COLUMNS=100 run statusline '{"agent": {"name": "mystery"}}'
    [[ "${lines[0]}" == "◆ mystery │ advanced-gym main │ Opus 5:H"* || "${lines[0]}" == "◆ mystery │ advanced-gym main │ Opus 5"* ]]
}

@test "agent: no tag when the payload has no agent" {
    run statusline '{}'
    [[ "${lines[0]}" == "advanced-gym ⎇ main │ "* ]]
    [[ "$output" != *"◆"* ]]
}

@test "agent: a long name is truncated and line 1 fits 60 columns" {
    export COLUMNS=60
    long=$(printf 'x%.0s' {1..40})
    raw=$(payload "$(jq -n --arg n "$long" '{agent: {name: $n}}')" | bash "$SCRIPT" | head -1 | sed 's/\x1b\[[0-9;]*m//g')
    [ "${#raw}" -le 60 ]
    COLUMNS=200 run statusline "$(jq -n --arg n "$long" '{agent: {name: $n}}')"
    [[ "${lines[0]}" == "◆ xxxxxxxxxxxxxxxxxxx… │ "* ]]
}

@test "agent: a string agent, a non-object agent and control characters are tolerated" {
    run statusline '{"agent": "reviewer"}'
    [[ "${lines[0]}" == "◆ reviewer │ "* ]]
    run statusline '{"agent": 7}'
    [ "$status" -eq 0 ]
    [[ "$output" != *"◆"* ]]
    run statusline '{"agent": {"name": "a\u001b[31mb"}}'
    [[ "${lines[0]}" == "◆ a[31mb │ "* ]]
}

# --- Pressure colours, quota-first fitting, NO_COLOR, bars ----------------------------

@test "no fixed LONG marker: a 1M window past 200k tokens is judged by its own percentage" {
    run statusline '{"exceeds_200k_tokens": true}'
    [[ "$output" != *LONG* ]]
    run statusline '{"context_window": {"total_input_tokens": 250000, "context_window_size": 1000000, "used_percentage": 25}}'
    [[ "$output" != *LONG* && "$output" == *"Ctx ███░░░░░░░ 25%"* ]]
}

@test "context bar fills 10 cells by percentage and clamps" {
    run statusline '{"context_window": {"used_percentage": 92}}'
    [[ "$output" == *"Ctx █████████░ 92%"* ]]
    run statusline '{"context_window": {"used_percentage": 100}}'
    [[ "$output" == *"Ctx ██████████ 100%"* ]]
    run statusline '{"context_window": {"used_percentage": 130}}'
    [[ "$output" == *"Ctx ██████████ 130%"* ]]
}

@test "ASCII fallback: bars use # and - when the locale is not UTF-8" {
    export LC_ALL=C
    run statusline '{"context_window": {"used_percentage": 92}, "rate_limits": {"seven_day": {"used_percentage": 41}}}'
    [[ "$output" == *"Ctx #########- 92%"* ]]
    [[ "$output" == *"7d ####------ 41%"* ]]
    [[ "$output" != *█* && "$output" != *░* ]]
}

@test "bars appear only on the full layout" {
    export COLUMNS=100
    run statusline '{"rate_limits": {"seven_day": {"used_percentage": 41}}}'
    [[ "$output" != *█* && "$output" != *░* ]]
}

@test "NO_COLOR: no escape codes at all, same layout" {
    edit_tracked
    colored=$(payload "$FULL" | bash "$SCRIPT")
    plain=$(payload "$FULL" | NO_COLOR=1 bash "$SCRIPT")
    [[ "$colored" == *$'\033'* ]]
    [[ "$plain" != *$'\033'* ]]
    [ "$plain" = "$(sed 's/\x1b\[[0-9;]*m//g' <<<"$colored")" ]
}

@test "NO_COLOR: also applies to the agent tag, RC and narrow layouts" {
    export COLUMNS=70
    session_file 222 sess-1 session_01Abc
    out=$(payload '{"session_id": "sess-1", "agent": {"name": "reviewer"}}' | NO_COLOR=1 bash "$SCRIPT")
    [[ "$out" != *$'\033'* ]]
    [[ "$out" == "RC │ ◆ reviewer │ advanced-gym main │ Opus │ Ctx 55%" ]]
}

@test "NO_COLOR set but empty does not disable colour" {
    out=$(payload | NO_COLOR= bash "$SCRIPT")
    [[ "$out" == *$'\033'* ]]
}

@test "missing context fields show an em dash, never 0%" {
    run bash -c "jq -n --arg c '$REPO' '{cwd: \$c, context_window: {}}' | bash '$SCRIPT' | sed 's/\x1b\[[0-9;]*m//g'"
    [[ "$output" == *"Ctx —"* && "$output" != *"0%"* ]]
    export COLUMNS=80
    run bash -c "jq -n --arg c '$REPO' '{cwd: \$c}' | bash '$SCRIPT' | sed 's/\x1b\[[0-9;]*m//g'"
    [[ "$output" == *"Ctx —"* && "$output" != *"0%"* ]]
}

@test "missing quota fields are omitted, not shown as 0%" {
    run statusline '{"rate_limits": {"five_hour": {"resets_at": 1738425040}, "seven_day": {"used_percentage": null}}}'
    [[ "$output" != *"5h"* && "$output" != *"7d"* ]]
    export COLUMNS=80
    run statusline '{"rate_limits": {"five_hour": {}}}'
    [[ "$output" != *"5h"* && "$output" != *"7d"* ]]
}

# Minimal layout (below 80 columns) quota priority: the higher-utilisation quota survives.
@test "narrow: the quota with the higher utilisation is kept, 7d or 5h" {
    export COLUMNS=50
    run statusline '{"rate_limits": {"five_hour": {"used_percentage": 20}, "seven_day": {"used_percentage": 70}}}'
    [ "$output" = "advanced-gym main │ Opus │ Ctx 55% │ 7d 70%" ]
    run statusline '{"rate_limits": {"five_hour": {"used_percentage": 70}, "seven_day": {"used_percentage": 20}}}'
    [ "$output" = "advanced-gym main │ Opus │ Ctx 55% │ 5h 70%" ]
    # tie: 7d goes first, as before
    run statusline '{"rate_limits": {"five_hour": {"used_percentage": 50}, "seven_day": {"used_percentage": 50}}}'
    [ "$output" = "advanced-gym main │ Opus │ Ctx 55% │ 5h 50%" ]
}

@test "a quota at 85 percent or more is never dropped, at any width" {
    edit_tracked
    full="$(jq -n --argjson a "$FULL" --argjson b "$FULLER" --argjson c "$EXTRAS" \
        '$a * $b * $c * {rate_limits: {five_hour: {used_percentage: 30}, seven_day: {used_percentage: 96}}}')"
    for cols in 200 160 120 100 80 60; do
        COLUMNS=$cols run statusline "$full"
        [[ "$output" == *"7d "*"96%"* ]] || { echo "cols=$cols: $output"; false; }
    done
    full="$(jq '.rate_limits = {five_hour: {used_percentage: 91}, seven_day: {used_percentage: 96}}' <<<"$full")"
    for cols in 100 60; do
        COLUMNS=$cols run statusline "$full"
        [[ "$output" == *"5h 91%"* && "$output" == *"7d 96%"* ]] || { echo "cols=$cols: $output"; false; }
    done
}

@test "width: no line exceeds the terminal at 60, 80, 100, 120 and 160 columns" {
    edit_tracked
    full="$(jq -n --argjson a "$FULL" --argjson b "$FULLER" --argjson c "$EXTRAS" \
        '$a * $b * $c * {agent: {name: "release-auditor"}, cost: {total_cost_usd: 12.34, total_duration_ms: 3720000},
          prompt_cache: {caching_observed: true, warm: false, hit_ratio: 0.42},
          rate_limits: {five_hour: {used_percentage: 90, resets_at: 1738425040}, seven_day: {used_percentage: 97, resets_at: 1738679200}}}')"
    for cols in 60 80 100 120 160; do
        for loc in C.UTF-8 C; do
            LC_ALL=$loc COLUMNS=$cols run statusline "$full"
            [ "$status" -eq 0 ]
            for l in "${lines[@]}"; do
                [ "$(width "$l")" -le "$cols" ] || { echo "cols=$cols loc=$loc width=$(width "$l"): $l"; false; }
            done
        done
    done
}

@test "unknown window size is never assumed to be 200k (no 275% or /200k)" {
    run statusline '{"context_window": {"total_input_tokens": 550000, "context_window_size": null, "used_percentage": null, "remaining_percentage": 40}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ctx —"* ]]
    [[ "$output" != *275* && "$output" != *"/200k"* && "$output" != *left* ]]
    run statusline '{"context_window": {"total_input_tokens": 550000, "context_window_size": 0, "used_percentage": 55}}'
    [[ "$output" == *"Ctx ██████░░░░ 55%" ]]
}

@test "odd payload types do not blank the line" {
    run statusline '{"rate_limits": {"five_hour": {"used_percentage": "high", "resets_at": "soon"}, "seven_day": {"used_percentage": 30, "resets_at": "x"}}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"7d ███░░░░░░░ 30%" && "$output" != *5h* ]]
    run statusline '{"rate_limits": "none", "context_window": "big", "cost": {"total_lines_added": "many", "total_lines_removed": 1.5}}'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "advanced-gym ⎇ main │ Opus 5" ]
    [ "${lines[1]}" = "Ctx —" ]
    run statusline '{"cost": "free"}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main │ "* ]]
}

@test "odd line counts outside git: a string count is 0 and 1.5 rounds to 2" {
    mkdir -p "$WORK/plain-dir"
    run statusline "$(jq -n --arg d "$WORK/plain-dir" '{workspace: {project_dir: $d, current_dir: $d},
        cost: {total_lines_added: "many", total_lines_removed: 1.5}}')"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "plain-dir │ Opus 5" ]
    [[ "$output" == *"Git +0/-2" ]]
}

@test "string-valued effort, model, workspace, worktree, pr and prompt_cache do not blank the line" {
    run statusline '{"effort": "high", "model": "opus", "workspace": "here", "worktree": "wt",
        "pr": "184", "prompt_cache": "warm"}'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "advanced-gym ⎇ main │ unknown" ]
    [ "${lines[1]}" = "Ctx ██████░░░░ 55% · 548k/1M" ]
}

@test "a PR number that is not a number is omitted instead of printed" {
    run statusline '{"pr": {"number": {"id": 1}, "review_state": {"x": 1}}}'
    [ "$status" -eq 0 ]
    [[ "$output" != *PR* ]]
    run statusline '{"pr": {"number": 184.0, "review_state": "approved"}}'
    [[ "$output" == *"PR #184 approved" ]]
}

# --- Three rows, three layouts ---------------------------------------------------------

# rich: the shape of a busy session (RC, agent, git counts, 7d quota, cost, cache).
rich() {
    local dir=$WORK/rich
    rm -rf "$dir"; make_repo "$dir" main
    touch "$dir/a" "$dir/b"; git -C "$dir" add a b
    git -C "$dir" -c user.name=t -c user.email=t@t commit -q -m ab
    echo x >"$dir/a"; git -C "$dir" add a; echo y >"$dir/b"; touch "$dir/u1" "$dir/u2"
    session_file 222 sess-1 session_01Abc
    jq -n --arg d "$dir" '{
        session_id: "sess-1", cwd: $d, workspace: {project_dir: $d, current_dir: $d},
        agent: {name: "orchestrator"},
        model: {display_name: "Opus 5.5 (1M context)"}, effort: {level: "high"},
        context_window: {total_input_tokens: 140000, context_window_size: 1000000,
                         used_percentage: 14, remaining_percentage: 86},
        rate_limits: {seven_day: {used_percentage: 92, resets_at: 1738679200}},
        cost: {total_cost_usd: 294.30, total_duration_ms: 502260000},
        prompt_cache: {caching_observed: true, warm: true, hit_ratio: 0.97}}'
}

@test "full layout (160 columns): identity, pressure, then git and telemetry rows" {
    COLUMNS=160 run bash -c "$(declare -f rich make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich | bash '$SCRIPT' | sed 's/\x1b\[[0-9;]*m//g'"
    [ "${#lines[@]}" -eq 3 ]
    [ "${lines[0]}" = "RC │ ◆ orchestrator │ rich ⎇ main* │ Opus 5.5 high" ]
    [ "${lines[1]}" = "Ctx █░░░░░░░░░ 14% · 140k/1M · ~860k left │ 7d █████████░ 92% ↻Tue" ]
    [ "${lines[2]}" = 'Git ●1 ✚1 …2 +2/-0 │ $294.30 · 139h31m · Cache 97%' ]
}

@test "compact layout (100 columns): rows 1 and 2 merge, shorter labels, effort initial, agent tag kept" {
    out=$(rich | COLUMNS=100 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(wc -l <<<"$out")" -eq 2 ]
    [ "$(sed -n 1p <<<"$out")" = "RC │ ◆ orchestrator │ rich main* │ Opus 5.5:H │ Ctx 14% · 860k left │ 7d 92%" ]
    [ "$(sed -n 2p <<<"$out")" = 'Git ●1 ✚1 …2 +2/-0 │ $294.30 · 139h31m · Cache 97%' ]
}

@test "minimal layout (59 columns): no Git group, model without version, whole dollars" {
    out=$(rich | COLUMNS=59 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(wc -l <<<"$out")" -eq 2 ]
    # One column short of fitting RC and the agent tag: RC is the first whole
    # metric to go on row 1, and row 3 keeps everything.
    [ "$(sed -n 1p <<<"$out")" = "◆ orchestrator │ rich main* │ Opus:H │ Ctx 14% │ 7d 92%" ]
    [ "$(sed -n 2p <<<"$out")" = '$294 · 139h31m │ Cache 97%' ]
    out=$(rich | COLUMNS=60 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(sed -n 1p <<<"$out")" = "RC │ ◆ orchestrator │ rich main* │ Opus:H │ Ctx 14% │ 7d 92%" ]
}

@test "every layout fits at 160, 120, 100, 80, 60 and 40 columns, never losing a quota at 85%+" {
    for cols in 160 120 100 80 60 40; do
        out=$(rich | COLUMNS=$cols bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
        while IFS= read -r l; do
            [ "$(width "$l")" -le "$cols" ] || { echo "cols=$cols width=$(width "$l"): $l"; false; }
        done <<<"$out"
        [[ "$out" == *"7d "*"92%"* ]] || { echo "cols=$cols lost 7d: $out"; false; }
    done
}

@test "effort initials: high H, medium M, low L, xhigh X, max stays max" {
    export COLUMNS=100
    for pair in high:H medium:M low:L xhigh:X max:max; do
        run statusline "{\"effort\": {\"level\": \"${pair%%:*}\"}}"
        [[ "${lines[0]}" == *"Opus 5:${pair##*:}"* ]] || { echo "$pair: $output"; false; }
    done
    export COLUMNS=200
    run statusline '{"effort": {"level": "max"}}'
    [ "${lines[0]}" = "advanced-gym ⎇ main │ Opus 5 max" ]
}

@test "CLAUDE_STATUSLINE_MODE pins the layout regardless of width" {
    CLAUDE_STATUSLINE_MODE=compact COLUMNS=200 run statusline "$FULL"
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == *"Opus 5:H │ Ctx 55%"* ]]
    CLAUDE_STATUSLINE_MODE=full COLUMNS=100 run statusline "$FULL"
    [[ "${lines[0]}" == *"Opus 5 high" ]]
    CLAUDE_STATUSLINE_MODE=minimal COLUMNS=200 run statusline "$FULL"
    [[ "${lines[0]}" == *"Opus:H │ Ctx 55% │ 5h 72% · 7d 41%" ]]
    CLAUDE_STATUSLINE_MODE=bogus COLUMNS=200 run statusline "$FULL"
    [ "${#lines[@]}" -eq 2 ]
}

@test "ASCII locale: groups are separated by | and details by -, no box-drawing characters" {
    export LC_ALL=C COLUMNS=160
    run bash -c "$(declare -f rich make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich | bash '$SCRIPT' | sed 's/\x1b\[[0-9;]*m//g'"
    [[ "${lines[1]}" == "Ctx #---------"* ]]
    [[ "${lines[1]}" == "Ctx #--------- 14% - 140k/1M - ~860k left | 7d #########- 92%"* ]]
    [[ "${lines[2]}" == *'| $294.30 - 139h31m - Cache 97%' ]]
    [[ "$output" != *│* && "$output" != *·* ]]
}

@test "cache is plain when healthy and coloured only when low or cold" {
    raw() { payload "{\"prompt_cache\": {\"caching_observed\": true, \"warm\": $2, \"hit_ratio\": $1}}" | bash "$SCRIPT" | tail -1; }
    [[ "$(raw 0.97 true)" == "Cache 97%" ]]
    [[ "$(raw 0.60 true)" == $'\033[0;33mCache 60%\033[0m' ]]
    [[ "$(raw 0.30 true)" == $'\033[0;31mCache 30%\033[0m' ]]
    [[ "$(raw 0.97 false)" == "Cache 97% "$'\033[0;33mcold\033[0m' ]]
}

@test "minimal layout drops RC, then effort, then quotas below 85%; the agent tag is shortened and kept to the end" {
    out=$(rich | COLUMNS=55 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(sed -n 1p <<<"$out")" = "◆ orchestrator │ rich main* │ Opus:H │ Ctx 14% │ 7d 92%" ]
    out=$(rich | COLUMNS=54 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(sed -n 1p <<<"$out")" = "◆ orchestrator │ rich main* │ Opus │ Ctx 14% │ 7d 92%" ]
    out=$(rich | COLUMNS=48 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(sed -n 1p <<<"$out")" = "◆ orch │ rich main* │ Opus │ Ctx 14% │ 7d 92%" ]
    # Deliberate requirement change: the agent tag is never dropped while
    # anything else can go first, so other segments (context, project) give way.
    out=$(rich | COLUMNS=40 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(sed -n 1p <<<"$out")" = "◆ orch │ rich main* │ Opus │ 7d 92%" ]
    out=$(rich | COLUMNS=30 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(sed -n 1p <<<"$out")" = "◆ orch │ Opus │ 7d 92%" ]
    [[ "$(rich | COLUMNS=22 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 1p)" == *"◆ orch"* ]]
    # A weaker quota goes before the agent tag does.
    export COLUMNS=60
    run statusline '{"agent": {"name": "orchestrator"}, "rate_limits": {"five_hour": {"used_percentage": 20}, "seven_day": {"used_percentage": 30}}}'
    [[ "${lines[0]}" == *"◆ orchestrator"* ]]
}

@test "quota colour: green below 70, yellow below 85, orange from 85, red from 95" {
    q7() { payload "{\"rate_limits\": {\"seven_day\": {\"used_percentage\": $1}}}" | bash "$SCRIPT" | grep -o $'\033\\[[0-9;]*m7d' | sed -E 's/^\x1b\[([0-9;]*)m7d$/\1/'; }
    [ "$(q7 69)" = "0;32" ]
    [ "$(q7 70)" = "0;33" ]
    [ "$(q7 84)" = "0;33" ]
    [ "$(q7 85)" = "38;5;208" ]
    [ "$(q7 94)" = "38;5;208" ]
    [ "$(q7 95)" = "0;31" ]
}

# --- Wide layout: two rows, right-aligned metrics -------------------------------------

# rich_q: the rich session plus a 5h quota (default 88%, the more urgent one).
rich_q() {
    rich | jq --argjson p "${1:-88}" '.rate_limits.five_hour = {used_percentage: $p, resets_at: 1738425040}'
}

# run_rich <cols> [quota-percent-for-5h]: rich_q at a width, ANSI stripped; the wide
# breakpoint is 160 unless WIDE_MIN is set.
run_rich() {
    export CLAUDE_STATUSLINE_WIDE_MIN=${WIDE_MIN:-160}
    out=$(COLUMNS=$1 bash -c "$(declare -f rich rich_q make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich_q ${2:-88} | bash '$SCRIPT'" | sed 's/\x1b\[[0-9;]*m//g')
}

@test "wide (160 and 200 columns): exactly two rows, right-aligned inside the safety margin" {
    for cols in 160 200; do
        run_rich "$cols"
        [ "$(wc -l <<<"$out")" -eq 2 ] || { echo "cols=$cols: $out"; false; }
        while IFS= read -r l; do
            [ "$(width "$l")" -le $((cols - 3)) ] || { echo "cols=$cols width=$(width "$l"): $l"; false; }
        done <<<"$out"
        # Both rows end exactly at the right edge of the usable area.
        [ "$(width "$(sed -n 1p <<<"$out")")" -eq $((cols - 3)) ]
        [ "$(width "$(sed -n 2p <<<"$out")")" -eq $((cols - 3)) ]
        [[ "$(sed -n 1p <<<"$out")" == "RC │ ◆ orchestrator │ rich ⎇ main* │ Opus 5.5:H "* ]]
        [[ "$(sed -n 1p <<<"$out")" == *"140k/1M · ~860k left │ 5h 88% ↻1h24m · 7d 92% ↻Tue" ]]
        [[ "$(sed -n 2p <<<"$out")" == "Git ●1 ✚1 …2 +2/-0 "* ]]
        [[ "$(sed -n 2p <<<"$out")" == *'Cost $294.30 · Session 139h31m · Cache 97%' ]]
    done
}

@test "wide: the 5h quota shows when it is the more urgent one, not when 7d is" {
    run_rich 200 88
    [[ "$(sed -n 1p <<<"$out")" == *"5h 88%"*"7d 92%"* ]]
    run_rich 200 20
    [[ "$(sed -n 1p <<<"$out")" != *"5h"* ]]
    [[ "$(sed -n 1p <<<"$out")" == *"7d 92%"* ]]
}

@test "wide: cache is muted grey when healthy, coloured when low" {
    unset CLAUDE_STATUSLINE_WIDE_MIN
    raw=$(COLUMNS=200 bash -c "$(declare -f rich rich_q make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich_q | bash '$SCRIPT'" | sed -n 2p)
    [[ "$raw" == *$'\033[0;90mCache 97%\033[0m' ]]
    raw=$(COLUMNS=200 bash -c "$(declare -f rich rich_q make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich_q | jq '.prompt_cache.hit_ratio = 0.3' | bash '$SCRIPT'" | sed -n 2p)
    [[ "$raw" == *$'\033[0;31mCache 30%\033[0m' ]]
}

@test "wide: optional segments stay conditional (no WT/PR/session/cost placeholders)" {
    unset CLAUDE_STATUSLINE_WIDE_MIN
    COLUMNS=200 run statusline '{"agent": {"name": "reviewer"}}'
    [ "${#lines[@]}" -le 2 ]
    [[ "$output" != *"WT"* && "$output" != *"PR #"* && "$output" != *"Cost"* && "$output" != *"Session"* && "$output" != *"Cache"* ]]
    COLUMNS=200 run statusline "$EXTRAS"
    [[ "$output" == *"WT ui-redesign · PR #184 approved"* ]]
}

@test "wide: terminal widths 60 to 200 never overflow and always keep the agent tag" {
    for cols in 60 80 100 120 160 200; do
        run_rich "$cols"
        limit=$cols; (( cols >= 160 )) && limit=$((cols - 3))
        while IFS= read -r l; do
            [ "$(width "$l")" -le "$limit" ] || { echo "cols=$cols width=$(width "$l"): $l"; false; }
        done <<<"$out"
        [[ "$out" == *"◆ orch"* ]] || { echo "cols=$cols lost agent: $out"; false; }
        [[ "$out" == *"7d "*"92%"* ]] || { echo "cols=$cols lost 7d: $out"; false; }
        [[ "$out" == *"5h 88%"* ]] || { echo "cols=$cols lost urgent 5h: $out"; false; }
    done
    run_rich 120
    [ "$(wc -l <<<"$out")" -eq 3 ]
    run_rich 100
    [ "$(wc -l <<<"$out")" -eq 2 ]
}

@test "wide: no agent.name means no diamond and no invented label" {
    unset CLAUDE_STATUSLINE_WIDE_MIN
    COLUMNS=200 run statusline "$FULL"
    [[ "$output" != *"◆"* ]]
    [[ "${lines[0]}" == "advanced-gym ⎇ main │ Opus 5:H "* ]]
}

@test "wide: very long project or branch names fall back to the full layout, never overflow" {
    unset CLAUDE_STATUSLINE_WIDE_MIN
    longp=$(printf 'p%.0s' {1..50}); longb=$(printf 'b%.0s' {1..50})
    make_repo "$WORK/$longp" "$longb"
    out=$(jq -n --arg d "$WORK/$longp" '{cwd: $d, agent: {name: "orchestrator"}, model: {display_name: "Opus 5.5 (1M context)"},
            workspace: {project_dir: $d, current_dir: $d}, effort: {level: "high"},
            context_window: {total_input_tokens: 140000, context_window_size: 1000000, used_percentage: 14, remaining_percentage: 86},
            cost: {total_cost_usd: 1.5, total_duration_ms: 3600000}}' \
        | COLUMNS=160 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(wc -l <<<"$out")" -eq 3 ]
    while IFS= read -r l; do [ "$(width "$l")" -le 160 ]; done <<<"$out"
    [[ "$out" == *"◆ orchestrator"* ]]
    [[ "$out" == *"$longp"* && "$out" == *"$longb"* ]]
}

@test "wide: NO_COLOR prints no escape codes and the same rows" {
    unset CLAUDE_STATUSLINE_WIDE_MIN
    colored=$(COLUMNS=200 bash -c "$(declare -f rich rich_q make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich_q | bash '$SCRIPT'")
    plain=$(COLUMNS=200 NO_COLOR=1 bash -c "$(declare -f rich rich_q make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich_q | bash '$SCRIPT'")
    [[ "$plain" != *$'\033'* ]]
    [ "$(wc -l <<<"$plain")" -eq 2 ]
    [ "$plain" = "$(sed 's/\x1b\[[0-9;]*m//g' <<<"$colored")" ]
}

@test "wide: CLAUDE_STATUSLINE_MODE=wide pins it below the breakpoint; WIDE_MIN moves the breakpoint" {
    unset CLAUDE_STATUSLINE_WIDE_MIN
    withcost=$(jq -c '. + {cost: {total_cost_usd: 1.5, total_duration_ms: 3600000}}' <<<"$FULL")
    CLAUDE_STATUSLINE_MODE=wide COLUMNS=170 run statusline "$withcost"
    [ "${#lines[@]}" -eq 2 ]
    [[ "${lines[1]}" == *"Cost \$1.50 · Session 1h00m" ]]
    CLAUDE_STATUSLINE_WIDE_MIN=140 COLUMNS=150 run statusline "$withcost"
    [ "${#lines[@]}" -eq 2 ]
    CLAUDE_STATUSLINE_WIDE_MIN=100000 CLAUDE_STATUSLINE_MODE=full COLUMNS=200 run statusline "$withcost"
    [ "${#lines[@]}" -eq 3 ]
}

# ea_width <text>: display cells counting East Asian wide/fullwidth characters as 2
# (independent of the script's own width function).
ea_width() {
    python3 -I -c 'import sys, unicodedata
t = sys.argv[1]
print(sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in t))' "$1"
}

@test "wide: Hangul, fullwidth and emoji agent names keep every row inside the margin" {
    unset CLAUDE_STATUSLINE_WIDE_MIN
    for name in 한국어에이전트한국어에이전트한국어 ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴ ✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨; do
        for cols in 160 200; do
            out=$(payload "$(jq -n --arg n "$name" '{agent: {name: $n}, effort: {level: "high"},
                cost: {total_cost_usd: 1.5, total_duration_ms: 3600000}}')" \
                | COLUMNS=$cols bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
            [ "$(wc -l <<<"$out")" -eq 2 ] || { echo "$name cols=$cols: $out"; false; }
            while IFS= read -r l; do
                [ "$(ea_width "$l")" -eq $((cols - 3)) ] || { echo "$name cols=$cols ea_width=$(ea_width "$l"): $l"; false; }
            done <<<"$out"
        done
    done
}

@test "wide: an unknown or non-numeric COLUMNS never selects the wide layout" {
    unset CLAUDE_STATUSLINE_WIDE_MIN
    for setting in unset abc "" 1x; do
        if [ "$setting" = unset ]; then
            out=$(bash -c "$(declare -f rich rich_q make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich_q | env -u COLUMNS bash '$SCRIPT'" | sed 's/\x1b\[[0-9;]*m//g')
        else
            out=$(bash -c "$(declare -f rich rich_q make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich_q | COLUMNS='$setting' bash '$SCRIPT'" | sed 's/\x1b\[[0-9;]*m//g')
        fi
        [ "$(wc -l <<<"$out")" -eq 3 ] || { echo "COLUMNS=$setting: $out"; false; }
        while IFS= read -r l; do [ "$(width "$l")" -le 200 ] || { echo "COLUMNS=$setting: $l"; false; }; done <<<"$out"
    done
    # Pinning wide does not help when the width is unknown.
    out=$(CLAUDE_STATUSLINE_MODE=wide bash -c "$(declare -f rich rich_q make_repo session_file); WORK='$WORK' CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' rich_q | env -u COLUMNS bash '$SCRIPT'")
    [ "$(wc -l <<<"$out")" -eq 3 ]
}

@test "wide: the breakpoint is 160 columns (159 stays on the full layout)" {
    run_rich 159
    [ "$(wc -l <<<"$out")" -eq 3 ]
    run_rich 160
    [ "$(wc -l <<<"$out")" -eq 2 ]
}

@test "wide: a tight row gives up the bar first, then the resets and the Cost/Session labels" {
    export WIDE_MIN=100
    # With RC and the 5h quota the thresholds for this payload are 123 and 112.
    run_rich 123
    [[ "$out" == *"Ctx █"* && "$out" == *"↻1h24m"* && "$out" == *"Cost \$294.30 · Session 139h31m"* ]]
    run_rich 122
    [ "$(wc -l <<<"$out")" -eq 2 ]
    [[ "$out" != *"█"* && "$out" == *"Ctx 14%"* && "$out" == *"↻1h24m"* && "$out" == *"Cost \$294.30 · Session 139h31m"* ]]
    run_rich 112
    [[ "$out" != *"█"* && "$out" == *"↻1h24m"* && "$out" == *"Cost "* ]]
    run_rich 111
    [ "$(wc -l <<<"$out")" -eq 2 ]
    [[ "$out" != *"█"* && "$out" != *"↻"* && "$out" != *"Cost"* && "$out" != *"Session"* ]]
    [[ "$out" == *'$294.30 · 139h31m · Cache 97%' && "$out" == *"5h 88% · 7d 92%"* ]]
    while IFS= read -r l; do [ "$(width "$l")" -le 108 ]; done <<<"$out"
}

# --- Model and agent colours -------------------------------------------------------

# code_before <label> [payload-override]: the SGR parameters directly before
# <label> on row 1 (e.g. 38;5;69), or "none" when it is uncoloured.
code_before() {
    local raw
    raw=$(payload "${2:-{\}}" | bash "$SCRIPT" | head -1)
    if [[ "$raw" =~ $'\033'\[([0-9\;]*)m"$1" ]]; then printf %s "${BASH_REMATCH[1]}"; else printf none; fi
}

# lum <256-colour code>: integer luminance (0-255000) of a colour-cube or grey-ramp code,
# so tests can assert "brighter" without hard-coding the order of two numbers.
lum() {
    local n=$1 r g b lv=(0 95 135 175 215 255)
    if (( n >= 232 )); then echo $(( (8 + (n - 232) * 10) * 1000 )); return; fi
    (( n -= 16 )); r=${lv[n / 36]} g=${lv[(n / 6) % 6]} b=${lv[n % 6]}
    echo $(( 2126 * r + 7152 * g + 722 * b ))
}

@test "colour: model colour follows price tier, brightest for Fable; unknown families stay neutral" {
    mc() { code_before "$1" "{\"model\": {\"display_name\": \"$2\"}}"; }
    [ "$(mc Opus 'Opus 5.5')" = "38;5;39" ]
    [ "$(mc Sonnet 'Sonnet 5')" = "38;5;67" ]
    [ "$(mc Haiku 'Haiku 4.5')" = "38;5;62" ]
    # Fable (and Mythos) is the dearest family: brighter than Opus. Unknown: no price guessed.
    [ "$(mc Fable 'Fable 5.1')" = "38;5;45" ]
    [ "$(mc Mythos 'Mythos 1')" = "38;5;45" ]
    [ "$(mc Mystery 'Mystery 9')" = "none" ]
    # The version and the 1M-context suffix do not change the family colour.
    [ "$(mc Opus 'Opus 4 (1M context)')" = "38;5;39" ]
    # Brighter = dearer: Fable > Opus > Sonnet > Haiku, and one colour per tier.
    f=$(lum 45) o=$(lum 39) s=$(lum 67) h=$(lum 62)
    (( f > o && o > s && s > h )) || { echo "luminance fable=$f opus=$o sonnet=$s haiku=$h"; false; }
}

# effort_code <level> <label> [columns|mode]: the SGR parameters before the effort label.
effort_code() {
    COLUMNS=${3:-200} code_before "$2" "{\"effort\": {\"level\": \"$1\"}}"
}

@test "colour: effort brightness rises low to max on one hue ramp, in every layout" {
    export CLAUDE_STATUSLINE_WIDE_MIN=160
    [ "$(effort_code high high 140)" = "38;5;170" ]
    [ "$(effort_code high H 100)" = "38;5;170" ]
    [ "$(effort_code high H 60)" = "38;5;170" ]
    [ "$(CLAUDE_STATUSLINE_WIDE_MIN=160 effort_code high H 200)" = "38;5;170" ]
    declare -A want=([low]=96 [medium]=133 [high]=170 [xhigh]=207 [max]=213)
    declare -A label=([low]=L [medium]=M [high]=H [xhigh]=X [max]=max)
    prev=0
    for lvl in low medium high xhigh max; do
        c=$(effort_code "$lvl" "${label[$lvl]}" 100)
        [ "$c" = "38;5;${want[$lvl]}" ] || { echo "$lvl: $c"; false; }
        l=$(lum "${want[$lvl]}")
        (( l > prev )) || { echo "$lvl not brighter than the level below"; false; }
        prev=$l
    done
    # full layout colours the word, not the model name
    [ "$(effort_code max max 140)" = "38;5;213" ]
    # an unknown level is neutral
    [ "$(effort_code odd odd 140)" = "none" ]
}

@test "colour: the same model and agent keep their colour in every layout" {
    export CLAUDE_STATUSLINE_WIDE_MIN=160
    for cols in 200 140 100 60; do
        [ "$(COLUMNS=$cols code_before Opus '{"agent": {"name": "reviewer"}}')" = "38;5;39" ] || { echo "model cols=$cols"; false; }
        [ "$(COLUMNS=$cols code_before '◆ ' '{"agent": {"name": "reviewer"}}')" = "38;5;179" ] || { echo "agent cols=$cols"; false; }
    done
    for mode in wide full compact minimal; do
        [ "$(CLAUDE_STATUSLINE_MODE=$mode COLUMNS=200 code_before Opus '{"agent": {"name": "reviewer"}}')" = "38;5;39" ] || { echo "mode=$mode"; false; }
    done
}

# agent_def <dir> <name> <frontmatter-colour-line-or-empty>: a fixture agent file.
agent_def() {
    mkdir -p "$1/.claude/agents"
    { echo '---'; echo "name: $2"; echo 'description: fixture'; [ -z "${3:-}" ] || echo "$3"; echo '---'; echo 'body'; echo 'color: red'; } >"$1/.claude/agents/$2.md"
}

# Claude Code colour names -> the 256-colour code this status line uses.
# (declared per test: bats sources this file inside a function, so a top-level declare is not global)
colour_codes() { declare -gA CODE=([red]=131 [blue]=75 [green]=108 [yellow]=179 [purple]=140 [orange]=173 [pink]=175 [cyan]=37); }

@test "colour: an agent takes the colour named by color: in its project definition file" {
    colour_codes
    [ "${#CODE[@]}" -eq 8 ]
    for c in "${!CODE[@]}"; do
        agent_def "$REPO" "fx-$c" "color: $c"
        out=$(code_before '◆ ' "{\"agent\": {\"name\": \"fx-$c\"}}")
        [ "$out" = "38;5;${CODE[$c]}" ] || { echo "$c: $out"; false; }
    done
    # case, quotes and trailing spaces are tolerated
    agent_def "$REPO" fx-q 'color: "Cyan"  '
    [ "$(code_before '◆ ' '{"agent": {"name": "fx-q"}}')" = "38;5;37" ]
    # the project file wins over a user-level one
    mkdir -p "$CLAUDE_CONFIG_DIR/agents"
    printf -- '---\ncolor: pink\n---\n' >"$CLAUDE_CONFIG_DIR/agents/fx-both.md"
    agent_def "$REPO" fx-both 'color: green'
    [ "$(code_before '◆ ' '{"agent": {"name": "fx-both"}}')" = "38;5;108" ]
}

@test "colour: without a project file the user-level definition is used (CLAUDE_CONFIG_DIR or ~/.claude)" {
    mkdir -p "$CLAUDE_CONFIG_DIR/agents"
    printf -- '---\nname: fx-user\ncolor: orange\n---\n' >"$CLAUDE_CONFIG_DIR/agents/fx-user.md"
    [ "$(code_before '◆ ' '{"agent": {"name": "fx-user"}}')" = "38;5;173" ]
    # without CLAUDE_CONFIG_DIR the lookup is $HOME/.claude/agents
    mkdir -p "$BATS_TEST_TMPDIR/home/.claude/agents"
    printf -- '---\nname: fx-home\ncolor: pink\n---\n' >"$BATS_TEST_TMPDIR/home/.claude/agents/fx-home.md"
    raw=$(payload '{"agent": {"name": "fx-home"}}' | env -u CLAUDE_CONFIG_DIR HOME="$BATS_TEST_TMPDIR/home" bash "$SCRIPT" | head -1)
    [[ "$raw" == $'\033[38;5;175m◆ fx-home'* ]]
}

@test "colour: an unknown colour, a missing file, no frontmatter or a body-only color: fall back to the table, then the hash" {
    agent_def "$REPO" reviewer 'color: chartreuse'
    [ "$(code_before '◆ ' '{"agent": {"name": "reviewer"}}')" = "38;5;179" ]          # fixed table: yellow
    [ "$(code_before '◆ ' '{"agent": {"name": "mystery"}}')" = "38;5;138" ]           # hash, no file
    mkdir -p "$REPO/.claude/agents"
    printf 'name: nofront\ncolor: red\n' >"$REPO/.claude/agents/nofront.md"           # no --- fence
    [ "$(code_before '◆ ' '{"agent": {"name": "nofront"}}')" != "38;5;131" ]
    agent_def "$REPO" bodyonly ''                                                    # color: only after the fence
    [ "$(code_before '◆ ' '{"agent": {"name": "bodyonly"}}')" != "38;5;131" ]
}

@test "colour: the first definition file that exists decides, so a project file shadows the user-level one" {
    mkdir -p "$CLAUDE_CONFIG_DIR/agents"
    printf -- '---\ncolor: pink\n---\n' >"$CLAUDE_CONFIG_DIR/agents/shadow.md"
    agent_def "$REPO" shadow 'color: chartreuse'                  # unknown colour: fallback, not pink
    [ "$(code_before '◆ ' '{"agent": {"name": "shadow"}}')" = "38;5;$(hash_code shadow)" ]
    printf -- '---\ncolor: red\n---\n' >"$CLAUDE_CONFIG_DIR/agents/shadow2.md"
    agent_def "$REPO" shadow2 ''                                  # no colour line: fallback, not red
    [ "$(code_before '◆ ' '{"agent": {"name": "shadow2"}}')" = "38;5;$(hash_code shadow2)" ]
    # a project file without frontmatter is not a definition: the user-level one is used
    printf 'no fence\n' >"$REPO/.claude/agents/shadow3.md"
    printf -- '---\ncolor: cyan\n---\n' >"$CLAUDE_CONFIG_DIR/agents/shadow3.md"
    [ "$(code_before '◆ ' '{"agent": {"name": "shadow3"}}')" = "38;5;37" ]
}

# hash_code <name>: the palette colour the name hash gives (the no-file fallback).
hash_code() {
    local n=${1,,} sum=0 c i palette=(74 103 109 116 133 138 143 152)
    for (( i = 0; i < ${#n}; i++ )); do printf -v c %d "'${n:i:1}"; sum=$(( sum + c )); done
    echo "${palette[sum % 8]}"
}

@test "colour: a definition file with one huge line is read in bounded time" {
    mkdir -p "$REPO/.claude/agents"
    { printf -- '---\n'; head -c 3000000 /dev/zero | tr '\0' 'a'; printf '\ncolor: red\n---\n'; } >"$REPO/.claude/agents/huge.md"
    start=$SECONDS
    out=$(payload '{"agent": {"name": "huge"}}' | timeout 10 bash "$SCRIPT" | head -1)
    [ $(( SECONDS - start )) -lt 5 ]
    [[ "$out" == *"◆ huge"* ]]
}

@test "colour: a Windows-style (backslash) workspace path fails safe: no stderr, fallback colour" {
    for d in 'C:\Users\x\proj' '/c/Users/x/proj' 'C:\Users\x\proj\'; do
        err=$(payload "$(jq -n --arg d "$d" '{agent: {name: "reviewer"}, workspace: {project_dir: $d, current_dir: $d}}')" \
            | bash "$SCRIPT" 2>&1 >"$BATS_TEST_TMPDIR/out")
        [ -z "$err" ] || { echo "stderr for $d: $err"; false; }
        [[ "$(head -1 "$BATS_TEST_TMPDIR/out")" == $'\033[38;5;179m◆ reviewer'* ]] || { echo "$d"; false; }
    done
}

@test "colour: an agent name that is not a plain file name never reads a file" {
    mkdir -p "$WORK/outside" "$REPO/.claude/agents"
    printf -- '---\ncolor: red\n---\n' >"$WORK/outside/x.md"
    printf -- '---\ncolor: red\n---\n' >"$REPO/.claude/agents/.dot.md"
    for n in '../../../outside/x' '../x' 'a/b' '.dot' '..'; do
        out=$(code_before '◆ ' "$(jq -n --arg n "$n" '{agent: {name: $n}}')")
        [[ "$out" =~ ^38\;5\;[0-9]+$ ]] || { echo "$n: $out"; false; }
        [ "$out" != "38;5;131" ] || { echo "$n read a file outside agents/"; false; }
    done
}

@test "colour: known Glyphbrace agents follow the fixed table when no file is present; distinct colours per name" {
    colour_codes
    declare -A want=([orchestrator]=purple [architect]=blue [plan-writer]=blue [implementer]=green
        [super-implementer]=green [configuration-maintainer]=green [local-maintainer]=green
        [reviewer]=yellow [agent-definition-reviewer]=yellow [researcher]=cyan [fleet-assessor]=cyan
        [phoenix-analyzer]=cyan [release-auditor]=red [agent-factory]=pink)
    for a in "${!want[@]}"; do
        c=$(code_before '◆ ' "{\"agent\": {\"name\": \"$a\"}}")
        [ "$c" = "38;5;${CODE[${want[$a]}]}" ] || { echo "$a: $c"; false; }
    done
    # Unknown names: same name, same colour on every run; case does not matter.
    a1=$(code_before '◆ ' '{"agent": {"name": "mystery"}}')
    a2=$(code_before '◆ ' '{"agent": {"name": "mystery"}}')
    a3=$(code_before '◆ ' '{"agent": {"name": "Mystery"}}')
    [ "$a1" = "$a2" ]; [ "$a1" = "$a3" ]
    [ "$a1" = "38;5;138" ]
    [[ "$(code_before '◆ ' '{"agent": {"name": "zebra"}}')" =~ ^38\;5\;[0-9]+$ ]]
}

@test "colour: the agent lookup adds at most two forks to a render" {
    command -v strace >/dev/null || skip "strace not available"
    count() {
        payload "$1" >"$BATS_TEST_TMPDIR/p.json"
        strace -f -qq -e trace=clone,clone3,fork,vfork -o "$BATS_TEST_TMPDIR/st" bash "$SCRIPT" <"$BATS_TEST_TMPDIR/p.json" >/dev/null
        wc -l <"$BATS_TEST_TMPDIR/st"
    }
    agent_def "$REPO" fx-fork 'color: cyan'
    base=$(count '{}'); with=$(count '{"agent": {"name": "fx-fork"}}')
    (( with - base <= 2 )) || { echo "base=$base with-agent=$with"; false; }
}

@test "colour: model and agent colours never use the reserved warning codes" {
    for a in orchestrator researcher architect implementer reviewer plan-writer release-auditor agent-factory mystery zebra qa-bot; do
        c=$(code_before '◆ ' "{\"agent\": {\"name\": \"$a\"}}")
        case "$c" in 0\;31|0\;33|0\;32|1\;31|38\;5\;208) false ;; esac
    done
}

@test "colour: NO_COLOR keeps agent and model names as text without escape codes" {
    out=$(payload '{"agent": {"name": "reviewer"}}' | NO_COLOR=1 bash "$SCRIPT")
    [[ "$out" != *$'\033'* ]]
    [[ "$out" == *"◆ reviewer"*"Opus 5"* ]]
}


@test "colour: a long agent name is coloured by its full name, not the shortened label" {
    long=abcdefghijklmnopqrstuvwxyz-long-agent-name-d
    # character-code sum of the full name mod 8 picks the palette slot
    sum=0; for ((i = 0; i < ${#long}; i++)); do printf -v c %d "'${long:i:1}"; sum=$((sum + c)); done
    palette=(74 103 109 116 133 138 143 152)
    [ "$(code_before '◆ ' "$(jq -n --arg n "$long" '{agent: {name: $n}}')")" = "38;5;${palette[sum % 8]}" ]
}

@test "minimal: the agent tag goes only when dropping it makes the row fit" {
    # 13 columns: "Opus │ 7d 92%" fits only without the tag, so it is dropped.
    out=$(rich | COLUMNS=13 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 1p)
    [ "$out" = "Opus │ 7d 92%" ]
    # 12 columns: nothing fits either way (the 92% quota is never dropped), so the tag stays.
    out=$(rich | COLUMNS=12 bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 1p)
    [[ "$out" == *"◆ orch"* ]]
}
