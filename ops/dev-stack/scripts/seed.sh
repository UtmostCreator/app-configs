#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"
. "$SCRIPT_DIR/lib/env.sh"
. "$SCRIPT_DIR/lib/seed-policy.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: seed.sh <internal> [--scenario <name>]"
assert_profile "$profile"
shift
scenario=minimal-standing-stack
while [ "$#" -gt 0 ]; do
	case "$1" in
		--scenario)
			shift
			require_value "--scenario" "${1:-}"
			scenario=$1
			;;
		-h|--help) printf 'Usage: seed.sh <internal> [--scenario <name>]\n'; exit 0 ;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

case "$scenario" in
	minimal-standing-stack) ;;
	*) die "Unknown seed scenario '$scenario'. Valid scenarios: minimal-standing-stack" ;;
esac

step "Seed - profile: $profile  scenario: $scenario"
assert_safe_app_environment "$profile"

admin_password=$(get_env_value EXAMPLE_APP_ADMIN_PASSWORD)
[ -n "$admin_password" ] || die "EXAMPLE_APP_ADMIN_PASSWORD is not set; add it to .env"

run_required "example-app seeding" \
	compose "$profile" run --rm --no-deps --workdir /var/www/html app \
	php artisan db:seed --force --no-interaction

# The password is passed through the container environment so it never lands in a command line string.
admin_bootstrap='$user = \App\Models\User::firstOrNew(["email" => "admin@example.test"]); $user->name = "Local Admin"; $user->password = \Illuminate\Support\Facades\Hash::make(getenv("SEED_ADMIN_PASSWORD")); $user->save();'
run_required "example-app local admin provisioning" \
	compose "$profile" run --rm --no-deps --workdir /var/www/html -e SEED_ADMIN_PASSWORD="$admin_password" app \
	php artisan tinker --execute "$admin_bootstrap"

run_optional "local application cache cleanup" \
	compose "$profile" run --rm --no-deps app php artisan optimize:clear

ok "Seeding complete"
