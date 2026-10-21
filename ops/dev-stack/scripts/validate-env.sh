#!/usr/bin/env sh
# Refuses application .env settings that could reach production data or external services.
set -eu

usage() {
	printf 'Usage: validate-env.sh <example-app> <env-file>\n' >&2
	exit 2
}

[ "$#" -eq 2 ] || usage
app=$1
env_file=$2
case "$app" in
	example-app) ;;
	*) usage ;;
esac

if [ ! -f "$env_file" ]; then
	printf '  [FAIL] %s: %s does not exist - run setup.sh to create it from the stack template\n' "$app" "$env_file" >&2
	exit 1
fi

awk -v app="$app" '
function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function err(message) { printf "  [FAIL] %s: %s\n", app, message > "/dev/stderr"; errors++ }
function add_words(list, set,   parts, n, j) {
	n = split(list, parts, /[ ,]+/)
	for (j = 1; j <= n; j++) if (parts[j] != "") set[tolower(parts[j])] = 1
}

# Constrained dotenv grammar: one literal value per key, optionally quoted, no interpolation.
function parse_value(raw,   quote, position, rest, character, j) {
	parsed_status = "ok"
	parsed_value = ""
	quote = substr(raw, 1, 1)
	if (quote == "\"" || quote == "\047") {
		position = 0
		for (j = 2; j <= length(raw); j++) {
			character = substr(raw, j, 1)
			if (character == "\\" && quote == "\"") { j++; continue }
			if (character == quote) { position = j; break }
		}
		if (position == 0) { parsed_status = "unparseable"; return }
		rest = trim(substr(raw, position + 1))
		if (rest != "" && substr(rest, 1, 1) != "#") { parsed_status = "unparseable"; return }
		parsed_value = substr(raw, 2, position - 2)
		if (quote == "\"" && index(parsed_value, "$") > 0) parsed_status = "interpolated"
		return
	}
	sub(/[[:space:]]+#.*$/, "", raw)
	if (raw ~ /[[:space:]"\047]/) { parsed_status = "unparseable"; return }
	parsed_value = raw
	if (index(raw, "$") > 0) parsed_status = "interpolated"
}

function usable(key) {
	if (!(key in status)) return 0
	if (!(key in reported)) {
		reported[key] = 1
		if (key in duplicate) err(key " is defined more than once; keep a single definition")
		else if (status[key] == "interpolated") err(key " uses $ interpolation; use a literal value")
		else if (status[key] == "unparseable") err(key " cannot be parsed; quote the value or remove spaces and stray quotes")
	}
	return status[key] == "ok" && !(key in duplicate)
}

function require_one_of(key, choices, example,   parts, n, j, current) {
	if (!(key in status)) { err(key " is missing; set " key "=" example); return }
	if (!usable(key)) return
	current = tolower(value[key])
	n = split(choices, parts, " ")
	for (j = 1; j <= n; j++) if (current == parts[j]) return
	err(key " must be one of: " choices)
}
function optional_one_of(key, choices) { if (key in status) require_one_of(key, choices, "") }
function must_be_empty(key, reason) { if (usable(key) && value[key] != "") err(key " must be empty: " reason) }
function each_empty(keys, reason,   parts, n, j) { n = split(keys, parts, " "); for (j = 1; j <= n; j++) must_be_empty(parts[j], reason) }

function host_of(url,   host, cut, at) {
	host = tolower(url)
	sub(/^[a-z][a-z0-9+.-]*:\/\//, "", host)
	cut = match(host, /[\/?#]/)
	if (cut > 0) host = substr(host, 1, cut - 1)
	at = index(host, "@")
	while (at > 0) { host = substr(host, at + 1); at = index(host, "@") }
	sub(/:[0-9]*$/, "", host)
	return host
}
function local_host(key, required,   host) {
	if (!(key in status)) { if (required) err(key " is missing; point it at a local stack service"); return }
	if (!usable(key)) return
	if (value[key] == "") { if (required) err(key " is empty; point it at a local stack service"); return }
	host = host_of(value[key])
	if (host == "" || host !~ /^[a-z0-9.-]+$/) { err(key " does not contain a recognisable hostname"); return }
	if ((host in internal)) return
	err(key " points to " host ", which is not a local stack service")
}
function each_local_host(keys, required,   parts, n, j) { n = split(keys, parts, " "); for (j = 1; j <= n; j++) local_host(parts[j], required) }

BEGIN {
	add_words("mariadb redis app app-nginx localhost 127.0.0.1", internal)
}

/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
{
	line = $0
	sub(/\r$/, "", line)
	sub(/^[[:space:]]*export[[:space:]]+/, "", line)
	separator = index(line, "=")
	if (separator == 0) next
	key = trim(substr(line, 1, separator - 1))
	raw = trim(substr(line, separator + 1))
	if (raw ~ /_live_/) err(key " contains a live-mode credential; only test-mode credentials are allowed")
	parse_value(raw)
	if (key in status) { duplicate[key] = 1; next }
	status[key] = parsed_status
	value[key] = parsed_value
}

END {
	require_one_of("APP_ENV", "local", "local")
	require_one_of("DB_HOST", "mariadb", "mariadb")
	optional_one_of("REDIS_HOST", "redis")
	local_host("REDIS_URL", 0)
	optional_one_of("MAIL_MAILER", "log array")
	optional_one_of("MAIL_DRIVER", "log array")
	each_local_host("APP_URL ASSET_URL DB_URL DATABASE_URL", 0)
	each_empty("AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_BUCKET AWS_ENDPOINT AWS_URL", "no object storage service is provided; use the local filesystem disk")
	# Third-party integrations are disabled locally: credential-looking keys must be empty or local- placeholders.
	for (key in status) {
		if (key ~ /(_DSN|_API_KEY|_SECRET|_TOKEN|_WEBHOOK_URL)$/ && usable(key) && value[key] != "" && value[key] !~ /^local-/) {
			err(key " must be empty or a local- placeholder: external integrations are disabled in local development")
		}
	}

	exit (errors > 0)
}
' "$env_file"
