#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../config.sh"

SESSION="$WS_TMUX_SESSION"
PANE_TITLE="$WS_PANE_FRONTEND"
PROCESS_PATTERNS=(
    "node .*netlify dev"
    "node .*web-frontend/node_modules/.bin/nuxt dev"
    "node .*web-frontend/node_modules/.bin/nuxt( |$)"
    "node .*web-frontend/node_modules/.bin/nuxi dev"
    "node .*web-frontend/node_modules/.bin/nuxi( |$)"
    "node .*web-frontend.*nuxi.* dev"
    "npm run dev.*web-frontend"
)

STOP_WAIT_SECONDS=8

is_pid_running() {
    local pid="$1"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

is_frontend_command() {
    local command_line="$1"

    [[ "$command_line" == *"$WS_FRONTEND_APP_DIR"* ]] \
        || [[ "$command_line" == *"netlify dev"* ]] \
        || [[ "$command_line" == *"frontend dev"* ]] \
        || [[ "$command_line" == *"nuxi dev"* ]]
}

collect_frontend_pids() {
    local -a pids=()
    local pattern
    local pid

    for pattern in "${PROCESS_PATTERNS[@]}"; do
        while IFS= read -r pid; do
            [[ -n "$pid" ]] || continue
            pids+=("$pid")
        done < <(pgrep -f "$pattern" 2>/dev/null || true)
    done

    printf '%s\n' "${pids[@]}" | awk 'NF && !seen[$0]++ { print $0 }'
}

wait_for_pids_exit() {
    local -a pids=("$@")
    local seconds=0
    local pid
    local all_stopped

    while (( seconds < STOP_WAIT_SECONDS )); do
        all_stopped=1
        for pid in "${pids[@]}"; do
            if is_pid_running "$pid"; then
                all_stopped=0
                break
            fi
        done

        if (( all_stopped == 1 )); then
            return 0
        fi

        sleep 1
        ((seconds+=1))
    done

    return 1
}

wait_for_port_release() {
    local port="$1"
    local seconds=0

    while (( seconds < STOP_WAIT_SECONDS )); do
        if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
            return 0
        fi

        sleep 1
        ((seconds+=1))
    done

    return 1
}

kill_frontend_listener_on_port() {
    local port="$1"
    local listener_pid
    listener_pid="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true)"

    if [[ -z "$listener_pid" ]]; then
        return 0
    fi

    local listener_cmd
    listener_cmd="$(ps -p "$listener_pid" -o command= 2>/dev/null || true)"

    # Guardrail: only kill listeners that belong to web-frontend processes.
    if is_frontend_command "$listener_cmd"; then
        kill "$listener_pid" 2>/dev/null || true
    fi
}

if tmux has-session -t "$SESSION" 2>/dev/null; then
    pane_id="$(tmux list-panes -a -F '#{session_name}	#{pane_title}	#{pane_id}' | awk -F '	' -v session="$SESSION" -v title="$PANE_TITLE" '$1 == session && $2 == title { print $3; exit }')"

    if [ -n "$pane_id" ]; then
        tmux send-keys -t "$pane_id" C-c
        # Give pane-managed commands a moment to terminate before fallback cleanup.
        sleep 1
    fi
fi

frontend_pids=()
while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    frontend_pids+=("$pid")
done < <(collect_frontend_pids)

if (( ${#frontend_pids[@]} > 0 )); then
    kill "${frontend_pids[@]}" 2>/dev/null || true

    if ! wait_for_pids_exit "${frontend_pids[@]}"; then
        kill -9 "${frontend_pids[@]}" 2>/dev/null || true
    fi
fi

kill_frontend_listener_on_port "$WS_FRONTEND_PORT"
kill_frontend_listener_on_port "$WS_FRONTEND_TARGET_PORT"

if ! wait_for_port_release "$WS_FRONTEND_PORT"; then
    kill_frontend_listener_on_port "$WS_FRONTEND_PORT"
fi

if ! wait_for_port_release "$WS_FRONTEND_TARGET_PORT"; then
    kill_frontend_listener_on_port "$WS_FRONTEND_TARGET_PORT"
fi
