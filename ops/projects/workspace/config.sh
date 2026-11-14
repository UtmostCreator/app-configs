#!/usr/bin/env bash
# Shared backend development constants.

WS_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_PROJECTS_ROOT_DIR="$(cd "$WS_SCRIPTS_DIR/.." && pwd)"
WS_TMUX_SCRIPTS_DIR="$WS_PROJECTS_ROOT_DIR/tmux"
WS_LOGGING_SCRIPTS_DIR="$WS_PROJECTS_ROOT_DIR/logging"
WS_HEALTH_SCRIPTS_DIR="$WS_PROJECTS_ROOT_DIR/health"
# Laravel Herd (macOS-only) keeps the apps in ~/Herd. Override on other hosts.
WS_HERD_ROOT_DIR="${WS_HERD_ROOT_DIR:-$HOME/Herd}"

WS_TMUX_SESSION="ws-dev"
WS_PANE_BACKEND="ws-backend"
WS_PANE_FRONTEND="ws-frontend"

WS_REDIS_CONTAINER_NAME="redis"
WS_REDIS_PORT="6379"

WS_FRONTEND_HOST="0.0.0.0"
WS_FRONTEND_PORT="3000"
WS_FRONTEND_TARGET_PORT="3001"
WS_FRONTEND_NETLIFY_CONTEXT="dev"
WS_NODE_RUNTIME="node@22"

WS_BACKEND_APP_DIR="$WS_HERD_ROOT_DIR/backend"
WS_FRONTEND_APP_DIR="$WS_HERD_ROOT_DIR/web-frontend"
WS_INTEGRATION_APP_DIR="$WS_HERD_ROOT_DIR/integration"
WS_UI_COMPONENTS_DIR="$WS_HERD_ROOT_DIR/ui-components"
WS_PAYMENTS_DIR="$WS_HERD_ROOT_DIR/payments"

WS_LOG_DIR="$HOME/logs"
WS_BACKEND_LOG_FILE="$WS_LOG_DIR/backend-npm.log"
WS_FRONTEND_LOG_FILE="$WS_LOG_DIR/web-frontend-npm.log"

WS_BACKEND_JUSTFILE="$WS_BACKEND_APP_DIR/justfile"

# macOS-only (Herd). verify-workspace treats a missing file as the default port.
WS_HERD_DNSMASQ_CONF="$HOME/Library/Application Support/Herd/config/dnsmasq/dnsmasq.conf"
WS_RESOLVER_TEST_FILE="/etc/resolver/test"
WS_HOSTS_FILE="/etc/hosts"
WS_DNSMASQ_DEFAULT_PORT="53"

WS_SCRIPT_OPEN_WORKSPACE="$WS_TMUX_SCRIPTS_DIR/master.sh"
WS_SCRIPT_RESTART="$WS_SCRIPTS_DIR/restart.sh"
WS_SCRIPT_REPO_CHECKS="$WS_HEALTH_SCRIPTS_DIR/repo-checks.sh"
WS_SCRIPT_VERIFY_WORKSPACE="$WS_HEALTH_SCRIPTS_DIR/verify-workspace.sh"
WS_SCRIPT_WATCH_LOGS="$WS_LOGGING_SCRIPTS_DIR/watch/watch.sh"
WS_SCRIPT_START_STACK="$WS_SCRIPTS_DIR/stack/start.sh"
WS_SCRIPT_STOP_STACK="$WS_SCRIPTS_DIR/stack/stop.sh"
WS_SCRIPT_START_FRONTEND="$WS_SCRIPTS_DIR/frontend/start.sh"
WS_SCRIPT_STOP_FRONTEND="$WS_SCRIPTS_DIR/frontend/stop.sh"
WS_SCRIPT_STOP_LOG_WATCH="$WS_LOGGING_SCRIPTS_DIR/watch/stop-watch.sh"
WS_SCRIPT_FRONTEND_DEBUG="$WS_SCRIPTS_DIR/frontend/debug.sh"
WS_SCRIPT_LOG_CAPTURE="$WS_LOGGING_SCRIPTS_DIR/capture.sh"

WS_TMP_RESTART_LOG="${TMPDIR:-/tmp}/ws-restart.log"

