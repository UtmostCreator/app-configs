#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"
. "$SCRIPT_DIR/lib/env.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: smoke.sh <internal> [--connectivity] [--workers] [--external-check]"
assert_profile "$profile"
shift
connectivity=false
workers=false
external_check=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--connectivity) connectivity=true ;;
		--workers) workers=true ;;
		--external-check) external_check=true ;;
		-h|--help) printf 'Usage: smoke.sh <internal> [--connectivity] [--workers] [--external-check]\n'; exit 0 ;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

failures=0
record_failure() { failures=$((failures + 1)); }

test_http() {
	label=$1
	url=$2
	accepted_status=$3
	if status_code=$(curl -sS -o /dev/null --max-time 10 -w '%{http_code}' "$url"); then
		case " $accepted_status " in
			*" $status_code "*) ok "$label: responded HTTP $status_code"; return 0 ;;
			*) fail "$label: returned HTTP $status_code (URL: $url)"; return 1 ;;
		esac
	fi
	fail "$label: unreachable at $url"
	return 1
}

test_tcp_port() {
	label=$1
	port=$2
	if command_exists nc && nc -z -w 3 127.0.0.1 "$port" >/dev/null 2>&1; then
		ok "$label: reachable at 127.0.0.1:$port"
		return 0
	fi
	if ! command_exists nc && curl -sS --connect-timeout 3 --max-time 3 "telnet://127.0.0.1:$port" >/dev/null 2>&1; then
		ok "$label: reachable at 127.0.0.1:$port"
		return 0
	fi
	fail "$label: not reachable at 127.0.0.1:$port"
	return 1
}

test_container_http() {
	label=$1
	service=$2
	url=$3
	accepted_status=$4
	if status_code=$(compose "$profile" exec -T "$service" curl -sS -o /dev/null --max-time 5 -w '%{http_code}' "$url" 2>/dev/null); then
		case " $accepted_status " in
			*" $status_code "*) ok "$label: $service -> $url (HTTP $status_code)"; return 0 ;;
		esac
	fi
	fail "$label: $service returned HTTP ${status_code:-unreachable} from $url"
	return 1
}

check_workers() {
	service=app-queue
	container_id=$(compose "$profile" --profile workers ps -aq "$service" 2>/dev/null || true)
	if [ -z "$container_id" ]; then
		fail "$service has no container"
		record_failure
		return
	fi
	state=$(docker inspect --format '{{.State.Status}}' "$container_id" 2>/dev/null || true)
	restarts=$(docker inspect --format '{{.RestartCount}}' "$container_id" 2>/dev/null || true)
	if [ "$state" != running ] || [ "${restarts:-0}" -gt 0 ]; then
		fail "$service is $state with restart count ${restarts:-unknown}"
		record_failure
	else
		ok "$service is running with restart count 0"
	fi
}

step "Smoke - profile: $profile"
if [ "$(get_env_value DEVSTACK_PUBLISH_DATA_PORTS false)" = true ]; then
	test_tcp_port "MariaDB" "$(get_env_port MARIADB_HOST_PORT 3306)" || record_failure
	test_tcp_port "Redis" "$(get_env_port REDIS_HOST_PORT 6380)" || record_failure
fi
test_http "Example App" "http://localhost:$(get_env_port EXAMPLE_APP_PORT 8080)" '200 301 302 401 403' || record_failure

if [ "$connectivity" = true ]; then
	step "Connectivity checks..."
	if [ -n "$(compose "$profile" ps -q app)" ]; then
		test_container_http "App->Nginx" app http://app-nginx/healthz '200' || record_failure
	fi
fi

[ "$connectivity" = true ] && workers=true
[ "$workers" = true ] && check_workers

if [ "$external_check" = true ]; then
	step "External call audit (last 60 seconds of logs)..."
	# Any URL in the logs with a dotted host (not a single-label stack service name or localhost) counts as external.
	external_hosts=$(compose "$profile" logs --since 60s 2>&1 |
		grep -Eo 'https?://[A-Za-z0-9.-]+' |
		sed 's#^https\{0,1\}://##' |
		grep -Ev '^([^.]*|127\.0\.0\.1|example\.test)$' |
		sort -u || true)
	for host in $external_hosts; do
		fail "External host contacted or referenced in logs: $host"
		record_failure
	done
fi

printf '\n'
if [ "$failures" -eq 0 ]; then
	ok "All smoke checks passed"
else
	fail "$failures smoke check(s) failed"
	exit 1
fi
