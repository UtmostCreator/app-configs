#!/usr/bin/env bash
# Shared backend development constants.

WS_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_PROJECTS_ROOT_DIR="$(cd "$WS_SCRIPTS_DIR/.." && pwd)"
WS_TMUX_SCRIPTS_DIR="$WS_PROJECTS_ROOT_DIR/tmux"
WS_LOGGING_SCRIPTS_DIR="$WS_PROJECTS_ROOT_DIR/logging"
WS_HEALTH_SCRIPTS_DIR="$WS_PROJECTS_ROOT_DIR/health"
WS_HERD_ROOT_DIR="$HOME/Herd"

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

WS_HERD_DNSMASQ_CONF="$HOME/Library/Application Support/Herd/config/dnsmasq/dnsmasq.conf"
WS_RESOLVER_TEST_FILE="/etc/resolver/test"
WS_HOSTS_FILE="/etc/hosts"
WS_DNSMASQ_DEFAULT_PORT="53"

WS_SCRIPT_OPEN_WORKSPACE="$WS_TMUX_SCRIPTS_DIR/master.sh"
WS_SCRIPT_RESTART="$WS_SCRIPTS_DIR/restart.sh"
WS_SCRIPT_REPO_CHECKS="$WS_HEALTH_SCRIPTS_DIR/repo-checks.sh"
WS_SCRIPT_VERIFY_WORKSPACE="$WS_HEALTH_SCRIPTS_DIR/verify-workspace.sh"
WS_SCRIPT_WATCH_LOGS="$WS_LOGGING_SCRIPTS_DIR/workspace/watch.sh"
WS_SCRIPT_START_STACK="$WS_SCRIPTS_DIR/stack/start.sh"
WS_SCRIPT_STOP_STACK="$WS_SCRIPTS_DIR/stack/stop.sh"
WS_SCRIPT_START_FRONTEND="$WS_SCRIPTS_DIR/frontend/start.sh"
WS_SCRIPT_STOP_FRONTEND="$WS_SCRIPTS_DIR/frontend/stop.sh"
WS_SCRIPT_STOP_LOG_WATCH="$WS_LOGGING_SCRIPTS_DIR/workspace/stop-watch.sh"
WS_SCRIPT_FRONTEND_DEBUG="$WS_SCRIPTS_DIR/frontend/debug.sh"
WS_SCRIPT_LOG_CAPTURE="$WS_LOGGING_SCRIPTS_DIR/capture.sh"

WS_TMP_RESTART_LOG="${TMPDIR:-/tmp}/ws-restart.log"

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
