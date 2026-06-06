#!/usr/bin/env bash
# vicinae-extension.sh — set up a Raycast-compatible extension for Vicinae from
# source, reproducibly. Vicinae runs most Raycast extensions; this automates the
# official "from source" path (https://vicinae.com/docs) so it is one command.
#
# Why from source: extensions installed from a store are pre-bundled and cannot
# be debugged/rebuilt. Building from source gives you a development build you
# control. For ready-to-use extensions, prefer the in-app Store (see
# repo-docs/vicinae-extensions.md).
#
# What it does (idempotent):
#   1. Verifies vicinae + node + npm + git are present.
#   2. Clones (or updates) the raycast/extensions monorepo into a cache dir.
#   3. cd into extensions/<name>, runs `npm install` and adds the Vicinae SDK
#      (@vicinae/api) as a dev dependency.
#   4. Runs `npx vici develop` (default) or `npx vici build` with --build.
#
# Usage:
#   bash ops/vicinae-extension.sh <extension-dir-name>
#   bash ops/vicinae-extension.sh visual-studio-code-recent-projects
#   bash ops/vicinae-extension.sh <name> --build      # production build, no watch
#   VICINAE_EXT_CACHE=~/code/raycast bash ops/vicinae-extension.sh <name>
#
# List candidates:
#   bash ops/vicinae-extension.sh --list | grep -i code
#
# Linux only (Vicinae is Linux-only). Exits non-zero on failure.

set -uo pipefail

log()  { printf '[vicinae-ext] %s\n' "$*"; }
fail() { printf '[vicinae-ext:error] %s\n' "$*" >&2; exit 1; }

REPO_URL="https://github.com/raycast/extensions"
CACHE_DIR="${VICINAE_EXT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/vicinae/raycast-extensions}"
SRC_DIR="$CACHE_DIR/extensions"

MODE="develop"
EXT_NAME=""
for a in "$@"; do
  case "$a" in
    --build)  MODE="build" ;;
    --list)   MODE="list" ;;
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
    -*)       fail "unknown flag: $a" ;;
    *)        EXT_NAME="$a" ;;
  esac
done

# Vicinae is Linux-only; bail clearly elsewhere.
case "$(uname -s)" in
  Linux) : ;;
  *) fail "Vicinae (and its extensions) are Linux-only; nothing to do on $(uname -s)" ;;
esac

# Tooling checks — all of these are shipped by this repo's Nix modules.
command -v git  >/dev/null 2>&1 || fail "git not found (ship via nix/modules/common/packages.nix)"
command -v node >/dev/null 2>&1 || fail "node not found (ship via nix/modules/home/dev.nix: nodejs_22)"
command -v npm  >/dev/null 2>&1 || fail "npm not found (comes with nodejs)"
command -v vicinae >/dev/null 2>&1 \
  || fail "vicinae not found — run: home-manager switch (gui.nix ships it)"

# Validate inputs BEFORE any network/clone: develop/build need an extension name.
# Only --list may proceed without one. This keeps a bad invocation instant and
# offline instead of triggering a multi-hundred-MB clone first.
if [[ "$MODE" != "list" && -z "$EXT_NAME" ]]; then
  fail "no extension name given. List candidates first: bash $0 --list"
fi

# Clone or update the Raycast extensions monorepo (shallow to keep it small).
if [[ -d "$SRC_DIR/.git" ]]; then
  log "Updating extensions repo in $SRC_DIR"
  git -C "$SRC_DIR" pull --ff-only --depth 1 >/dev/null 2>&1 \
    || log "pull skipped (offline or shallow); using existing checkout"
else
  log "Cloning $REPO_URL (shallow) into $SRC_DIR"
  mkdir -p "$CACHE_DIR"
  git clone --depth 1 "$REPO_URL" "$SRC_DIR" || fail "git clone failed"
fi

if [[ "$MODE" == "list" ]]; then
  log "Available extensions (extensions/<name>):"
  find "$SRC_DIR/extensions" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
  exit 0
fi

EXT_PATH="$SRC_DIR/extensions/$EXT_NAME"
[[ -d "$EXT_PATH" ]] || fail "extension '$EXT_NAME' not found at $EXT_PATH (try --list)"

log "Extension: $EXT_NAME"
log "Path: $EXT_PATH"

cd "$EXT_PATH" || fail "cannot cd to $EXT_PATH"

log "Installing dependencies (npm install)…"
npm install || fail "npm install failed"

log "Adding Vicinae SDK (@vicinae/api) as a dev dependency…"
npm install --save-dev @vicinae/api || fail "installing @vicinae/api failed"

if [[ "$MODE" == "build" ]]; then
  log "Production build: npx vici build"
  npx vici build || fail "vici build failed"
  log "Done. Built extension is registered with Vicinae. Open it with: vicinae toggle"
else
  log "Development session: npx vici develop"
  log "(Leave this running; the extension appears in Vicinae. Ctrl-C to stop.)"
  exec npx vici develop
fi
