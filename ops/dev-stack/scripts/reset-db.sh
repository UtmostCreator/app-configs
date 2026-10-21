#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"
. "$SCRIPT_DIR/lib/env.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: reset-db.sh <internal> [--yes]"
assert_profile "$profile"
shift
assume_yes=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--yes) assume_yes=true ;;
		-h|--help) printf 'Usage: reset-db.sh <internal> [--yes]\n'; exit 0 ;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

if [ "$assume_yes" = false ]; then
	printf '\n'
	warn "This will DROP and re-create all local databases. All local data will be lost."
	printf "Type 'yes' to continue: "
	IFS= read -r answer
	[ "$answer" = yes ] || { info "Aborted"; exit 0; }
fi

step "Reset DB - profile: $profile"
drop_sql='DROP DATABASE IF EXISTS example_app; DROP DATABASE IF EXISTS example_app_test;'
info "Dropping databases..."
compose "$profile" exec -T mariadb sh -c 'mysql -uroot -p"$MARIADB_ROOT_PASSWORD" -e "$1"' sh "$drop_sql"
info "Re-running init SQL..."
compose "$profile" exec -T mariadb sh /docker-entrypoint-initdb.d/01-create-databases.sh
ok "Databases re-created"
