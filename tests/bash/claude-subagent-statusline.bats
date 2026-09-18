#!/usr/bin/env bats
# Tests for home/dot_claude/executable_subagent-statusline.sh — the per-agent
# rows in Claude Code's agent panel (settings.json `subagentStatusLine`).
#
# Contract (Claude Code statusline docs): stdin is one JSON object with
# `columns` and `tasks[]` ({id, name, type, status, description, label,
# startTime (epoch ms), model, effort, contextWindowSize, tokenCount, cwd});
# stdout is one {"id", "content"} JSON line per row to override.
#
# Deterministic: the clock is pinned via STATUSLINE_NOW (epoch seconds).
#
# Run:  bats tests/bash/claude-subagent-statusline.bats

NOW=1738420000

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/home/dot_claude/executable_subagent-statusline.sh"
    [ -f "$SCRIPT" ]
    export STATUSLINE_NOW=$NOW
}

# rows <input-json>: run the script, print "id=content" per line, ANSI stripped.
rows() {
    bash "$SCRIPT" <<<"$1" | jq -r '"\(.id)=\(.content)"' | sed 's/\x1b\[[0-9;]*m//g'
}

# task <id> <name> <model> <effort> <status> <tokens> <window> <age-seconds>
task() {
    jq -n --arg id "$1" --arg name "$2" --arg model "$3" --arg effort "$4" \
        --arg status "$5" --argjson tokens "$6" --argjson window "$7" \
        --argjson start "$(( (NOW - $8) * 1000 ))" '{
            id: $id, name: $name, type: "local_agent", status: $status,
            description: "desc", startTime: $start, tokenCount: $tokens, cwd: "/tmp"
        }
        + (if $model  == "" then {} else {model: $model} end)
        + (if $effort == "" then {} else {effort: $effort} end)
        + (if $window == 0  then {} else {contextWindowSize: $window} end)'
}

FOUR_AGENTS() {
    jq -n --argjson cols 120 \
        --argjson a "$(task a1 Explore      claude-sonnet-5   high  running    48000 200000 102)" \
        --argjson b "$(task a2 UI-review    'claude-opus-5[1m]' xhigh running 142000 200000 258)" \
        --argjson c "$(task a3 Tests        claude-sonnet-5   high  completed  72000 200000 126)" \
        --argjson d "$(task a4 Architecture claude-opus-5     max   running   168000 200000 451)" \
        '{columns: $cols, tasks: [$a, $b, $c, $d]}'
}

@test "aligned rows: name, model, effort, status, context %, elapsed while running" {
    run rows "$(FOUR_AGENTS)"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [ "${lines[0]}" = "a1=Explore      Sonnet 5 · high  · ▶ 24% · 1m42" ]
    [ "${lines[1]}" = "a2=UI-review    Opus 5   · xhigh · ▶ 71% · 4m18" ]
    [ "${lines[2]}" = "a3=Tests        Sonnet 5 · high  · ✓ 36%" ]
    [ "${lines[3]}" = "a4=Architecture Opus 5   · max   · ▶ 84% ⚠ · 7m31" ]
}

@test "every output line is valid {id, content} JSON" {
    run bash -c "bash '$SCRIPT' | jq -e 'has(\"id\") and has(\"content\")' >/dev/null" <<<"$(FOUR_AGENTS)"
    [ "$status" -eq 0 ]
}

@test "model names: fable point releases, dated haiku ids" {
    input=$(jq -n \
        --argjson a "$(task f Fable claude-fable-5-1 high running 1000 1000000 5)" \
        --argjson b "$(task h Haiku claude-haiku-4-5-20251001 low failed 1000 200000 5)" \
        '{columns: 120, tasks: [$a, $b]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "f=Fable Fable 5.1 · high · ▶ 0% · 5s" ]
    [ "${lines[1]}" = "h=Haiku Haiku 4.5 · low  · ✗ 1%" ]
}

@test "inherited effort, unresolved model, and hours-long runtime" {
    input=$(jq -n --argjson a "$(task p Pending '' '' pending 12000 0 3720)" '{columns: 120, tasks: [$a]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "p=Pending inherit · ◷ 12k tok · 1h02" ]
}

@test "numeric effort budget and killed status" {
    input=$(jq -n --argjson a "$(task k Budget claude-sonnet-5 '' killed 20000 200000 60)" \
        '{columns: 120, tasks: [$a | .effort = 32000]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "k=Budget Sonnet 5 · 32k · ■ 10%" ]
}

@test "falls back to label, then description, when name is missing" {
    input=$(jq -n \
        --argjson a "$(task l x claude-sonnet-5 high running 0 200000 1 | jq 'del(.name) | .label = "Lint"')" \
        --argjson b "$(task d x claude-sonnet-5 high running 0 200000 1 | jq 'del(.name)')" \
        '{columns: 120, tasks: [$a, $b]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "l=Lint Sonnet 5 · high · ▶ 0% · 1s" ]
    [ "${lines[1]}" = "d=desc Sonnet 5 · high · ▶ 0% · 1s" ]
}

@test "long names are truncated to keep rows aligned" {
    input=$(jq -n --argjson a "$(task t a-very-long-agent-name-here claude-sonnet-5 high running 0 200000 1)" \
        '{columns: 120, tasks: [$a]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "t=a-very-long-ag… Sonnet 5 · high · ▶ 0% · 1s" ]
}

@test "narrow panel keeps only name, status, and context %" {
    run rows "$(FOUR_AGENTS | jq '.columns = 50')"
    [ "$status" -eq 0 ]
    [ "${lines[3]}" = "a4=Architecture ▶ 84% ⚠" ]
    [ "${lines[2]}" = "a3=Tests        ✓ 36%" ]
}

@test "no tasks prints nothing" {
    run bash "$SCRIPT" <<<'{"columns": 120, "tasks": []}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
