#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"
. "$SCRIPT_DIR/lib/repos.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: install-deps.sh <internal> [app]"
assert_profile "$profile"
app=${2:-example-app}

run_composer_command() {
	if [ -n "${COMPOSER_AUTH:-}" ]; then
		compose_tools --profile tools run --rm --no-deps -e COMPOSER_PROCESS_TIMEOUT=0 -e COMPOSER_AUTH composer "$@"
	else
		compose_tools --profile tools run --rm --no-deps -e COMPOSER_PROCESS_TIMEOUT=0 composer "$@"
	fi
}

install_dependencies() {
	service=$1
	workdir=$2

	assert_clean_composer_files example-app

	info "composer install - $service"
	run_composer_command composer install --no-interaction --prefer-dist --optimize-autoloader --no-scripts || die "composer install failed for $service"
	compose "$profile" run --rm --no-deps --workdir "$workdir" "$service" \
		php artisan package:discover --ansi || die "Laravel package discovery failed for $service"
	ok "$service - dependencies installed"
}

case "$app" in
	example-app) ;;
	*) die "Unsupported app '$app'. Valid apps: example-app" ;;
esac

step "Install dependencies - profile: $profile  app: $app"
assert_safe_app_environment "$profile" "$app"
install_dependencies app /var/www/html
