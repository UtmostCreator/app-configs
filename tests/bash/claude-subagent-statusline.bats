#!/usr/bin/env bats
# Tests for home/dot_claude/executable_subagent-statusline.sh — the per-agent
# rows in Claude Code's agent panel (settings.json `subagentStatusLine`).
#
# Contract (Claude Code statusline docs): stdin is one JSON object with
# `columns` and `tasks[]` ({id, name, type, status, description, label,
# startTime (epoch ms), model, effort, contextWindowSize, tokenCount, cwd});
# stdout is one {"id", "content"} JSON line per row to override.
# Row order: status glyph, agent type (#n when several share a type), runtime,
# context, model:effort, task.
#
# Deterministic: the clock is pinned via STATUSLINE_NOW (epoch seconds).
#
# Run:  bats tests/bash/claude-subagent-statusline.bats

NOW=1738420000

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/home/dot_claude/executable_subagent-statusline.sh"
    [ -f "$SCRIPT" ]
    export STATUSLINE_NOW=$NOW LC_ALL=C.UTF-8
    unset NO_COLOR
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

@test "aligned rows: glyph, name, runtime, context, model and effort in fixed columns" {
    run rows "$(FOUR_AGENTS)"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [ "${lines[0]}" = "a1=▶ Explore      1m42 · ctx 24%   │ Sonnet 5:H" ]
    [ "${lines[1]}" = "a2=▶ UI-review    4m18 · ctx 71%   │ Opus 5:X" ]
    [ "${lines[2]}" = "a3=✓ Tests             · ctx 36%   │ Sonnet 5:H" ]
    [ "${lines[3]}" = "a4=▶ Architecture 7m31 · ctx 84% ! │ Opus 5:max" ]
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
    [ "${lines[0]}" = "f=▶ Fable 5s · ctx 0% │ Fable 5.1:H" ]
    [ "${lines[1]}" = "h=✗ Haiku    · ctx 1% │ Haiku 4.5:L" ]
}

