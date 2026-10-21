#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"

profile=${1:-internal}
assert_profile "$profile"

print_settings() {
	service=$1
	label=$2
	service_id=$(compose "$profile" ps -q "$service" 2>/dev/null || true)
	if [ -z "$service_id" ]; then
		warn "$label is not running"
		return
	fi

	step "PHP settings - $label"
	compose "$profile" exec -T "$service" php -r '
$values = [
    "sapi" => PHP_SAPI,
    "version" => PHP_VERSION,
    "memory_limit" => ini_get("memory_limit"),
    "max_execution_time" => ini_get("max_execution_time"),
    "post_max_size" => ini_get("post_max_size"),
    "upload_max_filesize" => ini_get("upload_max_filesize"),
    "loaded_ini" => php_ini_loaded_file(),
    "scanned_ini_files" => php_ini_scanned_files(),
];
foreach ($values as $key => $value) {
    printf("%s=%s\n", $key, $value ?: "(none)");
}
'
}

case "$profile" in
	internal)
		print_settings app "Example App"
		print_settings app-queue "Example App queue"
		;;
	test)
		warn "Test PHP services are one-off containers; inspect them through scripts/test.sh"
		;;
esac
