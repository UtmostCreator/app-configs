#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../config.sh"

LOG_DIR="$WS_LOG_DIR"
LOG_FILE="$WS_FRONTEND_LOG_FILE"
APP_DIR="$WS_FRONTEND_APP_DIR"
MODE="background"
START_ATTEMPTS="${WS_FRONTEND_START_ATTEMPTS:-3}"
START_WAIT_SECONDS="${WS_FRONTEND_START_WAIT_SECONDS:-45}"
START_WAIT_SLEEP="${WS_FRONTEND_START_WAIT_SLEEP:-2}"
READY_PATH="${WS_FRONTEND_READY_PATH:-/region-a}"

PROCESS_PATTERNS=(
	"node .*netlify dev"
	"node .*web-frontend/node_modules/.bin/nuxt dev"
	"node .*web-frontend/node_modules/.bin/nuxt( |$)"
	"node .*web-frontend/node_modules/.bin/nuxi dev"
	"node .*web-frontend/node_modules/.bin/nuxi( |$)"
	"node .*web-frontend.*nuxi.* dev"
	"npm run dev.*web-frontend"
)

usage() {
	cat <<EOF
Usage: $(basename "$0") [--background|--foreground]

Starts the web-frontend Netlify/Frontend dev server.
Default mode runs in the background and writes logs to $LOG_FILE.
EOF
}

