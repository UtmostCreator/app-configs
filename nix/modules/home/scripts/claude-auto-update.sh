# Update the natively installed Claude Code, then restart supervised sessions
# so they run the new build. Run hourly by claude-auto-update.timer
# (nix/modules/home/ai-cli-updates.nix); tested by
# tests/bash/ai-cli-auto-update.bats.
#
# Claude Code is installed by its own installer, not Nix (see
# repo-docs/software-and-cli-tools.md), so `claude update` is the updater.
# The last version applied to sessions is recorded, so sessions are restarted
# once per new build, including builds installed by Claude Code's own
# background updater. A failed update or restart leaves the record alone and
# the next run retries.
set -euo pipefail

claude_bin="${CLAUDE_BIN:-$HOME/.local/bin/claude}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-auto-update"
applied_file="$state_dir/applied-version"
mkdir -p "$state_dir"

version() { "$claude_bin" --version | awk '{print $1}'; }

echo "Checking for Claude Code updates (installed: $(version))"
"$claude_bin" update
current="$(version)"

applied=""
[[ -r "$applied_file" ]] && read -r applied <"$applied_file" || true
if [[ "$current" == "$applied" ]]; then
  echo "Claude Code $current is already active in supervised sessions"
  exit 0
fi

echo "Applying Claude Code $current to supervised sessions (previously: ${applied:-none})"
# try-restart only touches running units; both kinds keep conversation state
# across a process restart. The glob covers every project instance.
systemctl --user try-restart claude-background-sessions.service 'claude-remote-control@*.service'

printf '%s\n' "$current" >"$applied_file.tmp"
mv "$applied_file.tmp" "$applied_file"
echo "Claude Code $current is now active in supervised sessions"
