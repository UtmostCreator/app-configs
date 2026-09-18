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
    WORK="$BATS_TEST_TMPDIR"
    REPO="$WORK/advanced-gym"
    make_repo "$REPO" main
}

# make_repo <dir> <branch>: a repo with one commit on <branch>.
make_repo() {
    git init -q -b "$2" "$1"
    git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
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

# --- Main line ----------------------------------------------------------------

@test "wide: dirty branch, diff, effort, real context %, LONG, 5h and 7d quota" {
    touch "$REPO/untracked.txt"
    run statusline "$FULL"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "$output" = "advanced-gym ⎇ main* +428/-91 | Opus 5 · effort:high | Ctx 55% · 548k/1M · LONG | 5h 72% ↻1h24m · 7d 41% ↻Tue" ]
}

@test "clean tree has no dirty marker and no diff segment when nothing changed" {
    run statusline '{"cost": {"total_lines_added": 0, "total_lines_removed": 0}}'
    [ "$status" -eq 0 ]
    [[ "$output" == "advanced-gym ⎇ main | Opus 5 | "* ]]
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
    touch "$REPO/untracked.txt"
    export COLUMNS=80
    run statusline "$(jq -n --argjson a "$FULL" --argjson b "$EXTRAS" '$a * $b')"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = "advanced-gym ⎇ main* | Opus 5:high | Ctx 55% | 5h 72% | 7d 41%" ]
    [ "${lines[1]}" = "+428/-91 · WT ui-redesign · PR #184 approved" ]
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
