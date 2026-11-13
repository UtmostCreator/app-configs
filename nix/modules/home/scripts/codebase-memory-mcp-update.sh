# Entry point for the codebase-memory-mcp-update user unit (dev.nix).
# Finds the repo through chezmoi's source dir, like the sys-* helpers, so it
# works for any clone location (README: ~/app-configs).
set -euo pipefail
src="$(chezmoi source-path)"
exec bash "$src/../ops/update-codebase-memory-mcp.sh" --apply
