#!/usr/bin/env bash
# Claude Code statusLine command. Claude Code pipes a JSON object on stdin
# (see `statusLine` in settings.json). Field reference:
# https://code.claude.com/docs/en/statusline#available-data
#
# Wide:    project ⎇ branch* +A/-R | Model · effort:high | Ctx 55% · 548k/1M · LONG | 5h 72% ↻1h24m · 7d 41% ↻Tue
#          WT name | PR #184 approved                            (only when either exists)
# Narrow:  project ⎇ branch* | Model:high | Ctx 55% | 5h 72% | 7d 41%    (COLUMNS < 120)
#          +A/-R · WT name · PR #184 approved
#
# Ctx % is real context-window usage; LONG marks crossing the fixed 200k
# threshold. STATUSLINE_NOW (epoch seconds) pins the clock for tests.
# shellcheck disable=SC2154  # payload variables are assigned by the jq eval below
set -euo pipefail

RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
NC=$'\033[0m'
NARROW_BELOW=120

# level_color <percent>: green below 70, yellow below 90, red otherwise.
level_color() {
    if   (( $1 < 70 )); then printf %s "$GREEN"
    elif (( $1 < 90 )); then printf %s "$YELLOW"
    else                     printf %s "$RED"
    fi
}

# join <separator> <parts...>: join the non-empty parts.
join() {
    local sep=$1 out="" part
    shift
    for part in "$@"; do
        [[ -z "$part" ]] && continue
        out+="${out:+$sep}$part"
    done
    printf %s "$out"
}

# One jq pass turns the payload into shell variables.
eval "$(jq -r --argjson now "${STATUSLINE_NOW:-$(date +%s)}" '
    def round: . + 0.5 | floor;
    def tokens:
        if . >= 1000000 then "\((. / 100000 | floor) / 10)M"
        elif . >= 1000 then "\(. / 1000 | floor)k"
        else "\(floor)" end;
    def pad2: tostring | if length < 2 then "0" + . else . end;
    # Weekday when a day or more away, otherwise a countdown.
    def reset_in:
        (. - $now) as $s
        | if $s >= 86400 then strflocaltime("%a")
          elif $s >= 3600 then "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor | pad2)m"
          else "\([($s / 60 | floor), 0] | max)m" end;
    def quota($w):
        .rate_limits[$w]
        | if .used_percentage == null then ["", ""]
          else [(.used_percentage | round | tostring),
                (if .resets_at == null then "" else .resets_at | reset_in end)] end;

    (.context_window // {}) as $cw
    | ($cw.context_window_size // 200000) as $size
    | ($cw.total_input_tokens // 0) as $used
    | quota("five_hour") as $q5
    | quota("seven_day") as $q7
    | @sh "project_dir=\(.workspace.project_dir // .cwd // "")",
      @sh "current_dir=\(.workspace.current_dir // .cwd // "")",
      @sh "model_name=\(.model.display_name // "unknown" | sub(" \\([^)]*context\\)$"; ""))",
      @sh "effort=\(.effort.level // "")",
      @sh "ctx_pct=\($cw.used_percentage // (if $size > 0 then $used * 100 / $size else 0 end) | round)",
      @sh "ctx_used=\($used | tokens)",
      @sh "ctx_size=\($size | tokens)",
      @sh "long=\(if has("exceeds_200k_tokens") then .exceeds_200k_tokens else $used > 200000 end)",
      @sh "added=\(.cost.total_lines_added // 0)",
      @sh "removed=\(.cost.total_lines_removed // 0)",
      @sh "q5_pct=\($q5[0])", @sh "q5_reset=\($q5[1])",
      @sh "q7_pct=\($q7[0])", @sh "q7_reset=\($q7[1])",
      @sh "worktree=\(.worktree.name // .workspace.git_worktree // "")",
      @sh "pr_number=\(.pr.number // "" | tostring)",
      @sh "pr_state=\(.pr.review_state // "")"
')"

# Project = the dir Claude was launched in; branch follows current_dir so a
# worktree/`cd` elsewhere shows the branch actually being edited.
project=$(basename "${project_dir:-$PWD}")
branch=""
if [[ -n "$current_dir" ]]; then
    branch=$(git --no-optional-locks -C "$current_dir" branch --show-current 2>/dev/null \
        || true)
    if [[ -z "$branch" ]]; then
        branch=$(git --no-optional-locks -C "$current_dir" rev-parse --short HEAD 2>/dev/null \
            || true)
    fi
fi

repo="${GREEN}${project}${NC}"
if [[ -n "$branch" ]]; then
    repo+=" ${MAGENTA}⎇ ${branch}${NC}"
    if [[ -n "$(git --no-optional-locks -C "$current_dir" status --porcelain 2>/dev/null || true)" ]]; then
        repo+="${YELLOW}*${NC}"
    fi
fi

diff=""
if (( added + removed > 0 )); then
    diff="${GREEN}+${added}${NC}/${RED}-${removed}${NC}"
fi

ctx_color=$(level_color "$ctx_pct")
ctx_short="${ctx_color}Ctx ${ctx_pct}%${NC}"

q5="" q7="" q5_long="" q7_long=""
if [[ -n "$q5_pct" ]]; then
    q5="$(level_color "$q5_pct")5h ${q5_pct}%${NC}"
    q5_long="${q5}${q5_reset:+ ↻$q5_reset}"
fi
if [[ -n "$q7_pct" ]]; then
    q7="$(level_color "$q7_pct")7d ${q7_pct}%${NC}"
    q7_long="${q7}${q7_reset:+ ↻$q7_reset}"
fi

wt_seg="${worktree:+WT $worktree}"
pr_seg=""
if [[ -n "$pr_number" ]]; then
    case "$pr_state" in
        approved)          pr_color=$GREEN ;;
        changes_requested) pr_color=$RED ;;
        *)                 pr_color=$YELLOW ;;
    esac
    pr_seg="PR #${pr_number}${pr_state:+ ${pr_color}${pr_state}${NC}}"
fi

if (( ${COLUMNS:-999} < NARROW_BELOW )); then
    line1=$(join " | " "$repo" "${BLUE}${model_name}${NC}${effort:+:$effort}" \
        "$ctx_short" "$q5" "$q7")
    line2=$(join " · " "$diff" "$wt_seg" "$pr_seg")
else
    ctx_long="${ctx_short} · ${ctx_used}/${ctx_size}"
    if [[ "$long" == true ]]; then
        ctx_long+=" · ${YELLOW}LONG${NC}"
    fi
    line1=$(join " | " "$(join " " "$repo" "$diff")" \
        "${BLUE}${model_name}${NC}${effort:+ · effort:$effort}" \
        "$ctx_long" "$(join " · " "$q5_long" "$q7_long")")
    line2=$(join " | " "$wt_seg" "$pr_seg")
fi

printf '%s\n' "$line1"
if [[ -n "$line2" ]]; then
    printf '%s\n' "$line2"
fi
