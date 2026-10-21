#!/usr/bin/env sh
set -eu

STACK_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
seed_script="$STACK_ROOT/scripts/seed.sh"

grep -q 'minimal-standing-stack' "$seed_script"
grep -q 'Unknown seed scenario' "$seed_script"
grep -q 'Hash::make(getenv("SEED_ADMIN_PASSWORD"))' "$seed_script"
if grep -q 'password = "' "$seed_script"; then
	printf 'Admin password is still stored in plaintext\n' >&2
	exit 1
fi

if sh "$seed_script" internal --scenario other >/dev/null 2>&1; then
	printf 'unknown seed scenario unexpectedly accepted\n' >&2
	exit 1
fi

SCRIPT_DIR="$STACK_ROOT/scripts"
. "$STACK_ROOT/scripts/lib/common.sh"
. "$STACK_ROOT/scripts/lib/seed-policy.sh"
if sh -c 'SCRIPT_DIR=$1; . "$1/lib/common.sh"; . "$1/lib/seed-policy.sh"; run_required "fixture required failure" false' sh "$STACK_ROOT/scripts" >/dev/null 2>&1; then
	printf 'required seed failure unexpectedly succeeded\n' >&2
	exit 1
fi
optional_output=$(run_optional 'fixture optional failure' false 2>&1)
printf '%s\n' "$optional_output" | grep -q 'Optional seed/provisioning operation failed: fixture optional failure'

printf 'seed policy fixtures passed.\n'
