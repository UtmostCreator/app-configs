#!/usr/bin/env bash
# Snapshot files chezmoi is about to manage, before any apply.
#
# Behavior:
# - Asks chezmoi for the list of managed targets (chezmoi managed).
# - Copies every existing destination file into a timestamped folder
#   under $HOME/.local/state/dotfiles-snapshots/<UTC timestamp>/.
# - Writes a manifest at <snapshot>/MANIFEST.txt listing every copied file
#   and the snapshot location.
# - Exits non-zero if chezmoi is missing or if any copy fails. Callers
#   (ops/bootstrap.sh, mise run sync:apply) must treat that as fatal.
#
# Usage:
#   bash ops/snapshot-home.sh
#
# Override the destination root with DOTFILES_SNAPSHOT_ROOT.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log()  { printf '[snapshot-home] %s\n' "$*"; }
fail() { printf '[snapshot-home][ERROR] %s\n' "$*" >&2; exit 1; }

if ! command -v chezmoi >/dev/null 2>&1; then
  fail "chezmoi not on PATH; cannot enumerate managed files"
fi

DEFAULT_ROOT="$HOME/.local/state/dotfiles-snapshots"
SNAPSHOT_ROOT="${DOTFILES_SNAPSHOT_ROOT:-$DEFAULT_ROOT}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SNAPSHOT_DIR="$SNAPSHOT_ROOT/$STAMP"
MANIFEST="$SNAPSHOT_DIR/MANIFEST.txt"

mkdir -p "$SNAPSHOT_DIR"
log "Snapshot dir: $SNAPSHOT_DIR"

# Collect managed paths. chezmoi managed emits paths relative to $HOME.
managed_count=0
copied_count=0
missing_count=0

{
  printf 'dotfiles snapshot\n'
  printf 'created (UTC): %s\n' "$STAMP"
  printf 'repo: %s\n' "$ROOT_DIR"
  printf 'snapshot dir: %s\n' "$SNAPSHOT_DIR"
  printf '\n## Copied files\n'
} > "$MANIFEST"

while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  managed_count=$((managed_count + 1))
  src="$HOME/$rel"
  if [[ ! -e "$src" ]]; then
    missing_count=$((missing_count + 1))
    printf -- '- missing (no current file): %s\n' "$rel" >> "$MANIFEST"
    continue
  fi
  dst="$SNAPSHOT_DIR/$rel"
  mkdir -p "$(dirname "$dst")"
  if cp -a "$src" "$dst"; then
    copied_count=$((copied_count + 1))
    printf -- '- %s\n' "$rel" >> "$MANIFEST"
  else
    fail "copy failed: $src"
  fi
done < <(chezmoi managed --include files,symlinks 2>/dev/null || true)

{
  printf '\n## Counts\n'
  printf 'managed targets: %s\n' "$managed_count"
  printf 'copied: %s\n' "$copied_count"
  printf 'missing on host (nothing to back up): %s\n' "$missing_count"
} >> "$MANIFEST"

log "Snapshot complete: $copied_count copied, $missing_count not present yet."
log "Manifest: $MANIFEST"
log "Restore with: cp -a $SNAPSHOT_DIR/. ~/"
