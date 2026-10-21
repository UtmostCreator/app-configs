#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"
. "$SCRIPT_DIR/lib/repos.sh"
. "$SCRIPT_DIR/lib/env.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: up.sh <internal>"
assert_profile "$profile"
shift
start_workers=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--workers|--all) start_workers=true ;;
		-h|--help) printf 'Usage: up.sh <internal> [--workers|--all]\n'; exit 0 ;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

active_branch() {
	repository_name=$1
	repository_path="$WORKSPACE_ROOT/$(repo_field "$repository_name" folder)"

	branch=$(git -C "$repository_path" symbolic-ref --short -q HEAD 2>/dev/null || true)
	if [ -n "$branch" ]; then
		printf '%s\n' "$branch"
		return
	fi

	revision=$(git -C "$repository_path" rev-parse --short HEAD 2>/dev/null || true)
	if [ -n "$revision" ]; then
		printf 'detached@%s\n' "$revision"
		return
	fi

	printf 'unavailable\n'
}

assert_no_pending_migrations() {
	service=$1
	workdir=$2
	info "Checking migration readiness - $service"
	if ! status_output=$(compose "$profile" run --rm --no-deps --workdir "$workdir" "$service" \
		php artisan migrate:status --pending --no-interaction 2>&1); then
		printf '%s\n' "$status_output" >&2
		die "Could not determine migration readiness for $service"
	fi
	if printf '%s\n' "$status_output" | grep -Eq '[[:space:]]Pending[[:space:]]*$'; then
		printf '%s\n' "$status_output" >&2
		die "Pending migrations detected for $service"
	fi
	ok "$service has no pending migrations"
}

step "Validating application environments..."
assert_profile_repositories "$profile"
assert_safe_app_environment "$profile"

ensure_redis_host_port "$profile"

step "Starting profile '$profile'..."
compose internal --profile internal up -d --wait --wait-timeout 120
ok "Profile '$profile' started"

if [ "$start_workers" = true ]; then
	step "Checking schema readiness before starting workers..."
	assert_no_pending_migrations app /var/www/html

	step "Starting workers for profile '$profile'..."
	compose internal --profile internal --profile workers up -d --wait --wait-timeout 120
	ok "Workers started"
fi

printf '\n  Accessible services:\n'
printf '  Example App    http://localhost:%s/login\n' "$(get_env_port EXAMPLE_APP_PORT 8080)"

printf '\n  Active branches:\n'
printf '  Example App    %s\n' "$(active_branch example-app)"

printf '\n  Local admin user:\n'
printf '  Example App    admin@example.test (password: EXAMPLE_APP_ADMIN_PASSWORD from .env)\n'
