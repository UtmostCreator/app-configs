# Update the standalone Codex CLI. Run hourly by codex-auto-update.timer
# (nix/modules/home/ai-cli-updates.nix); tested by
# tests/bash/ai-cli-auto-update.bats.
#
# Codex is installed by its standalone installer under ~/.codex, not Nix, so
# `codex update` is the updater. Running Codex processes keep the build they
# loaded; new sessions pick up the update.
set -euo pipefail

codex_bin="${CODEX_BIN:-$HOME/.local/bin/codex}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/codex-auto-update"
installed_file="$state_dir/installed-version"
mkdir -p "$state_dir"

version() { "$codex_bin" --version | awk '{print $2}'; }

before="$(version)"
echo "Checking for Codex CLI updates (installed: $before)"
"$codex_bin" update
after="$(version)"

printf '%s\n' "$after" >"$installed_file.tmp"
mv "$installed_file.tmp" "$installed_file"

if [[ "$before" == "$after" ]]; then
  echo "Codex CLI $after is already current"
else
  echo "Updated Codex CLI from $before to $after"
  echo "Running Codex processes keep their loaded build; new sessions use $after"
fi
