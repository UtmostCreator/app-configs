#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/compose.sh"

profile=${1:-}
[ -n "$profile" ] || usage_error "Usage: restart.sh <internal>"
assert_profile "$profile"

"$SCRIPT_DIR/down.sh"
"$SCRIPT_DIR/up.sh" "$profile" --all