# ws_ensure_herd [--app]: make sure Herd's services (and, with --app, the Herd
# desktop app) are running. Herd is macOS-only, so on any other host the step
# is skipped with a single message instead of failing on `open`/`herd`.
ws_ensure_herd() {
	local os
	os="$(uname -s)"
	if [[ "$os" != Darwin ]]; then
		echo "Skipping Herd: Laravel Herd is macOS-only (this host is $os)."
		return 0
	fi
	if [[ "${1:-}" == --app ]]; then
		echo "Ensuring Herd app and services are running..."
		open -ga Herd >/dev/null 2>&1 || open -a Herd
	else
		echo "Ensuring Herd services are running..."
	fi
	herd start
}

# ws_ensure_docker: make sure a Docker daemon is reachable. macOS restarts
# the Colima VM (cpu=2, memory=2GiB, vm-type=vz) and logs to ~/logs/colima.
# Other hosts (WSL2, Linux) use the daemon that is already running (Docker
# Engine or Docker Desktop's WSL integration); Colima there would be a VM
# inside a VM, and vz is macOS-only.
ws_ensure_docker() {
	if [[ "$(uname -s)" != Darwin ]]; then
		if docker info >/dev/null 2>&1; then
			echo "Using the running Docker daemon (Colima is macOS-only here)."
			return 0
		fi
		echo "[ERROR] No Docker daemon reachable. Start Docker Engine (sudo systemctl start docker)" \
			"or enable Docker Desktop's WSL integration; see docs/platforms/wsl/setup.md." >&2
		return 1
	fi
	local log_dir="$HOME/logs/colima"
	local log_file
	log_file="$log_dir/colima-$(date +%F).log"
	mkdir -p "$log_dir"
	echo "Restarting Colima (cpu=2, memory=2GiB, vm-type=vz)..."
	{
		printf '[%s] colima stop\n' "$(date '+%Y-%m-%d %H:%M:%S')"
		colima stop
	} >>"$log_file" 2>&1 || true
	{
		printf '[%s] colima start --cpu 2 --memory 2 --vm-type vz\n' "$(date '+%Y-%m-%d %H:%M:%S')"
		colima start --cpu 2 --memory 2 --vm-type vz
	} >>"$log_file" 2>&1
	echo "Colima logs: $log_file"
}

# ws_ensure_redis: create the Redis container if missing, start it if
# stopped, and confirm it runs. Shared by start.sh and stack/start.sh, which
# carried identical copies.
ws_ensure_redis() {
	local name="$WS_REDIS_CONTAINER_NAME" status id
	if ! docker container inspect "$name" >/dev/null 2>&1; then
		echo "Creating Redis container..."
		docker run -d --name "$name" -p "$WS_REDIS_PORT:$WS_REDIS_PORT" redis:alpine >/dev/null
	fi
	status="$(docker inspect -f '{{.State.Status}}' "$name")"
	if [[ "$status" != running ]]; then
		echo "Starting Redis container..."
		docker start "$name" >/dev/null
		status="$(docker inspect -f '{{.State.Status}}' "$name")"
	fi
	if [[ "$status" != running ]]; then
		echo "[ERROR] Redis container is not running (status: $status)" >&2
		return 1
	fi
	id="$(docker inspect -f '{{.Id}}' "$name" | cut -c1-12)"
	echo "Redis container is running. ID: $id"
}

web_frontend_export_netlify_env() {
	local app_dir="${1:-$WS_FRONTEND_APP_DIR}"
	local key=""
	local value=""

	command -v netlify >/dev/null 2>&1 || return 0
	[[ -d "$app_dir" ]] || return 0

	for key in \
		BASIC_AUTH_CREDS \
		${WS_NETLIFY_ENV_KEYS:-}
	do
		if [[ -n "${!key:-}" ]]; then
			export "$key"
			continue
		fi

		value="$(cd "$app_dir" && netlify env:get "$key" --context "$WS_FRONTEND_NETLIFY_CONTEXT" 2>/dev/null || true)"
		if [[ -n "$value" ]]; then
			export "$key=$value"
		fi
	done
}
