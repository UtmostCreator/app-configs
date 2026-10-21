#!/usr/bin/env sh
# Writes a private npm registry credential file outside the repository and verifies it.
# The token comes from DEVSTACK_NPM_TOKEN or an interactive prompt; it is never stored in the repo.
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/env.sh"

if [ "${1:-}" = "--help" ]; then
	printf 'Usage: setup-npm-auth.sh\n'
	printf 'Creates %s for DEVSTACK_NPM_REGISTRY (scope @example-org).\n' "$(npm_credentials_file)"
	printf 'Set DEVSTACK_NPM_TOKEN to avoid the prompt.\n'
	exit 0
fi
[ "$#" -eq 0 ] || usage_error "Usage: setup-npm-auth.sh"
command_exists docker || die "Docker is required to verify the registry credentials"

registry=$(get_env_value DEVSTACK_NPM_REGISTRY)
[ -n "$registry" ] || die "DEVSTACK_NPM_REGISTRY is not set; add it to .env"
credentials_file=$(npm_credentials_file)

token=${DEVSTACK_NPM_TOKEN:-}
if [ -z "$token" ]; then
	[ -t 0 ] || die "DEVSTACK_NPM_TOKEN is unset and no interactive terminal is available"
	printf 'Registry token (read access): '
	stty -echo
	IFS= read -r token
	stty echo
	printf '\n'
fi
[ -n "$token" ] || die "Registry token cannot be empty"

umask 077
mkdir -p "$(dirname -- "$credentials_file")"
temporary_file="$credentials_file.tmp.$$"
trap 'rm -f "$temporary_file"' 0 HUP INT TERM
registry_host=${registry#*://}
printf '%s\n%s\n' \
	"@example-org:registry=$registry" \
	"//${registry_host%/}/:_authToken=$token" > "$temporary_file"
unset token

# Plain docker run: compose would create missing ../example-app mount points before clone.sh runs.
if docker run --rm --init \
	--user "$(id -u):$(id -g)" \
	--cap-drop ALL --security-opt no-new-privileges:true \
	-e HOME=/tmp -e npm_config_cache=/tmp/.npm \
	-e NPM_CONFIG_USERCONFIG=/run/secrets/npmrc \
	-v "$temporary_file:/run/secrets/npmrc:ro" \
	node:22.22.2-bookworm-slim@sha256:9f6d5975c7dca860947d3915877f85607946403fc55349f39b4bc3688448bb6e \
	npm view @example-org/example-ui version --registry="$registry" >/dev/null; then
	mv "$temporary_file" "$credentials_file"
	trap - 0 HUP INT TERM
	ok "Registry authentication verified"
	info "Credential file: $credentials_file"
else
	die "Registry authentication failed. Check the token, its read scope and package access."
fi
