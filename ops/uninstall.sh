#!/usr/bin/env bash
# Non-destructive uninstall / handoff helper for the dotfiles setup.
#
# Default behavior is "report only" — prints what each tool would do and
# leaves the host untouched. Pass --apply to actually run the listed
# commands. Pass --yes to skip the confirmation prompt.
#
# What this DOES NOT do (intentional):
#   - delete files in $HOME beyond what each tool's own uninstall handles
#   - remove Nix itself (use the official Nix uninstaller for that)
#   - delete snapshots created by ops/snapshot-home.sh
#   - touch system packages / casks managed by nix-darwin
#
# Usage:
#   bash ops/uninstall.sh             # report only (default)
#   bash ops/uninstall.sh --apply     # actually run, with prompt
#   bash ops/uninstall.sh --apply --yes  # non-interactive apply

set -uo pipefail

MODE="report"
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --apply) MODE="apply" ;;
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      printf '[uninstall] unknown arg: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ops/lib/preflight.sh
source "$REPO_ROOT/ops/lib/preflight.sh"
# Test guard: an apply run under bats must stay inside the test's scratch dir.
[[ "$MODE" == "apply" ]] && preflight_bats_guard uninstall "to apply" "$REPO_ROOT"

log()  { printf '[uninstall:%s] %s\n' "$MODE" "$*"; }
note() { printf '   %s\n' "$*"; }

SNAPSHOT_ROOT="${DOTFILES_SNAPSHOT_ROOT:-$HOME/.local/state/dotfiles-snapshots}"

echo
echo "== dotfiles uninstall / handoff helper =="
echo "Mode: $MODE"
echo

# Snapshot inventory
if [[ -d "$SNAPSHOT_ROOT" ]]; then
  log "Existing snapshots ($SNAPSHOT_ROOT):"
  # A glob loop, not `find -printf`: BSD find (macOS) has no -printf.
  for snap in "$SNAPSHOT_ROOT"/*/; do
    [[ -d "$snap" ]] || continue
    snap="${snap%/}"
    printf '   %s\n' "${snap##*/}"
  done | LC_ALL=C sort
else
  log "No snapshots directory at $SNAPSHOT_ROOT — nothing to restore from."
fi
echo

# chezmoi forget — keeps rendered dotfiles in $HOME but stops tracking them.
if command -v chezmoi >/dev/null 2>&1; then
  log "chezmoi: would run 'chezmoi forget' (your rendered dotfiles stay in $HOME)."
  note "After 'chezmoi forget' you can manually delete any files you don't want."
else
  log "chezmoi not installed."
fi

# Home Manager rollback / uninstall.
if command -v home-manager >/dev/null 2>&1; then
  log "home-manager: would run 'home-manager uninstall' (removes managed packages)."
  note "List generations first with: home-manager generations"
elif command -v darwin-rebuild >/dev/null 2>&1; then
  log "nix-darwin: would offer 'darwin-rebuild --rollback' (no full uninstaller)."
else
  log "Neither home-manager nor darwin-rebuild on PATH; nothing to roll back."
fi

# Lefthook hooks.
if command -v lefthook >/dev/null 2>&1 && [[ -e "$REPO_ROOT/.git" ]]; then
  log "lefthook: would run 'lefthook uninstall' from $REPO_ROOT."
fi

# mise runtimes — keep on disk by default.
if command -v mise >/dev/null 2>&1; then
  log "mise: runtimes stay on disk; remove manually with 'mise uninstall <tool>@<version>' if desired."
fi

cat <<'NOTE'

Notes:
  - Nix itself is not removed. Use the official uninstaller:
    https://nix.dev/manual/nix/2.18/installation/uninstall
  - Snapshots are kept under $DOTFILES_SNAPSHOT_ROOT (default
    ~/.local/state/dotfiles-snapshots/). Delete manually if not needed.
  - Real personal.yaml is gitignored and stays where chezmoi found it.
NOTE

if [[ "$MODE" == "report" ]]; then
  echo
  log "Re-run with --apply to actually execute the commands above."
  exit 0
fi

if [[ "$ASSUME_YES" -ne 1 ]]; then
  if [[ ! -t 0 ]]; then
    echo "[uninstall:apply][error] non-interactive shell; pass --yes to confirm" >&2
    exit 1
  fi
  printf 'Proceed with uninstall? [y/N] '
  read -r ans
  [[ "$ans" = "y" || "$ans" = "Y" ]] || { echo "Aborted."; exit 1; }
fi

set -e
command -v chezmoi >/dev/null 2>&1 && chezmoi forget || true
command -v home-manager >/dev/null 2>&1 && home-manager uninstall || true
if command -v lefthook >/dev/null 2>&1 && [[ -e "$REPO_ROOT/.git" ]]; then
  ( cd "$REPO_ROOT" && lefthook uninstall ) || true
fi
echo
log "done. Nix and runtime data preserved."
