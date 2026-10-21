#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"
. "$SCRIPT_DIR/lib/env.sh"

usage() {
	printf 'Usage: import-db.sh <example-app> <absolute-path.sql|absolute-path.sql.gz> [--yes]\n'
}

[ "$#" -ge 2 ] || { usage; exit 2; }
app=$1
dump_path=$2
shift 2
assume_yes=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--yes) assume_yes=true ;;
		-h|--help) usage; exit 0 ;;
		*) usage_error "Unknown option: $1" ;;
	esac
	shift
done

case "$app" in
	example-app)
		profile=internal
		database=example_app
		database_user=example_app
		database_password=$(get_env_value EXAMPLE_APP_DB_PASSWORD)
		services='app app-nginx app-queue'
		;;
	*) usage_error "Unsupported app '$app'. Valid targets: example-app" ;;
esac
[ -n "$database_password" ] || die "EXAMPLE_APP_DB_PASSWORD is not set; add it to .env"

case "$dump_path" in
	/*) ;;
	*) usage_error "Dump path must be absolute" ;;
esac
[ -f "$dump_path" ] || die "Dump file not found: $dump_path"
[ -r "$dump_path" ] || die "Dump file is not readable: $dump_path"

case "$dump_path" in
	*.sql) dump_format=sql ;;
	*.sql.gz)
		command_exists gzip || die "gzip is required to import .sql.gz dumps"
		gzip -t -- "$dump_path" || die "Gzip integrity check failed: $dump_path"
		dump_format=gzip
		;;
	*) usage_error "Dump must end in .sql or .sql.gz" ;;
esac

mariadb_id=$(compose "$profile" ps -q mariadb 2>/dev/null || true)
[ -n "$mariadb_id" ] || die "MariaDB is not running. Start the $profile profile before importing."
[ "$(docker inspect --format '{{.State.Health.Status}}' "$mariadb_id" 2>/dev/null || true)" = healthy ] || die "MariaDB is not healthy. Resolve it before importing."

if [ "$assume_yes" = false ]; then
	printf '\n'
	warn "This replaces local database '$database' with '$dump_path'. Existing $database data will be lost."
	warn "Only import a sanitized, single-schema dump approved for local use."
	printf "Type '$database' to continue: "
	IFS= read -r answer
	[ "$answer" = "$database" ] || { info "Aborted"; exit 0; }
fi

running_services=''
for service in $services; do
	service_id=$(compose "$profile" ps -q "$service" 2>/dev/null || true)
	if [ -n "$service_id" ]; then
		running_services="${running_services}${running_services:+ }$service"
	fi
done

services_stopped=false
restore_services() {
	status=$?
	trap - 0
	if [ "$services_stopped" = true ]; then
		info "Restoring $app services..."
		if compose "$profile" up -d --wait --wait-timeout 120 $running_services; then
			ok "$app services restored"
		else
			warn "$app services did not become ready. Run ./scripts/up.sh $profile after resolving the import result."
		fi
	fi
	exit "$status"
}
trap restore_services 0
trap 'exit 130' HUP INT TERM

step "Importing $app database from $dump_format dump"
if [ -n "$running_services" ]; then
	info "Stopping running $app services..."
	services_stopped=true
	compose "$profile" stop $running_services || die "Could not stop $app services"
else
	info "No $app services are running; leaving them stopped."
fi

reset_sql="DROP DATABASE IF EXISTS $database; CREATE DATABASE $database CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
info "Recreating local database '$database'..."
compose "$profile" exec -T mariadb sh -c 'mysql --protocol=socket -uroot -p"$MARIADB_ROOT_PASSWORD" -e "$1"' sh "$reset_sql" || die "Could not recreate $database"

info "Streaming dump into '$database'..."
if [ "$dump_format" = sql ]; then
	compose "$profile" exec -T mariadb mysql --protocol=tcp -h 127.0.0.1 -u "$database_user" "-p$database_password" "$database" < "$dump_path" || die "Import failed; $database may be partially restored"
else
	gzip -dc -- "$dump_path" | compose "$profile" exec -T mariadb mysql --protocol=tcp -h 127.0.0.1 -u "$database_user" "-p$database_password" "$database" || die "Import failed; $database may be partially restored"
fi
ok "$app database imported"