is_pid_running() {
	local pid="$1"
	[[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

frontend_auth_header() {
	local creds=""
	local pair=""
	local encoded=""

	if [[ -n "${BASIC_AUTH_CREDS:-}" ]]; then
		creds="$BASIC_AUTH_CREDS"
	elif command -v netlify >/dev/null 2>&1 && [[ -d "$APP_DIR" ]]; then
		creds="$(cd "$APP_DIR" && netlify env:get BASIC_AUTH_CREDS --context "$WS_FRONTEND_NETLIFY_CONTEXT" 2>/dev/null || true)"
	fi

	pair="${creds%% *}"
	[[ -n "$pair" ]] || return 0

	encoded="$(printf '%s' "$pair" | base64 | tr -d '\n')"
	printf 'Authorization: Basic %s\n' "$encoded"
}

find_listener_pid() {
	local port="$1"
	lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true
}

is_frontend_command() {
	local command_line="$1"

	[[ "$command_line" == *"$APP_DIR"* ]] \
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

	printf '%s\n' "${pids[@]-}" | awk 'NF && !seen[$0]++ { print $0 }'
}

existing_frontend_pid() {
	local pid=""
	local command_line=""

	while IFS= read -r pid; do
		[[ -n "$pid" ]] || continue
		if ! is_pid_running "$pid"; then
			continue
		fi

		command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
		if is_frontend_command "$command_line"; then
			printf '%s\n' "$pid"
			return 0
		fi
	done < <(collect_frontend_pids)

	pid="$(find_listener_pid "$WS_FRONTEND_PORT")"
	if [[ -n "$pid" ]]; then
		command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
		if is_frontend_command "$command_line"; then
			printf '%s\n' "$pid"
			return 0
		fi
	fi

	pid="$(find_listener_pid "$WS_FRONTEND_TARGET_PORT")"
	if [[ -n "$pid" ]]; then
		command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
		if is_frontend_command "$command_line"; then
			printf '%s\n' "$pid"
			return 0
		fi
	fi

	return 1
}

ensure_ports_available() {
	local public_pid=""
	local target_pid=""
	local command_line=""

	public_pid="$(find_listener_pid "$WS_FRONTEND_PORT")"
	if [[ -n "$public_pid" ]]; then
		command_line="$(ps -p "$public_pid" -o command= 2>/dev/null || true)"
		if ! is_frontend_command "$command_line"; then
			echo "Port $WS_FRONTEND_PORT is already in use by PID $public_pid." >&2
			return 1
		fi
	fi

	target_pid="$(find_listener_pid "$WS_FRONTEND_TARGET_PORT")"
	if [[ -n "$target_pid" ]]; then
		command_line="$(ps -p "$target_pid" -o command= 2>/dev/null || true)"
		if ! is_frontend_command "$command_line"; then
			echo "Port $WS_FRONTEND_TARGET_PORT is already in use by PID $target_pid." >&2
			return 1
		fi
	fi

	return 0
}

ensure_netlify_cli() {
	if command -v netlify >/dev/null 2>&1; then
		return 0
	fi

	echo "netlify CLI not found. Install it first or add it to PATH." >&2
	return 1
}

ensure_frontend_dependencies() {
	if [[ -f "$APP_DIR/node_modules/frontend/package.json" || -f "$APP_DIR/node_modules/nuxi/package.json" ]]; then
		return 0
	fi

	echo "Frontend package not found in $APP_DIR/node_modules. Installing frontend dependencies..."
	if [[ -f "$APP_DIR/package-lock.json" ]]; then
		(cd "$APP_DIR" && npm ci)
	else
		(cd "$APP_DIR" && npm install)
	fi
}

run_frontend_dev() {
	mise exec "$WS_NODE_RUNTIME" -- env NODE_ENV=development APP_DEBUG=true BROWSER=none \
		netlify dev \
			--offline \
			--context "$WS_FRONTEND_NETLIFY_CONTEXT" \
			--port "$WS_FRONTEND_PORT" \
			--target-port "$WS_FRONTEND_TARGET_PORT" \
			--command "npm run dev -- --host $WS_FRONTEND_HOST --port $WS_FRONTEND_TARGET_PORT" \
			--no-open
}

wait_for_frontend_ready() {
	local launcher_pid="$1"
	local waited=0
	local http_code=""
	local auth_header=""
	local ready_url="http://localhost:${WS_FRONTEND_PORT}${READY_PATH}"

	auth_header="$(frontend_auth_header || true)"

	while (( waited < START_WAIT_SECONDS )); do
		if ! is_pid_running "$launcher_pid"; then
			return 1
		fi

		if [[ -n "$auth_header" ]]; then
			http_code="$(curl -H "$auth_header" -sSo /dev/null -w '%{http_code}' --max-time 5 "$ready_url" 2>/dev/null || true)"
		else
			http_code="$(curl -sSo /dev/null -w '%{http_code}' --max-time 5 "$ready_url" 2>/dev/null || true)"
		fi
		if [[ -n "$http_code" && "$http_code" != "000" ]]; then
			return 0
		fi

		if [[ -z "$auth_header" && ( "$http_code" == "401" || "$http_code" == "403" ) ]]; then
			return 0
		fi

		sleep "$START_WAIT_SLEEP"
		((waited+=START_WAIT_SLEEP))
	done

	return 1
}

stop_failed_attempt() {
	local launcher_pid="$1"

	if is_pid_running "$launcher_pid"; then
		kill "$launcher_pid" 2>/dev/null || true
	fi

	bash "$WS_SCRIPT_STOP_FRONTEND" >/dev/null 2>&1 || true
}

start_background() {
	local frontend_pid=""
	local attempt=1
	local ready_url="http://localhost:${WS_FRONTEND_PORT}${READY_PATH}"

	frontend_pid="$(existing_frontend_pid || true)"
	if [[ -n "$frontend_pid" ]]; then
		echo "web-frontend is already running with PID $frontend_pid."
		echo "Logs: $LOG_FILE"
		return 0
	fi

	ensure_ports_available

	printf '%s\n' "starting web-frontend" \
		| bash "$WS_SCRIPT_LOG_CAPTURE" --label FRONTEND-NPM --output "$LOG_FILE" --quiet

	cd "$APP_DIR"
	ensure_netlify_cli
	ensure_frontend_dependencies
	web_frontend_export_netlify_env "$APP_DIR"

	while (( attempt <= START_ATTEMPTS )); do
		echo "Starting web-frontend in background (attempt ${attempt}/${START_ATTEMPTS})..."
		echo "Waiting for $ready_url"

		printf '%s\n' "starting web-frontend (attempt ${attempt}/${START_ATTEMPTS})" \
			| bash "$WS_SCRIPT_LOG_CAPTURE" --label FRONTEND-NPM --output "$LOG_FILE" --quiet

		# shellcheck disable=SC2016 # Positional parameters are expanded by the child bash.
		nohup mise exec "$WS_NODE_RUNTIME" -- bash -c '
			set -o pipefail
			cd "$1"
			env NODE_ENV=development APP_DEBUG=true BROWSER=none \
				netlify dev \
					--offline \
					--context "$2" \
					--port "$3" \
					--target-port "$4" \
					--command "npm run dev -- --host $5 --port $4" \
					--no-open \
					2>&1 \
				| bash "$6" --label FRONTEND-NPM --output "$7" --quiet
		' bash "$APP_DIR" "$WS_FRONTEND_NETLIFY_CONTEXT" "$WS_FRONTEND_PORT" "$WS_FRONTEND_TARGET_PORT" "$WS_FRONTEND_HOST" "$WS_SCRIPT_LOG_CAPTURE" "$LOG_FILE" >/dev/null 2>&1 &

		frontend_pid="$!"
		disown || true

		if wait_for_frontend_ready "$frontend_pid"; then
			echo "Started web-frontend in background with PID $frontend_pid"
			echo "Ready: $ready_url"
			echo "Logs: $LOG_FILE"
			return 0
		fi

		echo "web-frontend attempt ${attempt}/${START_ATTEMPTS} did not become ready; retrying..." >&2
		stop_failed_attempt "$frontend_pid"
		frontend_pid=""
		((attempt+=1))
	done

	echo "web-frontend failed to become ready on http://localhost:$WS_FRONTEND_PORT$READY_PATH after ${START_ATTEMPTS} attempts." >&2
	echo "Check logs: $LOG_FILE" >&2
	return 1
}

start_foreground() {
	local ready_url="http://localhost:${WS_FRONTEND_PORT}${READY_PATH}"

	echo "Writing logs to $LOG_FILE"
	echo "Expected ready URL: $ready_url"
	echo "Logs: $LOG_FILE"
}

for arg in "$@"; do
	case "$arg" in
		--background)
			MODE="background"
			;;
		--foreground)
			MODE="foreground"
			;;
		help|-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $arg" >&2
			usage >&2
			exit 1
			;;
	esac
	done

mkdir -p "$LOG_DIR"

if [[ "$MODE" == "background" ]]; then
	start_background
	exit 0
fi

cd "$APP_DIR"
ensure_netlify_cli
ensure_frontend_dependencies
web_frontend_export_netlify_env "$APP_DIR"
start_foreground
run_frontend_dev 2>&1 | bash "$WS_SCRIPT_LOG_CAPTURE" --label FRONTEND-NPM --output "$LOG_FILE"
