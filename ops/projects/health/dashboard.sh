#!/usr/bin/env bash
# Live markdown workspace-health dashboard (shared by the zsh and fish
# `ws-health` / `ws-health-once` commands).
#
# Usage:
#   bash ops/projects/health/dashboard.sh          live view, Ctrl+C to stop
#   bash ops/projects/health/dashboard.sh --once   single snapshot
#
# Env: WS_HEALTH_MD_REFRESH (redraw seconds, default 20),
#      WS_HEALTH_CHECK_EVERY (run checks every N redraws, default 1),
#      WS_HEALTH_SOUND_DEBOUNCE (seconds between status sounds, default 5).

set -uo pipefail

WS_HEALTH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

render_md() {
    if command -v glow >/dev/null 2>&1; then
        glow - -w 0 -n
    else
        cat
    fi
}

if [[ "${1:-}" == "--once" ]]; then
    bash "$WS_HEALTH_DIR/monitor.sh" --json 2>/dev/null \
        | bash "$WS_HEALTH_DIR/pretty.sh" \
        | render_md
    exit
fi

# Live markdown health dashboard.
# refresh controls redraw frequency; check_every controls expensive check frequency.
refresh="${WS_HEALTH_MD_REFRESH:-20}"
check_every="${WS_HEALTH_CHECK_EVERY:-1}"
sound_debounce="${WS_HEALTH_SOUND_DEBOUNCE:-5}"
rendered=""
health_json=""
health_status="unknown"
health_rc=0
last_health_status=""
now_ts=0
last_sound_ts=0
sound_cmd=""
sound_ok=""
sound_fail=""
cycle=0

if [[ ! "$check_every" =~ ^[0-9]+$ ]] || (( check_every < 1 )); then
    check_every=1
fi

if command -v afplay >/dev/null 2>&1; then
    sound_cmd="afplay"
    sound_ok="/System/Library/Sounds/Ping.aiff"
    sound_fail="/System/Library/Sounds/Basso.aiff"
elif command -v paplay >/dev/null 2>&1; then
    sound_cmd="paplay"
    sound_ok="/usr/share/sounds/freedesktop/stereo/complete.oga"
    sound_fail="/usr/share/sounds/freedesktop/stereo/dialog-error.oga"
fi

while true; do
    ((cycle+=1))
    if (( (cycle - 1) % check_every == 0 )) || [[ -z "$rendered" ]]; then
        health_json="$(bash "$WS_HEALTH_DIR/monitor.sh" --json 2>/dev/null)"
        health_rc=$?

        if [[ -z "${health_json//[[:space:]]/}" ]] || ! jq -e '.overall.status' >/dev/null 2>&1 <<<"$health_json"; then
            health_status="fail"
            rendered="# Workspace Health\n\n- Status: **HALTED**\n- Cause: health check command returned invalid or empty JSON\n- Updated: $(date '+%Y-%m-%d %H:%M:%S')\n\n## Notes\n- Live health data is unavailable right now.\n- This view intentionally does **not** keep stale OK output.\n- Last command exit code: $health_rc\n- Run: bash $WS_HEALTH_DIR/monitor.sh --json\n"
        else
            health_status="$(jq -r '.overall.status // "unknown"' <<<"$health_json")"
            rendered="$(printf "%s\n" "$health_json" | bash "$WS_HEALTH_DIR/pretty.sh")"
        fi

        if [[ "$health_status" != "$last_health_status" ]]; then
            now_ts="$(date +%s)"
            if (( now_ts - last_sound_ts >= sound_debounce )); then
                if [[ "$health_status" == "ok" ]]; then
                    if [[ -n "$sound_cmd" && -f "$sound_ok" ]]; then
                        "$sound_cmd" "$sound_ok" >/dev/null 2>&1 &
                    else
                        printf '\a'
                    fi
                else
                    if [[ -n "$sound_cmd" && -f "$sound_fail" ]]; then
                        "$sound_cmd" "$sound_fail" >/dev/null 2>&1 &
                    else
                        printf '\a'
                    fi
                fi
                last_sound_ts="$now_ts"
            fi
            last_health_status="$health_status"
        fi
    fi

    if [[ -n "$rendered" ]]; then
        clear
        printf "%s\n" "$rendered" | render_md
        printf "\nupdated: %s | refresh: %ss | health-check cadence: every %s cycles (~%ss) | Ctrl+C to stop\n" "$(date +%H:%M:%S)" "$refresh" "$check_every" "$((refresh * check_every))"
    fi
    sleep "$refresh"
done
