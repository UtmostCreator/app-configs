#!/usr/bin/env sh
set -eu

STACK_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
SCRIPT_DIR="$STACK_ROOT/scripts"
. "$STACK_ROOT/scripts/lib/env.sh"

fixture=$(mktemp "${TMPDIR:-/tmp}/env-parser.XXXXXX")
trap 'rm -f "$fixture"' EXIT HUP INT TERM

cat > "$fixture" <<'EOF'
SAMPLE_QUOTED="x y"
PLAIN_VALUE=local
EOF

[ "$(read_env_file_value SAMPLE_QUOTED "$fixture")" = "x y" ]
[ "$(read_env_file_value PLAIN_VALUE "$fixture")" = local ]
validate_stack_env_file "$fixture"

for invalid_line in \
	'export FOO=1' \
	'FOO=$HOME' \
	'FOO="unmatched' \
	'FOO=value # comment'
do
	printf '%s\n' "$invalid_line" > "$fixture"
	if validate_stack_env_file "$fixture" >/dev/null 2>&1; then
		printf 'invalid env line unexpectedly accepted: %s\n' "$invalid_line" >&2
		exit 1
	fi
done

printf 'env parser fixtures passed.\n'
