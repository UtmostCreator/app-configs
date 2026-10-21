#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

usage() {
	printf 'Usage: tests/run.sh [area]\n' >&2
	exit 2
}

run_area() {
	area=$1
	area_dir="$SCRIPT_DIR/$area"
	[ -d "$area_dir" ] || {
		printf 'Unknown test area: %s\n' "$area" >&2
		return 1
	}

	found=false
	for test_file in "$area_dir"/*.test.sh; do
		[ -f "$test_file" ] || continue
		found=true
		printf '==> %s\n' "${test_file#"$SCRIPT_DIR/"}"
		if sh "$test_file"; then
			printf '  [PASS] %s\n' "${test_file#"$SCRIPT_DIR/"}"
		else
			printf '  [FAIL] %s\n' "${test_file#"$SCRIPT_DIR/"}" >&2
			failures=$((failures + 1))
		fi
	done
	[ "$found" = true ] || {
		printf 'No test files found for area: %s\n' "$area" >&2
		return 1
	}
}

case "${1:-}" in
	-h|--help) usage ;;
	'') areas=$(find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;) ;;
	*) areas=$1 ;;
esac

failures=0
for area in $areas; do
	run_area "$area" || failures=$((failures + 1))
done

[ "$failures" -eq 0 ] || exit 1
printf 'All fixture areas passed.\n'