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
# - Fails closed: if `chezmoi managed` fails, nothing is claimed as backed up.
#   An empty managed list is a legitimate success.
# - Dangling symlinks are captured as symlinks.
# - Each run gets its own directory; a same-second run never reuses one.
#
# Usage:
#   bash ops/snapshot-home.sh              # human log on stdout
#   bash ops/snapshot-home.sh --print-dir  # logs to stderr; stdout is ONLY
#                                          # the absolute snapshot directory
#
# Override the destination root with DOTFILES_SNAPSHOT_ROOT.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PRINT_DIR=0
if [[ $# -gt 1 ]]; then
  printf '[snapshot-home][ERROR] too many arguments\n' >&2; exit 2
fi
case "${1:-}" in
  "") ;;
  --print-dir) PRINT_DIR=1 ;;
  -h | --help)
    printf 'Usage: bash ops/snapshot-home.sh [--print-dir | -h | --help]\n'
    printf 'Copies the files chezmoi is about to overwrite into ~/.local/state/dotfiles-snapshots (override: DOTFILES_SNAPSHOT_ROOT).\n'
    exit 0
    ;;
  *) printf '[snapshot-home][ERROR] unknown argument: %s\n' "$1" >&2; exit 2 ;;
esac

if [[ "$PRINT_DIR" == 1 ]]; then
  log() { printf '[snapshot-home] %s\n' "$*" >&2; }
else
  log() { printf '[snapshot-home] %s\n' "$*"; }
fi
fail() { printf '[snapshot-home][ERROR] %s\n' "$*" >&2; exit 1; }

if ! command -v chezmoi >/dev/null 2>&1; then
  fail "chezmoi not on PATH; cannot enumerate managed files"
fi

DEFAULT_ROOT="$HOME/.local/state/dotfiles-snapshots"
SNAPSHOT_ROOT="${DOTFILES_SNAPSHOT_ROOT:-$DEFAULT_ROOT}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

# Collision-safe: mkdir (no -p) on the leaf is atomic, so a same-second run
# takes the next -N suffix instead of overwriting an earlier snapshot.
mkdir -p "$SNAPSHOT_ROOT"
# Normalise to an absolute path so --print-dir is usable from any cwd.
SNAPSHOT_ROOT="$(cd "$SNAPSHOT_ROOT" && pwd -P)"
SNAPSHOT_DIR="$SNAPSHOT_ROOT/$STAMP"
n=1
until mkdir "$SNAPSHOT_DIR" 2>/dev/null; do
  [[ -d "$SNAPSHOT_DIR" ]] || fail "cannot create snapshot dir: $SNAPSHOT_DIR"
  n=$((n + 1))
  SNAPSHOT_DIR="$SNAPSHOT_ROOT/$STAMP-$n"
done
MANIFEST="$SNAPSHOT_DIR/MANIFEST.txt"
log "Snapshot dir: $SNAPSHOT_DIR"

# Enumerate first and check the exit status: a failed enumeration must not
# look like an empty one. chezmoi managed emits paths relative to $HOME.
MANAGED_LIST="$(chezmoi managed --include files,symlinks)" \
  || fail "chezmoi managed failed; cannot enumerate managed files"

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
  if [[ ! -e "$src" && ! -L "$src" ]]; then
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
done <<< "$MANAGED_LIST"

{
  printf '\n## Counts\n'
  printf 'managed targets: %s\n' "$managed_count"
  printf 'copied: %s\n' "$copied_count"
  printf 'missing on host (nothing to back up): %s\n' "$missing_count"
} >> "$MANIFEST"

log "Snapshot complete: $copied_count copied, $missing_count not present yet."
log "Manifest: $MANIFEST"
log "Restore with: cp -a $SNAPSHOT_DIR/. ~/"

if [[ "$PRINT_DIR" == 1 ]]; then
  printf '%s\n' "$SNAPSHOT_DIR"
fi