@test "unresolved model shows inherit; no window size shows the raw token count, never a fake %" {
    input=$(jq -n --argjson a "$(task p Pending '' '' pending 12000 0 3720)" '{columns: 120, tasks: [$a]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "p=◷ Pending 1h02 · tok 12k │ inherit" ]
    input=$(jq -n --argjson a "$(task t Tok claude-opus-5 high running 298000 0 5)" '{columns: 120, tasks: [$a]}')
    run rows "$input"
    [ "$output" = "t=▶ Tok 5s · tok 298k │ Opus 5:H" ]
    [[ "$output" != *"ctx"* ]]
}

@test "no token count at all: no context field is invented" {
    input=$(jq -n --argjson a "$(task n None claude-opus-5 high running 0 200000 5 | jq 'del(.tokenCount)')" '{columns: 120, tasks: [$a]}')
    run rows "$input"
    [ "$output" = "n=▶ None 5s │ Opus 5:H" ]
}

@test "numeric effort budget and killed status" {
    input=$(jq -n --argjson a "$(task k Budget claude-sonnet-5 '' killed 20000 200000 60)" \
        '{columns: 120, tasks: [$a | .effort = 32000]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "k=■ Budget ctx 10% │ Sonnet 5:32k" ]
}

@test "falls back to label, then description, when name is missing" {
    input=$(jq -n \
        --argjson a "$(task l x claude-sonnet-5 high running 0 200000 1 | jq 'del(.name) | .label = "Lint"')" \
        --argjson b "$(task d x claude-sonnet-5 high running 0 200000 1 | jq 'del(.name)')" \
        '{columns: 120, tasks: [$a, $b]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "l=▶ Lint 1s · ctx 0% │ Sonnet 5:H" ]
    [ "${lines[1]}" = "d=▶ desc 1s · ctx 0% │ Sonnet 5:H" ]
}

@test "long names are truncated to keep rows aligned" {
    input=$(jq -n --argjson a "$(task t a-very-long-agent-name-here claude-sonnet-5 high running 0 200000 1)" \
        '{columns: 120, tasks: [$a]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "t=▶ a-very-long-ag… 1s · ctx 0% │ Sonnet 5:H" ]
}

@test "agents sharing a type are numbered #1, #2 by start time then id; singletons are not" {
    input=$(jq -n \
        --argjson a "$(real_task reviewer 'later' | jq '.id = "z1" | .startTime = (.startTime + 5000)')" \
        --argjson b "$(real_task reviewer 'earlier' | jq '.id = "z2" | .startTime = (.startTime - 5000)')" \
        --argjson c "$(real_task reviewer 'tie-b' | jq '.id = "b9"')" \
        --argjson d "$(real_task reviewer 'tie-a' | jq '.id = "a9"')" \
        --argjson e "$(real_task researcher 'solo' | jq '.id = "s1"')" \
        '{columns: 160, tasks: [$a, $b, $c, $d, $e]}')
    run rows "$input"
    [[ "${lines[0]}" == "z1=▶ reviewer #4"* ]]
    [[ "${lines[1]}" == "z2=▶ reviewer #1"* ]]
    [[ "${lines[2]}" == "b9=▶ reviewer #3"* ]]
    [[ "${lines[3]}" == "a9=▶ reviewer #2"* ]]
    [[ "${lines[4]}" == "s1=▶ researcher "* && "${lines[4]}" != *"#"*"researcher"* && "${lines[4]}" != "s1=▶ researcher #"* ]]
}

@test "narrow panel (below 60 columns): glyph, name, compact model tag with effort initial, context" {
    run rows "$(FOUR_AGENTS | jq '.columns = 50')"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "a1=▶ Explore      Son 5:H    ctx 24%" ]
    [ "${lines[1]}" = "a2=▶ UI-review    Opus 5:X   ctx 71%" ]
    [ "${lines[2]}" = "a3=✓ Tests        Son 5:H    ctx 36%" ]
    [ "${lines[3]}" = "a4=▶ Architecture Opus 5:max ctx 84% !" ]
}

@test "narrow panel: compact tags for Sonnet 4.6, Haiku 4.5, and no effort initial when inherited" {
    run rows "$(jq -n --argjson a "$(task s Son claude-sonnet-4-6 '' running 1000 200000 5)" '{columns: 50, tasks: [$a]}')"
    [ "$status" -eq 0 ]
    [ "$output" = "s=▶ Son Son 4.6 ctx 1%" ]
    run rows "$(jq -n --argjson a "$(task h Haiku claude-haiku-4-5-20251001 low failed 1000 200000 5)" '{columns: 50, tasks: [$a]}')"
    [ "$output" = "h=✗ Haiku Haiku 4.5:L ctx 1%" ]
}

@test "narrow panel: the effort initial is kept or dropped for every row at once" {
    run rows "$(FOUR_AGENTS | jq '.columns = 28')"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "a1=▶ Explore      Son 5  ctx 24%" ]
    [ "${lines[1]}" = "a2=▶ UI-review    Opus 5 ctx 71%" ]
    [ "${lines[2]}" = "a3=✓ Tests        Son 5  ctx 36%" ]
    [ "${lines[3]}" = "a4=▶ Architecture Opus 5 ctx 84% !" ]
}

@test "narrow panel: a task without a model shows no tag" {
    input=$(jq -n --argjson a "$(task n Nomodel '' high running 1000 200000 5)" '{columns: 50, tasks: [$a]}')
    run rows "$input"
    [ "${lines[0]}" = "n=▶ Nomodel ctx 1%" ]
}

@test "no tasks prints nothing" {
    run bash "$SCRIPT" <<<'{"columns": 120, "tasks": []}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# Shape captured from Claude Code 2.1.325 (sanitised): no `name`; the agent type
# is `agentType`, the task text is `label`; the session's own agent is the
# top-level `agent_type`. Inherited-model agents still carry `model`.
real_task() {
    jq -n --arg type "$1" --arg label "$2" --argjson start "$(( (NOW - 1) * 1000 ))" '{
        id: "aad0147d1d0ef9f0e", type: "local_agent", status: "running",
        agentType: $type, label: $label, description: "desc",
        model: "claude-sonnet-5-5", effort: "high", contextWindowSize: 1000000,
        tokenCount: 1200, startTime: $start, tokenSamples: [], cwd: "/tmp"}'
}

@test "real payload: type, runtime, context, model and the task label in that order" {
    input=$(jq -n --argjson a "$(real_task reviewer 'Check delegation nesting')" \
        '{columns: 167, agent_type: "orchestrator", tasks: [$a]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "$output" = "aad0147d1d0ef9f0e=▶ reviewer 1s · ctx 0% │ Sonnet 5.5:H │ Check delegation nesting" ]
}

@test "real payload: narrow panel drops the task label but keeps type and model" {
    input=$(jq -n --argjson a "$(real_task reviewer 'Check delegation nesting')" \
        '{columns: 50, tasks: [$a]}')
    run rows "$input"
    [ "$output" = "aad0147d1d0ef9f0e=▶ reviewer Son 5.5:H ctx 0%" ]
}

@test "colour: a known agent type and its model family are coloured, unknown types hash to a palette colour" {
    input=$(jq -n --argjson a "$(real_task reviewer x)" --argjson b "$(real_task mystery x)" \
        '{columns: 167, tasks: [$a, $b]}')
    run bash -c "bash '$SCRIPT' <<<'$input' | jq -r .content"
    [ "${lines[0]}" = "$(printf '\033[0;34m▶\033[0m \033[38;5;179mreviewer\033[0m 1s · \033[0;32mctx 0%%\033[0m │ \033[38;5;67mSonnet 5.5\033[0m:\033[38;5;170mH\033[0m │ x')" ]
    # Unknown types hash to a palette colour: 797 (sum of the character codes) % 8 = 5, 138.
    [[ "${lines[1]}" == *$'\033[38;5;138mmystery \033[0m'* ]]
}

@test "colour: narrow fit is decided on visible width: exact fit keeps the effort initial, one less drops it" {
    input=$(jq -n --argjson a "$(real_task reviewer x)" '{columns: 27, tasks: [$a]}')
    run rows "$input"
    [ "$output" = "aad0147d1d0ef9f0e=▶ reviewer Son 5.5:H ctx 0%" ]
    run rows "$(jq '.columns = 26' <<<"$input")"
    [ "$output" = "aad0147d1d0ef9f0e=▶ reviewer Son 5.5 ctx 0%" ]
}

# visible_widths <input-json>: display width of each row's content, ANSI stripped.
visible_widths() {
    bash "$SCRIPT" <<<"$1" | jq -r '.content' | sed 's/\x1b\[[0-9;]*m//g' | while IFS= read -r l; do printf '%s\n' "${#l}"; done
}

@test "width: rows with a long task label never exceed columns (60-167)" {
    long='A very long task description that keeps going well past any sensible panel width'
    for cols in 60 70 80 99 100 120 167; do
        input=$(jq -n --argjson a "$(real_task reviewer "$long")" --argjson b "$(real_task researcher "$long" | jq '.id = "b"')" \
            --argjson c "$cols" '{columns: $c, tasks: [$a, $b]}')
        while read -r w; do
            [ "$w" -le "$cols" ] || { echo "cols=$cols width=$w"; false; }
        done < <(visible_widths "$input")
    done
}

@test "width: a task label is dropped when fewer than 8 columns remain" {
    input=$(jq -n --argjson a "$(real_task reviewer 'Some task')" '{columns: 60, tasks: [$a]}')
    run rows "$input"
    [[ "$output" == *"│ Some task" ]]
    run rows "$(jq '.columns = 51' <<<"$input")"
    [[ "$output" != *"Some task"* ]]
}

@test "robustness: missing status, non-string type and control characters do not blank the panel" {
    input=$(jq -n --argjson a "$(real_task reviewer 'x')" \
        '{columns: 120, tasks: [($a | del(.status)), ($a | .agentType = 42 | .id = "n"), ($a | .id = "c" | .label = "a\u001b[31mb\u0007c")]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 3 ]
    [[ "${lines[2]}" == *"│ a[31mbc" ]]
}

@test "parity: both scripts use the same colour for every agent type and the default" {
    MAIN="$REPO_ROOT/home/dot_claude/executable_statusline.sh"
    export GIT_CONFIG_GLOBAL=/dev/null CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/c" XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR" STATUSLINE_GIT_TTL=0 COLUMNS=200
    for t in researcher architect implementer super-implementer reviewer orchestrator plan-writer release-auditor agent-factory agent-definition-reviewer configuration-maintainer local-maintainer fleet-assessor phoenix-analyzer mystery; do
        sub=$(bash "$SCRIPT" <<<"$(jq -n --argjson a "$(real_task "$t" x)" '{columns: 167, tasks: [$a]}')" \
            | jq -r .content | sed -E 's/^\x1b\[[0-9;]*m[^\x1b]*\x1b\[0m \x1b\[([0-9;]*)m.*/\1/')
        main=$(jq -n --arg t "$t" '{cwd: "/nonexistent", agent: {name: $t}}' | bash "$MAIN" | head -1 \
            | sed -E 's/^\x1b\[([0-9;]*)m.*/\1/')
        [ -n "$sub" ]
        [ "$sub" = "$main" ] || { echo "$t: subagent=$sub main=$main"; false; }
    done
}

# main_code <payload-json> <label>: the SGR parameters directly before <label> in the
# main renderer's first row. sub_code <task-json> <label>: the same in the subagent row.
main_code() {
    jq -c . <<<"$1" | COLUMNS=200 bash "$REPO_ROOT/home/dot_claude/executable_statusline.sh" | head -1 \
        | sed -nE "s/.*\x1b\[([0-9;]*)m$2.*/\1/p" | head -1
}
sub_code() {
    bash "$SCRIPT" <<<"$(jq -n --argjson a "$1" '{columns: 200, tasks: [$a]}')" | jq -r .content \
        | sed -nE "s/.*\x1b\[([0-9;]*)m$2.*/\1/p" | head -1
}

@test "parity: both scripts colour every model family the same way; Fable is the brightest, unknown models stay plain" {
    export GIT_CONFIG_GLOBAL=/dev/null CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/c" XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR" STATUSLINE_GIT_TTL=0
    for pair in opus:Opus:38\;5\;39 sonnet:Sonnet:38\;5\;67 haiku:Haiku:38\;5\;62 fable:Fable:38\;5\;45 mythos:Mythos:38\;5\;45; do
        IFS=: read -r id name want <<<"$pair"
        sub=$(sub_code "$(real_task reviewer x | jq --arg m "claude-$id-5" '.model = $m')" "$name")
        main=$(main_code "{\"cwd\": \"/nonexistent\", \"model\": {\"display_name\": \"$name 5\"}}" "$name")
        [ "$sub" = "$main" ] || { echo "$name: subagent=$sub main=$main"; false; }
        [ "$sub" = "${want//\\/}" ] || { echo "$name: $sub"; false; }
    done
    # An unknown family carries no colour code in either renderer.
    [ -z "$(main_code '{"cwd": "/nonexistent", "model": {"display_name": "Mystery 9"}}' Mystery)" ]
    [ -z "$(sub_code "$(real_task reviewer x | jq '.model = "claude-mystery-9"')" Mystery)" ]
}

@test "parity: both scripts colour every effort level the same way, brightness rising low to max" {
    export GIT_CONFIG_GLOBAL=/dev/null CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/c" XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR" STATUSLINE_GIT_TTL=0
    for pair in low:L:96 medium:M:133 high:H:170 xhigh:X:207 max:max:213; do
        IFS=: read -r lvl lab want <<<"$pair"
        sub=$(sub_code "$(real_task reviewer x | jq --arg e "$lvl" '.effort = $e')" "$lab")
        main=$(main_code "{\"cwd\": \"/nonexistent\", \"effort\": {\"level\": \"$lvl\"}}" "$lab")
        [ "$sub" = "38;5;$want" ] || { echo "$lvl sub=$sub"; false; }
        [ "$main" = "38;5;$want" ] || { echo "$lvl main=$main"; false; }
    done
    # narrow panel colours the initial too; an unknown level and a numeric budget stay plain
    narrow=$(bash "$SCRIPT" <<<"$(jq -n --argjson a "$(real_task reviewer x | jq '.effort = "high"')" '{columns: 50, tasks: [$a]}')" | jq -r .content)
    [[ "$narrow" == *$'\033[38;5;170mH\033[0m'* ]]
    [ -z "$(sub_code "$(real_task reviewer x | jq '.effort = "odd"')" odd)" ]
}

@test "parity: names hitting all eight palette slots and a name over 20 characters get the same colour" {
    export GIT_CONFIG_GLOBAL=/dev/null CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/c" XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR" STATUSLINE_GIT_TTL=0
    declare -A slots
    # Single letters: character code mod 8 runs through 0-7 (h=104 -> 0, a=97 -> 1 ... g=103 -> 7).
    for t in h a b c d e f g abcdefghijklmnopqrstuvwxyz-long-agent-name-d; do
        sub=$(bash "$SCRIPT" <<<"$(jq -n --argjson a "$(real_task "$t" x)" '{columns: 167, tasks: [$a]}')" \
            | jq -r .content | sed -E 's/^\x1b\[[0-9;]*m[^\x1b]*\x1b\[0m \x1b\[([0-9;]*)m.*/\1/')
        main=$(jq -n --arg t "$t" '{cwd: "/nonexistent", agent: {name: $t}}' | COLUMNS=200 bash "$REPO_ROOT/home/dot_claude/executable_statusline.sh" | head -1 \
            | sed -E 's/^\x1b\[([0-9;]*)m.*/\1/')
        [[ "$sub" =~ ^38\;5\;[0-9]+$ ]]
        [ "$sub" = "$main" ] || { echo "$t: subagent=$sub main=$main"; false; }
        slots[$sub]=1
    done
    # The nine names produced exactly the eight palette colours.
    [ "${#slots[@]}" -eq 8 ]
    for c in 74 103 109 116 133 138 143 152; do [ -n "${slots[38;5;$c]:-}" ] || { echo "palette slot $c never hit"; false; }; done
}

# --- Colour scales ---------------------------------------------------------------------

# code_of <age-seconds-or-pct-kind> ...: helpers pulling an SGR code out of raw output.
age_code() {
    local raw
    raw=$(NO_COLOR="${2:-}" bash "$SCRIPT" <<<"$(jq -n --argjson a "$(task a A claude-opus-5 high running 1000 200000 "$1")" \
        '{columns: 120, tasks: [$a]}')" | jq -r .content)
    if [[ "$raw" =~ $'\033'\[([0-9;]+)m[0-9hms]+$'\033'\[0m\ · ]]; then
        printf %s "${BASH_REMATCH[1]}"
    fi
}

@test "runtime scale: under 5m neutral, 5-15m yellow, 15-30m orange, 30m+ muted red" {
    [ -z "$(age_code 0)" ]
    [ -z "$(age_code 299)" ]
    [ "$(age_code 300)" = "0;33" ]
    [ "$(age_code 899)" = "0;33" ]
    [ "$(age_code 900)" = "38;5;208" ]
    [ "$(age_code 1799)" = "38;5;208" ]
    [ "$(age_code 1800)" = "38;5;167" ]
    [ "$(age_code 7200)" = "38;5;167" ]
}

# ctx_code <tokens>: the SGR code on "ctx N%" for N = tokens / 2000 (200k window).
ctx_code() {
    bash "$SCRIPT" <<<"$(jq -n --argjson a "$(task a A claude-opus-5 high completed "$1" 200000 5)" '{columns: 120, tasks: [$a]}')" \
        | jq -r .content | grep -o $'\033\\[[0-9;]*mctx' | sed -E 's/^\x1b\[([0-9;]*)mctx$/\1/'
}

@test "context scale: under 70 green, 70-84 yellow, 85-94 orange, 95+ red" {
    [ "$(ctx_code 138000)" = "0;32" ]     # 69%
    [ "$(ctx_code 140000)" = "0;33" ]     # 70%
    [ "$(ctx_code 168000)" = "0;33" ]     # 84%
    [ "$(ctx_code 170000)" = "38;5;208" ] # 85%
    [ "$(ctx_code 188000)" = "38;5;208" ] # 94%
    [ "$(ctx_code 190000)" = "0;31" ]     # 95%
}

@test "context is labelled ctx, with a trailing ! from 80 percent" {
    input=$(jq -n --argjson a "$(task a A claude-opus-5 high completed 20000 200000 5)" \
        --argjson b "$(task b B claude-opus-5 high completed 160000 200000 5)" \
        --argjson c "$(task c C claude-opus-5 high completed 158000 200000 5)" '{columns: 120, tasks: [$a, $b, $c]}')
    run rows "$input"
    [ "${lines[0]}" = "a=✓ A ctx 10%   │ Opus 5:H" ]
    [ "${lines[1]}" = "b=✓ B ctx 80% ! │ Opus 5:H" ]
    [ "${lines[2]}" = "c=✓ C ctx 79%   │ Opus 5:H" ]
}

@test "runtime tint: pending rows are tinted, finished rows show no runtime" {
    input=$(jq -n --argjson a "$(task p P claude-opus-5 high pending 1000 200000 700)" \
        --argjson b "$(task c C claude-opus-5 high completed 1000 200000 700)" '{columns: 120, tasks: [$a, $b]}')
    run bash -c "bash '$SCRIPT' <<<'$input' | jq -r .content"
    [[ "${lines[0]}" == *$'\033[0;33m11m40\033[0m'* ]]
    [[ "${lines[1]}" != *"11m40"* ]]
}

@test "runtime tint: the visible text and width are unchanged by the colour" {
    input=$(jq -n --argjson a "$(task a Alpha claude-opus-5 high running 1000 200000 2000)" '{columns: 120, tasks: [$a]}')
    run rows "$input"
    [ "$output" = "a=▶ Alpha 33m20 · ctx 1% │ Opus 5:H" ]
}

@test "NO_COLOR: no escape codes anywhere in a subagent row, text unchanged" {
    input=$(jq -n --argjson a "$(task a Alpha claude-opus-5 high running 150000 200000 2000)" '{columns: 120, tasks: [$a]}')
    out=$(NO_COLOR=1 bash "$SCRIPT" <<<"$input" | jq -r .content)
    [[ "$out" != *$'\033'* ]]
    [ "$out" = "▶ Alpha 33m20 · ctx 75% │ Opus 5:H" ]
    [ -z "$(age_code 2000 1)" ]
    [ "$(age_code 2000)" = "38;5;167" ]
}

@test "ASCII locale: groups are separated by | and details by -" {
    input=$(jq -n --argjson a "$(real_task reviewer 'Check')" '{columns: 167, tasks: [$a]}')
    out=$(LC_ALL=C bash "$SCRIPT" <<<"$input" | jq -r .content | sed 's/\x1b\[[0-9;]*m//g')
    [ "$out" = "▶ reviewer 1s - ctx 0% | Sonnet 5.5:H | Check" ]
}

@test "a numeric or missing task status does not blank the panel" {
    input=$(jq -n --argjson a "$(task a A claude-opus-5 high running 1000 200000 5 | jq '.status = 3')" \
        --argjson b "$(task b B claude-opus-5 high running 1000 200000 5 | jq 'del(.status)')" '{columns: 120, tasks: [$a, $b]}')
    run rows "$input"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = "a=· A ctx 1% │ Opus 5:H" ]
}

# model_col <content>: the display column where the first group separator after the name starts.
model_cols() {
    bash "$SCRIPT" <<<"$1" | jq -r .content | sed 's/\x1b\[[0-9;]*m//g' | while IFS= read -r l; do
        head=${l%%│*}
        printf '%s\n' "${#head}"
    done
}

@test "mixed context widths, a missing context and tok rows keep the model column aligned" {
    input=$(jq -n \
        --argjson a "$(task a A claude-opus-5 high running 18000 200000 70)" \
        --argjson b "$(task b B claude-opus-5 high running 170000 200000 70)" \
        --argjson c "$(task c C claude-opus-5 high running 298000 0 70)" \
        --argjson d "$(task d D claude-opus-5 high running 0 200000 70 | jq 'del(.tokenCount)')" \
        '{columns: 120, tasks: [$a, $b, $c, $d]}')
    run rows "$input"
    [ "${lines[0]}" = "a=▶ A 1m10 · ctx 9%    │ Opus 5:H" ]
    [ "${lines[1]}" = "b=▶ B 1m10 · ctx 85% ! │ Opus 5:H" ]
    [ "${lines[2]}" = "c=▶ C 1m10 · tok 298k  │ Opus 5:H" ]
    [ "${lines[3]}" = "d=▶ D 1m10 ·           │ Opus 5:H" ]
    run model_cols "$input"
    [ "$(printf '%s\n' "${lines[@]}" | sort -u | wc -l)" -eq 1 ]
}

@test "label is added only when the room left after the model padding is at least 8" {
    # Row a has a very long model name, so row b is padded by about 37 columns;
    # its label must not be added when the room left is smaller than that padding.
    input=$(jq -n \
        --argjson a "$(real_task reviewer 'x' | jq '.model = "claude-aaaaaaaaaaaa-bbbbbbbbbbbbbbb-ccccccccc"')" \
        --argjson b "$(real_task researcher 'Check delegation nesting' | jq '.id = "b" | .model = "x"')" \
        '{columns: 60, tasks: [$a, $b]}')
    for cols in $(seq 60 100); do
        w=$(bash "$SCRIPT" <<<"$(jq --argjson c $cols '.columns = $c' <<<"$input")" | jq -r 'select(.id == "b") | .content' | sed 's/\x1b\[[0-9;]*m//g')
        [ "${#w}" -le "$cols" ] || { echo "cols=$cols width=${#w}: $w"; false; }
    done
    # With room to spare the label is there, after the padded model column.
    run rows "$(jq '.columns = 120' <<<"$input")"
    [[ "${lines[1]}" == "b=▶ researcher"*"│ Check delegation nesting" ]]
}

@test "narrow panel: every effort initial, and exact fit with max" {
    input=$(jq -n \
        --argjson a "$(task a A claude-opus-5 low running 1000 200000 5)" \
        --argjson b "$(task b B claude-opus-5 medium running 1000 200000 5)" \
        --argjson c "$(task c C claude-opus-5 high running 1000 200000 5)" \
        --argjson d "$(task d D claude-opus-5 xhigh running 1000 200000 5)" \
        --argjson e "$(task e E claude-opus-5 max running 1000 200000 5)" \
        --argjson f "$(task f F claude-opus-5 odd running 1000 200000 5)" \
        '{columns: 50, tasks: [$a, $b, $c, $d, $e, $f]}')
    run rows "$input"
    [ "${lines[0]}" = "a=▶ A Opus 5:L   ctx 1%" ]
    [ "${lines[1]}" = "b=▶ B Opus 5:M   ctx 1%" ]
    [ "${lines[2]}" = "c=▶ C Opus 5:H   ctx 1%" ]
    [ "${lines[3]}" = "d=▶ D Opus 5:X   ctx 1%" ]
    [ "${lines[4]}" = "e=▶ E Opus 5:max ctx 1%" ]
    [ "${lines[5]}" = "f=▶ F Opus 5     ctx 1%" ]
    # one row with max: 2 + name 1 + 1 + "Opus 5:max" 10 + 1 + "ctx 1%" 6 = 21 columns exactly
    one=$(jq -n --argjson e "$(task e E claude-opus-5 max running 1000 200000 5)" '{columns: 21, tasks: [$e]}')
    run rows "$one"
    [ "$output" = "e=▶ E Opus 5:max ctx 1%" ]
    run rows "$(jq '.columns = 20' <<<"$one")"
    [ "$output" = "e=▶ E Opus 5 ctx 1%" ]
    [ "${#output}" -le 22 ]
}

# --- Token colour (no window size: the row shows the raw "tok 298k") --------------------

# tok_code <tokens> [columns]: the SGR code directly before "tok N" (empty when plain).
tok_code() {
    bash "$SCRIPT" <<<"$(jq -n --argjson a "$(task a A claude-opus-5 high completed "$1" 0 5)" --argjson c "${2:-120}" '{columns: $c, tasks: [$a]}')" \
        | jq -r .content | { grep -o $'\033\\[[0-9;]*mtok' || true; } | sed -E 's/^\x1b\[([0-9;]*)mtok$/\1/'
}

@test "token scale without a window: under 50k dim, under 150k neutral, under 400k orange, else red" {
    [ "$(tok_code 0)" = "2" ]
    [ "$(tok_code 49999)" = "2" ]
    [ -z "$(tok_code 50000)" ]
    [ -z "$(tok_code 149999)" ]
    [ "$(tok_code 150000)" = "38;5;208" ]
    [ "$(tok_code 399999)" = "38;5;208" ]
    [ "$(tok_code 400000)" = "0;31" ]
    [ "$(tok_code 2000000)" = "0;31" ]
}

@test "token colour: the narrow layout colours the count the same way" {
    [ "$(tok_code 49999 50)" = "2" ]
    [ "$(tok_code 400000 50)" = "0;31" ]
}

@test "token colour: a known window keeps the ctx percent scale and shows no tok field" {
    out=$(bash "$SCRIPT" <<<"$(jq -n --argjson a "$(task a A claude-opus-5 high completed 20000 200000 5)" '{columns: 120, tasks: [$a]}')" | jq -r .content)
    [[ "$out" != *tok* ]]
    [ "$(ctx_code 20000)" = "0;32" ]
}

@test "token colour: a missing token count adds no field and no colour" {
    input=$(jq -n --argjson a "$(task n N claude-opus-5 high completed 0 0 5 | jq 'del(.tokenCount)')" '{columns: 120, tasks: [$a]}')
    out=$(bash "$SCRIPT" <<<"$input" | jq -r .content)
    [[ "$out" != *tok* ]]
}

@test "token colour: NO_COLOR gives no escapes and the text is unchanged at every width" {
    for cols in 28 50 59 60 80 120 200; do
        input=$(jq -n --argjson a "$(task a Alpha claude-opus-5 high running 298000 0 2000)" --argjson c "$cols" '{columns: $c, tasks: [$a]}')
        colour=$(bash "$SCRIPT" <<<"$input" | jq -r .content)
        plain=$(NO_COLOR=1 bash "$SCRIPT" <<<"$input" | jq -r .content)
        [[ "$plain" != *$'\033'* ]]
        [ "$plain" = "$(sed 's/\x1b\[[0-9;]*m//g' <<<"$colour")" ]
        [[ "$plain" == *"tok 298k"* ]]
    done
    [ "$(NO_COLOR=1 bash "$SCRIPT" <<<"$(jq -n --argjson a "$(task a Alpha claude-opus-5 high running 298000 0 2000)" '{columns: 120, tasks: [$a]}')" | jq -r .content)" = "▶ Alpha 33m20 · tok 298k │ Opus 5:H" ]
}

@test "token colour: the elapsed time stays tinted next to a coloured token count" {
    input=$(jq -n --argjson a "$(task a Alpha claude-opus-5 high running 298000 0 2000)" '{columns: 120, tasks: [$a]}')
    out=$(bash "$SCRIPT" <<<"$input" | jq -r .content)
    [[ "$out" == *$'\033[38;5;167m33m20\033[0m'* ]]
    [[ "$out" == *$'\033[38;5;208mtok 298k\033[0m'* ]]
}
