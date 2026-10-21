#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/env.sh"
. "$SCRIPT_DIR/lib/compose.sh"

profile=${1:-internal}
assert_profile "$profile"
failed=false
compose_available=false

check_port() {
	label=$1
	port=$2
	if ! command_exists nc && ! command_exists curl; then
		warn "Could not check port $port ($label): nc or curl is required"
		return
	fi
	if ! port_is_in_use "$port"; then
		ok "Port $port ($label) is free"
		return
	fi
	if [ -n "$(docker ps -q --filter "publish=$port" --filter "label=com.docker.compose.project=$(get_compose_project_name)")" ]; then
		ok "Port $port ($label) is held by this Compose project"
	else
		fail "Port $port ($label) is already in use by another process"
		failed=true
	fi
}

step "Doctor - checking prerequisites"
if command_exists docker; then
	if docker info >/dev/null 2>&1; then ok "Docker is running"; else fail "Docker is not running or not accessible"; failed=true; fi
	if docker compose version >/dev/null 2>&1; then ok "Docker Compose v2 available"; compose_available=true; else fail "Docker Compose v2 not available"; failed=true; fi
else
	fail "Docker command not found"
	failed=true
fi
if [ "$compose_available" = true ]; then
	if COMPOSE_VERSION_CHECKED=true "$SCRIPT_DIR/validate-compose.sh" "$profile"; then :; else failed=true; fi
fi

if command_exists git; then ok "Git available ($(git --version))"; else fail "Git not found"; failed=true; fi
if command_exists curl; then ok "curl available"; else fail "curl is required"; failed=true; fi
if command_exists awk; then ok "awk available"; else fail "awk is required"; failed=true; fi

if [ -f "$STACK_ROOT/.env" ]; then ok ".env file exists"; else warn ".env not found - setup will create it from .env.example"; fi
if [ -f "$STACK_ROOT/.env" ]; then
	if validate_stack_env_file "$STACK_ROOT/.env"; then
		ok ".env grammar is valid"
	else
		fail ".env grammar is invalid"
		failed=true
	fi
fi

info "Checking host ports for the $profile profile..."
check_port "Example App" "$(get_env_port EXAMPLE_APP_PORT 8080)"
if [ "$(get_env_value DEVSTACK_PUBLISH_DATA_PORTS false)" = true ]; then
	check_port "MariaDB" "$(get_env_port MARIADB_HOST_PORT 3306)"
	check_port "Redis" "$(get_env_port REDIS_HOST_PORT 6380)"
else
	info "MariaDB and Redis host ports are disabled (set DEVSTACK_PUBLISH_DATA_PORTS=true to publish them)"
fi

if [ "$failed" = true ]; then
	fail "Doctor found blocking issues - resolve them before running setup"
	exit 1
fi
ok "Doctor passed"
