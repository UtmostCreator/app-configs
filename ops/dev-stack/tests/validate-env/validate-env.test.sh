#!/usr/bin/env sh
set -eu

TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
STACK_ROOT="$(CDPATH='' cd -- "$TEST_DIR/../.." && pwd)"
VALIDATOR=${VALIDATE_ENV_SCRIPT:-"$STACK_ROOT/scripts/validate-env.sh"}
fixture_dir=$(mktemp -d "${TMPDIR:-/tmp}/validate-env.XXXXXX")
trap 'rm -rf "$fixture_dir"' EXIT HUP INT TERM

checks=0

fixture_for() {
	app=$1
	fixture="$fixture_dir/$app.env"
	cp "$STACK_ROOT/templates/env/$app.env" "$fixture"
	printf '%s\n' "$fixture"
}

set_value() {
	key=$1
	value=$2
	fixture=$3
	temporary="$fixture.tmp"
	awk -v key="$key" -v value="$value" '
		index($0, key "=") == 1 { print key "=" value; found = 1; next }
		{ print }
		END { if (!found) print key "=" value }
	' "$fixture" > "$temporary"
	mv "$temporary" "$fixture"
}

expect_pass() {
	name=$1
	app=$2
	fixture=$3
	checks=$((checks + 1))
	if sh "$VALIDATOR" "$app" "$fixture" >/dev/null 2>&1; then
		printf '  [PASS] %s\n' "$name"
	else
		printf '  [FAIL] %s unexpectedly failed\n' "$name" >&2
		exit 1
	fi
}

expect_fail() {
	name=$1
	app=$2
	fixture=$3
	checks=$((checks + 1))
	if sh "$VALIDATOR" "$app" "$fixture" >/dev/null 2>&1; then
		printf '  [FAIL] %s unexpectedly passed\n' "$name" >&2
		exit 1
	fi
	printf '  [PASS] %s\n' "$name"
}

expect_key_rejected() {
	name=$1
	app=$2
	key=$3
	value=$4
	fixture=$(fixture_for "$app")
	set_value "$key" "$value" "$fixture"
	expect_fail "$name" "$app" "$fixture"
}

fixture=$(fixture_for example-app)
expect_pass 'example-app shipped template' example-app "$fixture"

checks=$((checks + 1))
if sh "$VALIDATOR" invalid-app "$(fixture_for example-app)" >/dev/null 2>&1; then
	printf '  [FAIL] invalid app unexpectedly passed\n' >&2
	exit 1
fi
printf '  [PASS] invalid app\n'
checks=$((checks + 1))
if sh "$VALIDATOR" example-app "$fixture_dir/missing.env" >/dev/null 2>&1; then
	printf '  [FAIL] missing env file unexpectedly passed\n' >&2
	exit 1
fi
printf '  [PASS] missing env file\n'

expect_key_rejected 'nonlocal database host' example-app DB_HOST db.example.test
expect_key_rejected 'production APP_ENV' example-app APP_ENV production
expect_key_rejected 'nonlocal Redis host' example-app REDIS_HOST redis.example.test
expect_key_rejected 'nonlocal Redis URL' example-app REDIS_URL redis://redis.example.test:6379
expect_key_rejected 'nonlocal database URL' example-app DB_URL mysql://user:pass@db.example.test/example_app
expect_key_rejected 'SMTP mailer' example-app MAIL_MAILER smtp
expect_key_rejected 'live-mode credential' example-app PAYMENT_KEY sk_live_fixture
expect_key_rejected 'external storage endpoint' example-app AWS_ENDPOINT http://storage.example.test
expect_key_rejected 'S3 bucket without storage service' example-app AWS_BUCKET some-bucket
for key in SERVICE_DSN SERVICE_API_KEY SERVICE_SECRET SERVICE_TOKEN SERVICE_WEBHOOK_URL; do
	expect_key_rejected "external credential $key" example-app "$key" live-value
done

fixture=$(fixture_for example-app)
set_value APP_URL "https://\${APP_HOST}" "$fixture"
expect_fail 'interpolated value' example-app "$fixture"
fixture=$(fixture_for example-app)
set_value DB_HOST '"mariadb' "$fixture"
expect_fail 'unparseable quote' example-app "$fixture"
fixture=$(fixture_for example-app)
printf 'DB_HOST=mariadb\n' >> "$fixture"
expect_fail 'duplicate safety key' example-app "$fixture"
printf 'validate-env fixtures passed (%s checks).\n' "$checks"
