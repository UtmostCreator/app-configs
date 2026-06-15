#!/usr/bin/env bash
# Stop Syncthing conflict spam in the Obsidian sync folder, once and for all.
#
# WHAT IT DOES
# 1. Installs the repo-tracked .stignore (reference/syncthing/obsidian.stignore)
#    into the Syncthing Obsidian folder root, so Syncthing stops trying to sync
#    Obsidian's per-device state (workspace.json, cursor-positions.json, etc.),
#    which is what generates `*.sync-conflict-*` files endlessly.
# 2. Sweeps any existing `*.sync-conflict-*` files in that folder.
#
# WHY a script and not Nix: this repo deliberately keeps Syncthing FOLDER config
# user-owned in the Web UI (see nix/modules/home/gui.nix, services.syncthing),
# so folder paths are not declared in Nix. This helper is the shippable,
# re-runnable bridge: run it on every device after Syncthing is set up.
#
# SAFETY
# - Dry-run by default. It changes nothing until you pass --apply.
# - The .stignore install is idempotent: re-running just refreshes the file.
# - Conflict-file deletion only ever targets paths matching `*.sync-conflict-*`.
#
# USAGE
#   bash ops/syncthing-obsidian-stignore.sh                 # dry-run, default folder
#   bash ops/syncthing-obsidian-stignore.sh --apply         # install + sweep
#   bash ops/syncthing-obsidian-stignore.sh --folder DIR    # custom folder root
#   SYNC_OBSIDIAN_DIR=DIR bash ops/syncthing-obsidian-stignore.sh --apply
#
# Default folder root: $HOME/Documents/___sync/obsidian (override as above).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT_DIR/reference/syncthing/obsidian.stignore"

FOLDER="${SYNC_OBSIDIAN_DIR:-$HOME/Documents/___sync/obsidian}"
APPLY=0

log()  { printf '[stignore] %s\n' "$*"; }
warn() { printf '[stignore][WARN] %s\n' "$*" >&2; }
fail() { printf '[stignore][ERROR] %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)  APPLY=1; shift ;;
    --folder) FOLDER="${2:?--folder needs a path}"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -f "$TEMPLATE" ]] || fail "template missing: $TEMPLATE"

if [[ ! -d "$FOLDER" ]]; then
  warn "Syncthing Obsidian folder not found: $FOLDER"
  warn "Pass --folder DIR or set SYNC_OBSIDIAN_DIR to the correct path."
  exit 0
fi

if [[ ! -e "$FOLDER/.stfolder" ]]; then
  warn "no .stfolder marker in $FOLDER; this may not be a Syncthing folder root."
  warn "Proceeding anyway (the .stignore is harmless if Syncthing ignores it)."
fi

DEST="$FOLDER/.stignore"

# --- 1) Decide whether the .stignore needs (re)installing -------------------
stignore_action="up-to-date"
if [[ ! -f "$DEST" ]]; then
  stignore_action="install"
elif ! cmp -s "$TEMPLATE" "$DEST"; then
  stignore_action="update"
fi

# --- 2) Collect existing conflict files ------------------------------------
conflicts=()
while IFS= read -r -d '' f; do
  conflicts+=("$f")
done < <(find "$FOLDER" -type f -name '*.sync-conflict-*' -print0 2>/dev/null)

log "Folder:        $FOLDER"
log ".stignore:     $stignore_action"
log "Conflict files: ${#conflicts[@]} found"

if [[ "$APPLY" -eq 0 ]]; then
  log "DRY-RUN (no changes). Re-run with --apply to install and sweep."
  if [[ ${#conflicts[@]} -gt 0 ]]; then
    log "Would remove:"
    printf '  %s\n' "${conflicts[@]}"
  fi
  exit 0
fi

# --- APPLY ------------------------------------------------------------------
if [[ "$stignore_action" != "up-to-date" ]]; then
  cp "$TEMPLATE" "$DEST"
  log ".stignore ${stignore_action}d: $DEST"
else
  log ".stignore already current: $DEST"
fi

removed=0
for f in "${conflicts[@]}"; do
  # Belt-and-braces: only ever delete genuine conflict files.
  case "$f" in
    *.sync-conflict-*)
      rm -f -- "$f" && removed=$((removed + 1)) ;;
    *)
      warn "skipped non-conflict path: $f" ;;
  esac
done
log "Removed $removed conflict file(s)."
log "Done. Restart/rescan in the Syncthing Web UI (http://127.0.0.1:8384) if it"
log "does not pick up the new .stignore automatically."
