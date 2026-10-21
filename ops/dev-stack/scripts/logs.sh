#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: logs.sh <internal> [service]"
assert_profile "$profile"
service=${2:-}

if [ -n "$service" ]; then
	compose "$profile" logs -f --tail=100 "$service"
else
	compose "$profile" logs -f --tail=50
fi
