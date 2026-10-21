#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: migrate.sh <internal>"
assert_profile "$profile"

migrate_service() {
	service=$1
	workdir=$2
	info "migrate - $service"
	if compose "$profile" run --rm --no-deps --workdir "$workdir" "$service" php artisan migrate --force --no-interaction; then
		ok "$service migrated"
	else
		die "migrate failed for $service"
	fi
}

step "Migrations - profile: $profile"
assert_safe_app_environment "$profile"
migrate_service app /var/www/html
