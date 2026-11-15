#!/usr/bin/env bash
# Claude Code subagentStatusLine command: one row per agent in the agent panel
# (see `subagentStatusLine` in settings.json). Contract:
# https://code.claude.com/docs/en/statusline#subagent-status-lines
#
# NOTE (2026-11): Claude Code 2.1.323 removed the `subagentStatusLine` setting
# (CHANGELOG 2.1.323; anthropics/claude-code#109446, #109494) and 2.1.325 still
# ignores it, so the agent panel shows its default rows. A maintainer said a
# grace period is planned for the next release and the feature is moving to
# mods. This renderer and its tests are kept until that lands.
#
# stdin:  {columns, tasks: [{id, agentType, label, description, status, startTime (epoch ms),
#          model, effort, contextWindowSize, tokenCount, ...}]}
#         Claude Code 2.1.325 sends no `name`: the agent type is `agentType` and the
#         task text is `label`. `name` is still honoured when present.
# stdout: one {"id", "content"} JSON line per row.
#
# Row:     reviewer Opus 5 · max · ▶ ctx 84% ! · 7m31 · Check delegation nesting
# Narrow:  reviewer Opus 5:M ▶ ctx 84% !                (columns < 60, no task text)
# The trailing task text is cut to the columns left (dropped under 8), so a row
# never exceeds `columns`. Names are coloured by agent type, models by family.
#
# Status: ▶ running  ◷ pending  ✓ completed  ✗ failed  ■ killed. Elapsed time is
# shown only while running/pending (tasks carry no end time), tinted by duration:
# 5m faint yellow, 10m yellow, 20m orange, 30m bold red. NO_COLOR drops all codes. "!" after the context % at >= 80%.
# Narrow keeps a compact model tag (Sonnet -> Son) plus the effort initial when
# the row still fits; without a model there is no tag.
# STATUSLINE_NOW (epoch seconds) pins the clock for tests.
set -euo pipefail

jq -c --argjson now "${STATUSLINE_NOW:-$(date +%s)}" \
    --argjson nocolor "$([[ -n "${NO_COLOR:-}" ]] && echo true || echo false)" '
    # NO_COLOR (set, non-empty) turns every escape code off; the layout is unchanged.
    def color($code): if $nocolor then . else "[\($code)m\(.)[0m" end;
    def level_color: if . < 70 then "0;32" elif . < 90 then "0;33" else "0;31" end;
    def tokens:
        if . >= 1000000 then "\((. / 100000 | floor) / 10)M"
        elif . >= 1000 then "\(. / 1000 | floor)k"
        else "\(floor)" end;
    def pad2: tostring | if length < 2 then "0" + . else . end;
    def rpad($n): if length < $n then . + (" " * ($n - length)) else . end;
    # Strings only, no control characters (untrusted payload text).
    def clean: tostring | gsub("[[:cntrl:]]"; "");
    def plain: gsub("\u001b\\[[0-9;]*m"; "");
    def truncate($n): if length > $n then .[0:$n - 1] + "…" else . end;
    # claude-haiku-4-5-20251001 -> Haiku 4.5, claude-opus-5[1m] -> Opus 5
    def model_name:
        sub("^claude-"; "") | sub("\\[.*\\]$"; "") | sub("-[0-9]{8}$"; "")
        | split("-")
        | [(.[0][0:1] | ascii_upcase) + .[0][1:]] + (if length > 1 then [.[1:] | join(".")] else [] end)
        | join(" ");
    # Stable colour per agent type (name column) and per model family. Basic SGR
    # codes only, so they follow the terminal palette; unknown types are grey.
    def type_color:
        ({researcher: "0;36", architect: "0;35", implementer: "0;32",
          "super-implementer": "0;32", reviewer: "0;33", orchestrator: "0;34",
          "plan-writer": "1", "release-auditor": "0;31"})[ascii_downcase] // "0;90";
    def tint($code): if length > 0 then color($code) else . end;
    def family_color:
        if startswith("Opus") then "0;35" elif startswith("Son") then "0;36"
        elif startswith("Haiku") then "0;32" else "0" end;
    # Narrow-row effort initial; unknown levels get none.
    def eff_i: ({low: "l", medium: "m", high: "h", xhigh: "x", max: "M"})[.] // "";
    # Elapsed-time tint for a running/pending row, by seconds running:
    # <5m none, 5-10m faint yellow, 10-20m yellow, 20-30m orange, >=30m bold red.
    # (Read as bands: the "15m" in the request is taken as the 10-20m band.)
    def age_code:
        if . >= 1800 then "1;31" elif . >= 1200 then "38;5;208"
        elif . >= 600 then "0;33" elif . >= 300 then "2;33" else "" end;
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
        name: ((.name // .agentType // .label // .description // "agent") | clean | truncate(15)),
        kind: (.agentType // .name // "" | clean),
        # Task text trails the row, only when the name column is not already it.
        task: (if (.name // .agentType) != null then (.label // "" | clean) else "" end),
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
    | ([$rows[] | (.model | sub("^Sonnet"; "Son")) + (if .model != "" and (.effort | eff_i) != "" then ":x" else "" end) | length] | max // 0) as $full_w
    # Widest state ("▶ ctx 84% !"), so keeping or dropping the effort initial is one decision for all rows.
    | ([$rows[] | 2 + (if .pct == null then (.tokens | length) + 4
                       else 4 + (.pct | tostring | length) + 1 + (if .pct >= 80 then 2 else 0 end) end)] | max // 0) as $state_w
    | ([$rows[].model | sub("^Sonnet"; "Son") | length] | max // 0) as $tag_w
    | $rows[]
    | ((.status // "" | tostring) | icon) as [$glyph, $glyph_color]
    | .pct as $p
    | (if $p == null then "\(.tokens) tok"
       else ("ctx \($p)%" | color($p | level_color))
            + (if $p >= 80 then " " + ("!" | color("0;31")) else "" end)
       end) as $ctx
    | (($glyph | color($glyph_color)) + " " + $ctx) as $state
    | (if (.status == "running" or .status == "pending") and .since != null
       then (.since | elapsed) as $e
            | ($now - (.since / 1000 | floor) | age_code) as $c
            | if $c == "" then $e else $e | color($c) end
       else "" end) as $age
    | (.kind | type_color) as $kind_c
    | (.model | sub("^Sonnet"; "Son") | family_color) as $model_c
    | (.name | rpad($name_w) | color($kind_c)) as $name
    | {id, content:
        (if $cols < 60 then
            ((.model | sub("^Sonnet"; "Son")) as $tag
             | (if .model != "" and (.effort | eff_i) != ""
                then $tag + ":" + (.effort | eff_i) else $tag end) as $full
             | (if $name_w + 1 + $full_w + 1 + $state_w <= $cols
                then $full | rpad($full_w) else $tag | rpad($tag_w) end) as $mark
             | ([$name, ($mark | tint($model_c)), $state] | map(select(length > 0)) | join(" ")))
         else
            ($name + " " + ([(.model | rpad($model_w) | tint($model_c)), (.effort | rpad($effort_w)), $state, $age]
                            | map(select(length > 0)) | join(" · "))) as $base
            | ($cols - ($base | plain | length) - 3) as $room
            | if .task != "" and $room >= 8 then $base + " · " + (.task | truncate([$room, 40] | min)) else $base end
         end)}
'
