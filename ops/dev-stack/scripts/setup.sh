#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"
. "$SCRIPT_DIR/lib/env.sh"
. "$SCRIPT_DIR/lib/repos.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: setup.sh <internal> [--force-env] [--skip-build]"
assert_profile "$profile"
shift
force_env=false
skip_build=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--force-env) force_env=true ;;
		--skip-build) skip_build=true ;;
		-h|--help) printf 'Usage: setup.sh <internal> [--force-env] [--skip-build]\n'; exit 0 ;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

copy_env_template() {
	app_name=$1
	template_name=$2
	destination=$3
	source_file="$STACK_ROOT/templates/env/$template_name"
	destination_file="$WORKSPACE_ROOT/$destination"
	destination_dir=$(dirname -- "$destination_file")
	# Later setup steps (key:generate) write .env, so a tracked .env is refused even when it already exists.
	if git -C "$destination_dir" ls-files --error-unmatch .env >/dev/null 2>&1; then
		die "$app_name .env is tracked by Git in $destination_dir - refusing to create or overwrite it"
	else
		git_status=$?
		[ "$git_status" -eq 1 ] || die "Unable to verify whether $app_name .env is tracked in $destination_dir - refusing to create or overwrite it"
	fi
	if [ ! -f "$source_file" ]; then
		warn "Template not found: $source_file"
		return 0
	fi
	if [ -f "$destination_file" ] && [ "$force_env" = false ]; then
		ok "$app_name .env already exists (use --force-env to overwrite)"
		return 0
	fi
	cp "$source_file" "$destination_file"
	ok "$app_name .env copied from template"
}

verify_npm_auth() {
	[ -s "$(npm_credentials_file)" ] || die "Private npm registry credentials are missing. Run ./scripts/setup-npm-auth.sh, then rerun setup."
	info "Verifying private npm registry authentication..."
	compose_tools --profile tools run --rm --no-deps node npm view @example-org/example-ui version --registry="$(get_env_value DEVSTACK_NPM_REGISTRY)" >/dev/null ||
		die "Private npm registry authentication failed. Run ./scripts/setup-npm-auth.sh again."
	ok "Private npm registry authentication verified"
}

app_key_is_blank() {
	case "$1" in
		''|'#'*) return 0 ;;
		'""'*|"''"*) ;;
		*) return 1 ;;
	esac
	app_key_remainder=$(printf '%s\n' "$1" | sed 's/^..//; s/^[[:space:]]*//')
	case "$app_key_remainder" in
		''|'#'*) return 0 ;;
		*) return 1 ;;
	esac
}

generate_app_key() {
	service=$1
	workdir=$2
	app_name=$3
	app_env="$WORKSPACE_ROOT/$app_name/.env"
	app_key=
	[ -f "$app_env" ] && app_key=$(read_env_file_value APP_KEY "$app_env")
	if ! app_key_is_blank "$app_key"; then
		ok "$service - APP_KEY already set"
		return 0
	fi
	compose "$profile" run --rm --no-deps --workdir "$workdir" "$service" php artisan key:generate --force || die "$service - APP_KEY generation failed"
	ok "$service - APP_KEY generated"
}

wait_for_mariadb() {
	info "Waiting for MariaDB to be ready..."
	waited=0
	max_wait=120
	health=
	while [ "$waited" -lt "$max_wait" ]; do
		mariadb_id=$(compose "$profile" ps -q mariadb)
		if [ -n "$mariadb_id" ]; then
			health=$(docker inspect --format '{{.State.Health.Status}}' "$mariadb_id" 2>/dev/null || true)
			[ "$health" = healthy ] && break
		fi
		sleep 5
		waited=$((waited + 5))
	done
	[ "$health" = healthy ] || die "MariaDB did not become healthy within ${max_wait}s"
	ok "MariaDB is healthy"
}

ensure_mariadb_users() {
	info "Reconciling local MariaDB users and grants..."
	compose "$profile" exec -T mariadb sh /docker-entrypoint-initdb.d/01-create-databases.sh || die "MariaDB user reconciliation failed"
	ok "MariaDB users and grants reconciled"
}

step "Running doctor..."
"$SCRIPT_DIR/doctor.sh" "$profile"

stack_env="$STACK_ROOT/.env"
if [ ! -f "$stack_env" ]; then
	cp "$STACK_ROOT/.env.example" "$stack_env"
	ok "Created .env from .env.example"
else
	ok ".env already exists"
fi

ensure_redis_host_port "$profile"

step "Verifying repos for profile '$profile'..."
assert_profile_repositories "$profile"
for repository_name in $(get_profile_repos "$profile"); do ok "$repository_name identity and required files verified"; done

step "Copying env templates..."
copy_env_template example-app example-app.env example-app/.env
if [ "$(get_env_value DEVSTACK_REQUIRE_NPM_AUTH false)" = true ]; then
	verify_npm_auth
fi

step "Validating application environments..."
assert_safe_app_environment "$profile"

if [ "$skip_build" = false ]; then
	step "Building Docker images..."
	compose internal --profile internal build --parallel || die "Image build failed"
	ok "Images built"
fi

info "Reconciling Composer cache ownership..."
compose "$profile" run --rm --no-deps --user 0 --entrypoint sh app \
	-c "mkdir -p /tmp/composer/cache && chown -R $(get_env_value LOCAL_UID "$(id -u)"):$(get_env_value LOCAL_GID "$(id -g)") /tmp/composer" ||
	die "Unable to reconcile Composer cache ownership"
ok "Composer cache ownership reconciled"

step "Starting infrastructure (mariadb, redis)..."
compose "$profile" up -d mariadb redis || die "Failed to start infrastructure"
wait_for_mariadb
ensure_mariadb_users

step "Ensuring Laravel runtime directories..."
for runtime_dir in bootstrap/cache storage/framework/cache/data storage/framework/sessions storage/framework/testing storage/framework/views storage/logs; do
	mkdir -p "$WORKSPACE_ROOT/example-app/$runtime_dir"
done
ok "example-app runtime directories ready"

step "Installing dependencies..."
"$SCRIPT_DIR/install-deps.sh" "$profile"

step "Generating missing APP_KEYs..."
generate_app_key app /var/www/html example-app

step "Running migrations..."
"$SCRIPT_DIR/migrate.sh" "$profile"

step "Running seeders..."
if ! "$SCRIPT_DIR/seed.sh" "$profile"; then
	die "Required seed or provisioning operation failed; standing application services were not started"
fi

step "Starting standing services and workers for profile '$profile'..."
"$SCRIPT_DIR/up.sh" "$profile" --all

step "Running smoke checks..."
"$SCRIPT_DIR/smoke.sh" "$profile" --workers

printf '\n========================================\n  Stack is up - %s profile\n========================================\n\n' "$profile"
printf '  Example App    http://localhost:%s\n' "$(get_env_port EXAMPLE_APP_PORT 8080)"
if [ "$(get_env_value DEVSTACK_PUBLISH_DATA_PORTS false)" = true ]; then
	printf '\n  MariaDB        localhost:%s\n  Redis          localhost:%s\n\n' "$(get_env_port MARIADB_HOST_PORT 3306)" "$(get_env_port REDIS_HOST_PORT 6380)"
fi
