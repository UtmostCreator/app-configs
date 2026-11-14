#!/usr/bin/env bash
# Claude Code statusLine command. Claude Code pipes a JSON object on stdin
# (see `statusLine` in settings.json). Field reference:
# https://code.claude.com/docs/en/statusline#available-data
#
# +A/-R is the live `git diff HEAD` line count (session edit counters outside git).
# Wide:    project ⎇ branch* +A/-R | Model · effort:high | Ctx 55% · 548k/1M · LONG | 5h 72% ↻1h24m · 7d 41% ↻Tue
#          WT name | PR #184 approved | $1.23 · 1h02m · Cache 91%   (only what exists)
# Narrow:  project ⎇ branch* | Model:high | Ctx 55% | 5h 72% | 7d 41%    (COLUMNS < 120)
#          +A/-R · WT name · PR #184 approved · $1.23 · 1h02m · Cache 91%
#
# Ctx % is real context-window usage; LONG marks crossing the fixed 200k
# threshold. RC leads line 1 while the session is connected to Remote Control.
#
# Optional segments appear only when their payload field exists (never a fake 0):
#   "452k left"      context_window.remaining_percentage (wide, after the token count)
#   Ctx colour       green <75%, yellow <85%, orange <95%, bold red above
#   ●S ✚U …N ↑A↓B   staged/unstaged/untracked paths (only when 2+ paths changed,
#                    since the * marker already covers one) and ahead/behind the
#                    upstream as last fetched; this script never fetches
#   $1.23 · 1h02m    cost.total_cost_usd, cost.total_duration_ms
#   Cache 91% cold   prompt_cache.hit_ratio; "cold" when prompt_cache.warm is false
# Lines are fitted to $COLUMNS by dropping the lowest-priority segments first.
# The auto/permission mode is left to Claude Code's own footer.
#
# STATUSLINE_NOW (epoch seconds) pins the clock for tests. Git results are
# cached STATUSLINE_GIT_TTL seconds (default 5, 0 disables) per directory in
# $XDG_RUNTIME_DIR (else $TMPDIR, else /tmp)/claude-statusline-<uid>.
# shellcheck disable=SC2154  # payload variables are assigned by the jq eval below
set -euo pipefail
shopt -s extglob

RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
ORANGE=$'\033[38;5;208m'
BOLD_RED=$'\033[1;31m'
NC=$'\033[0m'
NARROW_BELOW=120

# level_color <percent>: green below 70, yellow below 90, red otherwise.
level_color() {
    if   (( $1 < 70 )); then printf %s "$GREEN"
    elif (( $1 < 90 )); then printf %s "$YELLOW"
    else                     printf %s "$RED"
    fi
}

# pressure_color <percent>: green below 75, yellow below 85, orange below 95,
# bold red otherwise (context window pressure).
pressure_color() {
    if   (( $1 < 75 )); then printf %s "$GREEN"
    elif (( $1 < 85 )); then printf %s "$YELLOW"
    elif (( $1 < 95 )); then printf %s "$ORANGE"
    else                     printf %s "$BOLD_RED"
    fi
}

