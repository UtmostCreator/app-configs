#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"
. "$SCRIPT_DIR/lib/env.sh"

usage() {
	printf 'Usage: export-db.sh <example-app> <absolute-output.sql|absolute-output.sql.gz> [--force]\n'
}

[ "$#" -ge 2 ] || { usage; exit 2; }
app=$1
output_path=$2
shift 2
force=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--force) force=true ;;
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
		;;
	*) usage_error "Unsupported app '$app'. Valid targets: example-app" ;;
esac
[ -n "$database_password" ] || die "EXAMPLE_APP_DB_PASSWORD is not set; add it to .env"

case "$output_path" in
	/*) ;;
	*) usage_error "Output path must be absolute" ;;
esac

case "$output_path" in
	*.sql) output_format=sql ;;
	*.sql.gz)
		command_exists gzip || die "gzip is required to create .sql.gz exports"
		output_format=gzip
		;;
	*) usage_error "Output must end in .sql or .sql.gz" ;;
esac

output_dir=$(dirname -- "$output_path")
output_name=$(basename -- "$output_path")
[ -d "$output_dir" ] || die "Output directory does not exist: $output_dir"
[ -w "$output_dir" ] || die "Output directory is not writable: $output_dir"

if [ -L "$output_path" ]; then
	die "Output path must not be a symbolic link: $output_path"
fi
if [ -e "$output_path" ] && [ "$force" = false ]; then
	die "Output file already exists: $output_path. Use --force to replace it."
fi
if [ -e "$output_path" ] && [ ! -f "$output_path" ]; then
	die "Output path must be a regular file when it exists: $output_path"
fi

mariadb_id=$(compose "$profile" ps -q mariadb 2>/dev/null || true)
[ -n "$mariadb_id" ] || die "MariaDB is not running. Start the $profile profile before exporting."
[ "$(docker inspect --format '{{.State.Health.Status}}' "$mariadb_id" 2>/dev/null || true)" = healthy ] || die "MariaDB is not healthy. Resolve it before exporting."

if compose "$profile" exec -T mariadb sh -c 'command -v mariadb-dump >/dev/null 2>&1'; then
	dump_client=mariadb-dump
elif compose "$profile" exec -T mariadb sh -c 'command -v mysqldump >/dev/null 2>&1'; then
	dump_client=mysqldump
else
	die "Neither mariadb-dump nor mysqldump is available in the MariaDB container"
fi

umask 077
temporary_sql="$output_dir/.${output_name}.sql.partial.$$"
temporary_output="$output_dir/.${output_name}.partial.$$"
cleanup() {
	status=$?
	trap - 0
	rm -f -- "$temporary_sql" "$temporary_output"
	exit "$status"
}
trap cleanup 0
trap 'exit 130' HUP INT TERM

step "Exporting $app database as $output_format"
warn "The export can contain sensitive data. Store and share it only through approved channels."
info "Writing a consistent InnoDB snapshot of '$database'..."
compose "$profile" exec -T mariadb "$dump_client" \
	--protocol=tcp -h 127.0.0.1 -u "$database_user" "-p$database_password" \
	--single-transaction --quick --routines --events --triggers --no-tablespaces --skip-comments \
	"$database" > "$temporary_sql" || die "Database export failed; no output file was created"

if [ "$output_format" = gzip ]; then
	info "Compressing export..."
	gzip -c -- "$temporary_sql" > "$temporary_output" || die "Compression failed; no output file was created"
	rm -f -- "$temporary_sql"
else
	mv -- "$temporary_sql" "$temporary_output"
fi

mv -f -- "$temporary_output" "$output_path"
ok "$app database exported to $output_path"
