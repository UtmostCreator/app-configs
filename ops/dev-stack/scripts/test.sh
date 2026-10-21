#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: test.sh <internal> [app-tests]"
assert_profile "$profile"
service=${2:-app-tests}
case "$service" in
	app-tests|app) target=app-tests ;;
	*) die "Unsupported test target '$service'. Valid targets: app-tests" ;;
esac

prepare_test_databases() {
	info "Preparing isolated test database..."
	compose test --profile test up -d --wait --wait-timeout 120 mariadb-test ||
		die "Could not start isolated test database"
	ok "Isolated test database ready"
}

step "Test - profile: $profile  target: $target"
prepare_test_databases
info "Running tests in $target..."
compose test --profile test run --rm --no-deps "$target" || die "$target failed"
ok "$target passed"