# width <text>: display columns, ignoring colour codes. Byte length minus UTF-8
# continuation bytes, so it does not depend on the caller's locale.
width() {
    local plain=${1//$'\033'\[*([0-9;])m/} LC_ALL=C
    plain=${plain//[$'\200'-$'\277']/}
    printf %s "${#plain}"
}

# clock <seconds>: 45s, 12m, 1h02m.
clock() {
    if   (( $1 >= 3600 )); then printf '%dh%02dm' $(($1 / 3600)) $(($1 % 3600 / 60))
    elif (( $1 >= 60 ));   then printf '%dm' $(($1 / 60))
    else                        printf '%ds' "$1"
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

NOW=${STATUSLINE_NOW:-$(date +%s)}

# One jq pass turns the payload into shell variables.
eval "$(jq -r --argjson now "$NOW" '
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
    # A number as a rounded integer string, otherwise "" (field absent or odd).
    def whole(f): f | if type == "number" then round | tostring else "" end;

    (.context_window // {}) as $cw
    | ($cw.context_window_size // 200000) as $size
    | ($cw.total_input_tokens // 0) as $used
    | quota("five_hour") as $q5
    | quota("seven_day") as $q7
    | @sh "project_dir=\(.workspace.project_dir // .cwd // "")",
      @sh "session_id=\(.session_id // "")",
      @sh "current_dir=\(.workspace.current_dir // .cwd // "")",
      @sh "model_name=\(.model.display_name // "unknown" | sub(" \\([^)]*context\\)$"; ""))",
      @sh "effort=\(.effort.level // "")",
      @sh "ctx_pct=\($cw.used_percentage // (if $size > 0 then $used * 100 / $size else 0 end) | round)",
      @sh "ctx_used=\($used | tokens)",
      @sh "ctx_size=\($size | tokens)",
      @sh "ctx_left=\(if ($cw.remaining_percentage | type) == "number"
                      then ($size * $cw.remaining_percentage / 100 | round | tokens) else "" end)",
      @sh "cost_cents=\(whole(.cost.total_cost_usd | if type == "number" then . * 100 else . end))",
      @sh "duration_s=\(whole(.cost.total_duration_ms | if type == "number" then . / 1000 | floor else . end))",
      @sh "cache_observed=\(.prompt_cache.caching_observed == true)",
      @sh "cache_warm=\(.prompt_cache.warm == true)",
      @sh "cache_hit=\(whole(.prompt_cache.hit_ratio | if type == "number" then . * 100 else . end))",
      @sh "long=\(if has("exceeds_200k_tokens") then .exceeds_200k_tokens else $used > 200000 end)",
      @sh "added=\(.cost.total_lines_added // 0)",
      @sh "removed=\(.cost.total_lines_removed // 0)",
      @sh "q5_pct=\($q5[0])", @sh "q5_reset=\($q5[1])",
      @sh "q7_pct=\($q7[0])", @sh "q7_reset=\($q7[1])",
      @sh "worktree=\(.worktree.name // .workspace.git_worktree // "")",
      @sh "pr_number=\(.pr.number // "" | tostring)",
      @sh "pr_state=\(.pr.review_state // "")"
')"

# Remote Control is not in the statusLine payload. Claude Code keeps a state
# file per running session in <config>/sessions/<pid>.json and sets
# bridgeSessionId there while the session is connected. That file is internal,
# so any surprise (no dir, bad JSON, renamed field) just means no tag. When a
# resume left several files for this session, the latest updatedAt wins.
remote_control=""
sessions_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
if [[ -n "$session_id" && -d "$sessions_dir" ]]; then
    # grep narrows to this session's files; each is parsed on its own so one
    # malformed file cannot hide the rest.
    grep -lF -- "$session_id" "$sessions_dir"/*.json 2>/dev/null \
        | while IFS= read -r f; do jq -c . "$f" 2>/dev/null || true; done \
        | jq -e -s --arg id "$session_id" '
            map(select(.sessionId == $id)) | sort_by(.updatedAt // 0) | last
            | .bridgeSessionId // "" | length > 0' >/dev/null 2>&1 \
        && remote_control="${GREEN}RC${NC}"
fi

# git_state <dir>: one tab-separated line, "-" standing for an empty branch
# (so `read` never sees an empty field):
#   epoch branch changed staged unstaged untracked ahead behind added removed
# Counts are paths (a file both staged and modified counts in both). ahead and
# behind compare with the upstream as last fetched; nothing here touches the
# network. added/removed is the working tree against HEAD (binary files and
# untracked files add no lines).
git_state() {
    local dir=$1 status_out head t s u n a b added removed
    status_out=$(git --no-optional-locks -C "$dir" status --porcelain=v2 --branch 2>/dev/null) || true
    if [[ -z "$status_out" ]]; then
        printf '%s\t-\t0\t0\t0\t0\t0\t0\t0\t0\n' "$NOW"
        return
    fi
    read -r head _ t s u n a b < <(awk '
        $1 == "#" && $2 == "branch.head" { head = $3 }
        $1 == "#" && $2 == "branch.oid"  { oid = $3 }
        $1 == "#" && $2 == "branch.ab"   { a = substr($3, 2); b = substr($4, 2) }
        $1 == "1" || $1 == "2" {
            if (substr($2, 1, 1) != ".") s++
            if (substr($2, 2, 1) != ".") u++
            t++
        }
        $1 == "u" { u++; t++ }
        $1 == "?" { n++; t++ }
        END { print head, oid, t + 0, s + 0, u + 0, n + 0, a + 0, b + 0 }' <<<"$status_out")
    if [[ "$head" == "(detached)" ]]; then
        head=$(git --no-optional-locks -C "$dir" rev-parse --short HEAD 2>/dev/null || true)
    fi
    head=${head//[[:cntrl:]]/}
    read -r added removed < <(git --no-optional-locks -C "$dir" diff HEAD --numstat 2>/dev/null \
        | awk '$1 != "-" { a += $1; r += $2 } END { print a + 0, r + 0 }')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$NOW" "${head:--}" "$t" "$s" "$u" "$n" \
        "$a" "$b" "$added" "$removed"
}

# git_cached <dir>: git_state, reused for STATUSLINE_GIT_TTL seconds. The cache
# lives in a per-user directory that must be a real directory (not a symlink)
# owned by us; anything doubtful runs uncached. A cached line is only used when
# the whole line matches the exact shape git_state writes (epoch, branch with
# no control characters, eight integers), so planted data is a cache miss and
# is never evaluated; it is also never sourced.
git_cached() {
    local dir=$1 ttl=${STATUSLINE_GIT_TTL:-5} cache_dir key file line ts
    local shape=$'^([0-9]{1,12})\t[^[:cntrl:]]+(\t[0-9]{1,9}){8}$'
    if [[ "$ttl" =~ ^[0-9]+$ ]] && (( ttl > 0 )); then
        cache_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline-$(id -u)"
        if [[ ! -e "$cache_dir" && ! -L "$cache_dir" ]]; then
            mkdir -m 700 "$cache_dir" 2>/dev/null || true
        fi
        if [[ -d "$cache_dir" && ! -L "$cache_dir" && -O "$cache_dir" ]]; then
            key=$(printf %s "$dir" | cksum)
            file="$cache_dir/${key%% *}"
            if [[ -f "$file" && ! -L "$file" ]] && IFS= read -r line <"$file" \
                && [[ "$line" =~ $shape ]]; then
                ts=${BASH_REMATCH[1]}
                if (( NOW >= ts && NOW - ts < ttl )); then
                    printf '%s\n' "$line"
                    return
                fi
            fi
            line=$(git_state "$dir")
            { printf '%s\n' "$line" >"$file.$$" && mv -f "$file.$$" "$file"; } 2>/dev/null || true
            printf '%s\n' "$line"
            return
        fi
    fi
    git_state "$dir"
}

# Project = the dir Claude was launched in; branch follows current_dir so a
# worktree/`cd` elsewhere shows the branch actually being edited.
project=$(basename "${project_dir:-$PWD}")
branch="" changed=0 staged=0 unstaged=0 untracked=0 ahead=0 behind=0 git_added=0 git_removed=0
if [[ -n "$current_dir" ]]; then
    IFS=$'\t' read -r _ branch changed staged unstaged untracked ahead behind git_added git_removed \
        < <(git_cached "$current_dir")
    [[ "$branch" == "-" ]] && branch=""
fi

repo="${GREEN}${project}${NC}"
git_counts=""
if [[ -n "$branch" ]]; then
    repo+=" ${MAGENTA}⎇ ${branch}${NC}"
    if (( changed > 0 )); then
        repo+="${YELLOW}*${NC}"
    fi
    # +A/-R is the working tree against HEAD (staged and unstaged), read fresh
    # (within the cache TTL) so commits and edits made outside this session
    # show up. The payload's cost counters only count this session's own
    # edits, so they stay the fallback for a directory that is not a git repo.
    added=$git_added removed=$git_removed
    # A single changed path is already conveyed by the * marker.
    staged_seg="" unstaged_seg="" untracked_seg="" sync_seg=""
    if (( changed > 1 )); then
        (( staged > 0 ))    && staged_seg="${GREEN}●${staged}${NC}"
        (( unstaged > 0 ))  && unstaged_seg="${YELLOW}✚${unstaged}${NC}"
        (( untracked > 0 )) && untracked_seg="${RED}…${untracked}${NC}"
    fi
    (( ahead > 0 ))  && sync_seg+="↑${ahead}"
    (( behind > 0 )) && sync_seg+="↓${behind}"
    git_counts=$(join " " "$staged_seg" "$unstaged_seg" "$untracked_seg" "${sync_seg:+${BLUE}${sync_seg}${NC}}")
fi

diff=""
if (( added + removed > 0 )); then
    diff="${GREEN}+${added}${NC}/${RED}-${removed}${NC}"
fi

ctx_short="$(pressure_color "$ctx_pct")Ctx ${ctx_pct}%${NC}"

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

# Session cost and duration, then prompt-cache health; each only when present.
cost_seg="" dur_seg="" cache_seg=""
if [[ -n "$cost_cents" ]]; then
    printf -v cost_seg '$%d.%02d' $((cost_cents / 100)) $((cost_cents % 100))
fi
if [[ -n "$duration_s" ]]; then
    dur_seg=$(clock "$duration_s")
fi
session_seg=$(join " · " "$cost_seg" "$dur_seg")
if [[ "$cache_observed" == true ]]; then
    cache_hit_seg=""
    if [[ -n "$cache_hit" ]]; then
        if   (( cache_hit >= 80 )); then cache_color=$GREEN
        elif (( cache_hit >= 50 )); then cache_color=$YELLOW
        else                             cache_color=$RED
        fi
        cache_hit_seg="${cache_color}Cache ${cache_hit}%${NC}"
    fi
    cache_cold=""
    if [[ "$cache_warm" != true ]]; then
        cache_cold="${YELLOW}cold${NC}"
        [[ -z "$cache_hit_seg" ]] && cache_cold="Cache ${cache_cold}"
    fi
    cache_seg=$(join " " "$cache_hit_seg" "$cache_cold")
fi

# Lowest-priority segments go first when the terminal is too narrow; each
# drop_* flag is switched on by fit level below.
drop_left=0 drop_resets=0 drop_q7=0 drop_q5=0 drop_tokens=0 drop_effort=0 drop_counts=0
drop_cache=0 drop_session=0

render() {
    local q5="" q7="" q5_long="" q7_long="" ctx_long
    if [[ -n "$q5_pct" ]]; then
        q5="$(level_color "$q5_pct")5h ${q5_pct}%${NC}"
        q5_long="${q5}${q5_reset:+ ↻$q5_reset}"
        (( drop_q5 )) && q5=""
        (( drop_resets )) && q5_long="$q5"
    fi
    if [[ -n "$q7_pct" ]]; then
        q7="$(level_color "$q7_pct")7d ${q7_pct}%${NC}"
        q7_long="${q7}${q7_reset:+ ↻$q7_reset}"
        (( drop_resets )) && q7_long="$q7"
    fi
    (( drop_q7 )) && { q7="" q7_long=""; }
    (( drop_q5 )) && q5_long=""

    local repo_seg=$repo diff_seg=$diff
    if (( ! drop_counts )); then
        repo_seg=$(join " " "$repo" "$git_counts")
    fi
    local cache_part=$cache_seg session_part=$session_seg
    (( drop_cache )) && cache_part=""
    (( drop_session )) && session_part=""
    local extras
    extras=$(join " · " "$session_part" "$cache_part")

    if (( narrow )); then
        line1=$(join " | " "$remote_control" "$repo_seg" "${BLUE}${model_name}${NC}${effort:+:$effort}" \
            "$ctx_short" "$q5" "$q7")
        line2=$(join " · " "$diff_seg" "$wt_seg" "$pr_seg" "$extras")
    else
        ctx_long="${ctx_short}"
        (( drop_tokens )) || ctx_long+=" · ${ctx_used}/${ctx_size}"
        if [[ -n "$ctx_left" ]] && (( ! drop_left )); then
            ctx_long+=" · ${ctx_left} left"
        fi
        if [[ "$long" == true ]]; then
            ctx_long+=" · ${YELLOW}LONG${NC}"
        fi
        local effort_seg=""
        (( drop_effort )) || effort_seg="${effort:+ · effort:$effort}"
        line1=$(join " | " "$remote_control" "$(join " " "$repo_seg" "$diff_seg")" \
            "${BLUE}${model_name}${NC}${effort_seg}" \
            "$ctx_long" "$(join " · " "$q5_long" "$q7_long")")
        line2=$(join " | " "$wt_seg" "$pr_seg" "$extras")
    fi
}

cols=${COLUMNS:-999}
[[ "$cols" =~ ^[0-9]+$ ]] || cols=999
narrow=0
(( cols < NARROW_BELOW )) && narrow=1

# Line 1: raise the fit level until it fits (or nothing is left to drop).
for level in 0 1 2 3 4 5 6; do
    if (( narrow )); then
        # 7d, then 5h, then the git counts.
        drop_q7=$(( level >= 1 )) drop_q5=$(( level >= 2 )) drop_counts=$(( level >= 3 ))
    else
        # Remaining tokens, reset times, 7d, token counts, effort, git counts.
        drop_left=$(( level >= 1 )) drop_resets=$(( level >= 2 )) drop_q7=$(( level >= 3 ))
        drop_tokens=$(( level >= 4 )) drop_effort=$(( level >= 5 )) drop_counts=$(( level >= 6 ))
    fi
    render
    (( $(width "$line1") <= cols )) && break
done
# Line 2: cache health, then cost/duration.
for level in 0 1 2; do
    drop_cache=$(( level >= 1 )) drop_session=$(( level >= 2 ))
    render
    (( $(width "$line2") <= cols )) && break
done

printf '%s\n' "$line1"
if [[ -n "$line2" ]]; then
    printf '%s\n' "$line2"
fi
