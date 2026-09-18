#!/usr/bin/env bash
# Claude Code subagentStatusLine command: one row per agent in the agent panel
# (see `subagentStatusLine` in settings.json). Contract:
# https://code.claude.com/docs/en/statusline#subagent-status-lines
#
# stdin:  {columns, tasks: [{id, name, label, description, status, startTime (epoch ms),
#          model, effort, contextWindowSize, tokenCount, ...}]}
# stdout: one {"id", "content"} JSON line per row.
#
# Row:     Architecture Opus 5   · max   · ▶ 84% ⚠ · 7m31
# Narrow:  Architecture ▶ 84% ⚠                        (columns < 60)
#
# Status: ▶ running  ◷ pending  ✓ completed  ✗ failed  ■ killed. Elapsed time is
# shown only while running/pending (tasks carry no end time). ⚠ at >= 80% context.
# STATUSLINE_NOW (epoch seconds) pins the clock for tests.
set -euo pipefail

jq -c --argjson now "${STATUSLINE_NOW:-$(date +%s)}" '
    def color($code): "[\($code)m\(.)[0m";
    def level_color: if . < 70 then "0;32" elif . < 90 then "0;33" else "0;31" end;
    def tokens:
        if . >= 1000000 then "\((. / 100000 | floor) / 10)M"
        elif . >= 1000 then "\(. / 1000 | floor)k"
        else "\(floor)" end;
    def pad2: tostring | if length < 2 then "0" + . else . end;
    def rpad($n): if length < $n then . + (" " * ($n - length)) else . end;
    def truncate($n): if length > $n then .[0:$n - 1] + "…" else . end;
    # claude-haiku-4-5-20251001 -> Haiku 4.5, claude-opus-5[1m] -> Opus 5
    def model_name:
        sub("^claude-"; "") | sub("\\[.*\\]$"; "") | sub("-[0-9]{8}$"; "")
        | split("-")
        | [(.[0][0:1] | ascii_upcase) + .[0][1:]] + (if length > 1 then [.[1:] | join(".")] else [] end)
        | join(" ");
    def elapsed:
        ($now - (. / 1000 | floor)) as $s
        | if $s < 60 then "\([$s, 0] | max)s"
          elif $s < 3600 then "\($s / 60 | floor)m\($s % 60 | pad2)"
          else "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor | pad2)" end;
    def icon:
        . as $status
        | {running: ["▶", "0;34"], pending: ["◷", "0;33"], completed: ["✓", "0;32"],
           failed: ["✗", "0;31"], killed: ["■", "0;33"]}[$status] // ["·", "0"];

    (.columns // 999) as $cols
    | [(.tasks // [])[] | {
        id,
        status,
        name: ((.name // .label // .description // "agent") | truncate(15)),
        model: (if .model then .model | model_name else "" end),
        effort: (if .effort == null then "inherit"
                 elif (.effort | type) == "number" then .effort | tokens
                 else .effort end),
        pct: (if (.contextWindowSize // 0) > 0
              then (.tokenCount // 0) * 100 / .contextWindowSize + 0.5 | floor
              else null end),
        tokens: (.tokenCount // 0 | tokens),
        since: .startTime
      }] as $rows
    | ([$rows[].name | length] | max // 0) as $name_w
    | ([$rows[].model | length] | max // 0) as $model_w
    | ([$rows[].effort | length] | max // 0) as $effort_w
    | $rows[]
    | (.status | icon) as [$glyph, $glyph_color]
    | .pct as $p
    | (if $p == null then "\(.tokens) tok"
       else ("\($p)%" | color($p | level_color))
            + (if $p >= 80 then " " + ("⚠" | color("0;31")) else "" end)
       end) as $ctx
    | (($glyph | color($glyph_color)) + " " + $ctx) as $state
    | (if (.status == "running" or .status == "pending") and .since != null
       then .since | elapsed else "" end) as $age
    | (.name | rpad($name_w)) as $name
    | {id, content:
        (if $cols < 60 then "\($name) \($state)"
         else $name + " " + ([(.model | rpad($model_w)), (.effort | rpad($effort_w)), $state, $age]
                            | map(select(length > 0)) | join(" · "))
         end)}
'
