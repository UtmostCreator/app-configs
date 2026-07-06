#!/usr/bin/env bash
# Stop Syncthing from syncing Obsidian metadata folders, once and for all.
#
# WHAT IT DOES
# 1. Installs the repo-tracked managed ignore block
#    (reference/syncthing/obsidian.stignore) into every configured Syncthing
#    folder root, so Syncthing stops syncing any `.obsidian/` directory.
# 2. Sweeps any existing `*.sync-conflict-*`, `*sync-conflict-*`, or
#    `data-sync-conflict.*` files in that folder.
#
# WHY a script and not Nix: this repo deliberately keeps Syncthing FOLDER config
# user-owned in the Web UI (see nix/modules/home/gui.nix, services.syncthing),
# so folder paths are not declared in Nix. This helper is the shippable,
# re-runnable bridge: run it on every device after Syncthing is set up.
#
# SAFETY
# - Dry-run by default. It changes nothing until you pass --apply.
# - The .stignore install is idempotent and preserves non-managed rules.
# - Conflict-file deletion only ever targets known Syncthing conflict patterns.
#
# USAGE
#   bash ops/syncthing-obsidian-stignore.sh                 # dry-run, configured folders
#   bash ops/syncthing-obsidian-stignore.sh --apply         # install + sweep all folders
#   bash ops/syncthing-obsidian-stignore.sh --folder DIR    # custom folder root only
#   SYNC_OBSIDIAN_DIR=DIR bash ops/syncthing-obsidian-stignore.sh --apply
#
# Default: Syncthing config folders; fallback: $HOME/Documents/___sync/obsidian.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT_DIR/reference/syncthing/obsidian.stignore"

DEFAULT_FOLDER="${SYNC_OBSIDIAN_DIR:-$HOME/Documents/___sync/obsidian}"
APPLY=0
EXPLICIT_FOLDERS=()
BEGIN_MARKER="# BEGIN app-configs syncthing obsidian ignore"
END_MARKER="# END app-configs syncthing obsidian ignore"

log()  { printf '[stignore] %s\n' "$*"; }
warn() { printf '[stignore][WARN] %s\n' "$*" >&2; }
fail() { printf '[stignore][ERROR] %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)  APPLY=1; shift ;;
    --folder) EXPLICIT_FOLDERS+=("${2:?--folder needs a path}"); shift 2 ;;
    -h|--help)
      sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -f "$TEMPLATE" ]] || fail "template missing: $TEMPLATE"

syncthing_config_paths() {
  printf '%s\n' \
    "$HOME/.local/state/syncthing/config.xml" \
    "$HOME/.config/syncthing/config.xml"
}

configured_folders() {
  local config path
  while IFS= read -r config; do
    [[ -f "$config" ]] || continue
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      path="${path/#\~/$HOME}"
      printf '%s\n' "$path"
    done < <(python3 - "$config" <<'PY'
import sys
import xml.etree.ElementTree as ET

try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception:
    sys.exit(0)

for folder in root.findall("folder"):
    path = folder.attrib.get("path", "")
    if path:
        print(path)
PY
)
  done < <(syncthing_config_paths)
}

target_folders() {
  local folders=() folder
  if [[ ${#EXPLICIT_FOLDERS[@]} -gt 0 ]]; then
    folders=("${EXPLICIT_FOLDERS[@]}")
  else
    while IFS= read -r folder; do
      folders+=("$folder")
    done < <(configured_folders)
    if [[ ${#folders[@]} -eq 0 ]]; then
      folders=("$DEFAULT_FOLDER")
    fi
  fi

  printf '%s\n' "${folders[@]}" | awk 'NF && !seen[$0]++'
}

folder_count=0
changed_count=0
removed_total=0

while IFS= read -r FOLDER; do
  [[ -n "$FOLDER" ]] || continue
  folder_count=$((folder_count + 1))

  if [[ ! -d "$FOLDER" ]]; then
    warn "Syncthing folder not found: $FOLDER"
    continue
  fi

  if [[ ! -e "$FOLDER/.stfolder" ]]; then
    warn "no .stfolder marker in $FOLDER; this may not be a Syncthing folder root."
    warn "Proceeding anyway (the .stignore is harmless if Syncthing ignores it)."
  fi

  DEST="$FOLDER/.stignore"

  # --- 1) Decide whether the .stignore needs (re)installing -----------------
  stignore_action="up-to-date"
  desired="$(mktemp)"
  if [[ -f "$DEST" ]]; then
    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
      $0 == begin { skip = 1; next }
      $0 == end { skip = 0; next }
      !skip { print }
    ' "$DEST" > "$desired"
    if [[ -s "$desired" ]] && [[ "$(tail -c 1 "$desired")" != "" ]]; then
      printf '\n' >> "$desired"
    fi
    cat "$TEMPLATE" >> "$desired"
    if ! cmp -s "$desired" "$DEST"; then
      stignore_action="update"
    fi
  else
    cat "$TEMPLATE" > "$desired"
    stignore_action="install"
  fi

# --- 2) Collect existing conflict files ------------------------------------
  conflicts=()
  declare -A seen_conflicts=()
  for pattern in '*.sync-conflict-*' '*sync-conflict-*' 'data-sync-conflict.*'; do
    while IFS= read -r -d '' f; do
      if [[ -z "${seen_conflicts[$f]:-}" ]]; then
        seen_conflicts[$f]=1
        conflicts+=("$f")
      fi
    done < <(find "$FOLDER" -type f -name "$pattern" -print0 2>/dev/null)
  done

  log "Folder:        $FOLDER"
  log ".stignore:     $stignore_action"
  log "Conflict files: ${#conflicts[@]} found"

  if [[ "$APPLY" -eq 0 ]]; then
    rm -f "$desired"
    if [[ ${#conflicts[@]} -gt 0 ]]; then
      log "Would remove:"
      printf '  %s\n' "${conflicts[@]}"
    fi
    continue
  fi

  # --- APPLY ----------------------------------------------------------------
  if [[ "$stignore_action" != "up-to-date" ]]; then
    mv "$desired" "$DEST"
    changed_count=$((changed_count + 1))
    log ".stignore ${stignore_action}d: $DEST"
  else
    rm -f "$desired"
    log ".stignore already current: $DEST"
  fi

  removed=0
  for f in "${conflicts[@]}"; do
    # Belt-and-braces: only ever delete genuine conflict files.
    case "$f" in
      *.sync-conflict-*|*sync-conflict-*|*data-sync-conflict.*)
        rm -f -- "$f" && removed=$((removed + 1)) ;;
      *)
        warn "skipped non-conflict path: $f" ;;
    esac
  done
  removed_total=$((removed_total + removed))
  log "Removed $removed conflict file(s)."
done < <(target_folders)

if [[ "$folder_count" -eq 0 ]]; then
  warn "No Syncthing folders found. Pass --folder DIR or set SYNC_OBSIDIAN_DIR."
elif [[ "$APPLY" -eq 0 ]]; then
  log "DRY-RUN (no changes). Re-run with --apply to install and sweep."
else
  log "Done. Updated $changed_count folder(s); removed $removed_total conflict file(s)."
  log "Restart/rescan in the Syncthing Web UI (http://127.0.0.1:8384) if it"
  log "does not pick up the new .stignore automatically."
fi
