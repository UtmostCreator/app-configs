#!/usr/bin/env bash
# system-setup.sh — automate the NixOS SYSTEM layer that standalone Home
# Manager cannot set: fish as login shell, your user in trusted-users, and a
# declarative non-destructive GC timer. Then runs `nixos-rebuild switch`.
#
# Requires sudo (it edits /etc/nixos and rebuilds the system). It is:
#   - idempotent: skips settings already present; safe to re-run
#   - backed up: copies configuration.nix to a timestamped .bak first
#   - report-first: default prints the plan; pass --apply to mutate
#
# Usage:
#   bash scripts/system-setup.sh                 # report only (no sudo needed)
#   sudo bash scripts/system-setup.sh --apply    # apply + nixos-rebuild switch
#   USER_NAME=youruser sudo bash scripts/system-setup.sh --apply
#
# Exit non-zero on failure. NixOS only.

set -uo pipefail

MODE="report"
for a in "$@"; do
  case "$a" in
    --apply) MODE="apply" ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf '[system-setup] unknown arg: %s\n' "$a" >&2; exit 1 ;;
  esac
done

log()  { printf '[system-setup:%s] %s\n' "$MODE" "$*"; }
fail() { printf '[system-setup:error] %s\n' "$*" >&2; exit 1; }

[[ -f /etc/NIXOS ]] || grep -qi '^ID=nixos' /etc/os-release 2>/dev/null \
  || fail "not NixOS — this script only applies to NixOS systems"

SYS="/etc/nixos/configuration.nix"
[[ -f "$SYS" ]] || fail "$SYS not found"
USER_NAME="${USER_NAME:-${SUDO_USER:-$USER}}"
FLAKE_ARG=""
[[ -f /etc/nixos/flake.nix ]] && FLAKE_ARG="--flake /etc/nixos#nixos"

log "Target user: $USER_NAME"
log "System config: $SYS"
log "Rebuild cmd: nixos-rebuild switch ${FLAKE_ARG:-(non-flake)}"

# Decide which settings are missing.
need_fish=1; need_trusted=1; need_gc=1
grep -q "programs.fish.enable" "$SYS" && need_fish=0
grep -q "trusted-users" "$SYS" && need_trusted=0
grep -q "nix.gc" "$SYS" && need_gc=0

if (( need_fish == 0 && need_trusted == 0 && need_gc == 0 )); then
  log "All recommended system settings already present."
  if [[ "$MODE" == "apply" ]]; then
    log "Running nixos-rebuild to ensure system is current…"
    # shellcheck disable=SC2086
    nixos-rebuild switch $FLAKE_ARG || fail "nixos-rebuild failed"
  fi
  log "Nothing to add. Done."
  exit 0
fi

# Build the snippet (only the missing parts).
SNIPPET="$(mktemp)"
{
  echo ""
  echo "# ─── Added by app-configs scripts/system-setup.sh ───"
  echo "# Module form: merges with your existing configuration."
  echo "{ config, pkgs, lib, ... }:"
  echo "{"
  (( need_fish == 1 ))    && {
    echo "  programs.fish.enable = true;"
    echo "  users.users.\"${USER_NAME}\".shell = pkgs.fish;"
  }
  (( need_trusted == 1 )) && echo "  nix.settings.trusted-users = [ \"root\" \"${USER_NAME}\" ];"
  (( need_gc == 1 ))      && {
    echo "  nix.gc = { automatic = true; dates = \"weekly\"; options = \"--delete-older-than 14d\"; };"
    echo "  nix.optimise.automatic = true;"
  }
  echo "}"
} > "$SNIPPET"

log "Would add the following to a new module imported by your system:"
sed 's/^/    /' "$SNIPPET"

if [[ "$MODE" != "apply" ]]; then
  log "Report only. Re-run with: sudo bash scripts/system-setup.sh --apply"
  rm -f "$SNIPPET"
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || fail "--apply needs root: sudo bash scripts/system-setup.sh --apply"

# Write as a SEPARATE module to avoid mangling the user's configuration.nix,
# and import it from configuration.nix if not already imported.
MODULE="/etc/nixos/app-configs-extra.nix"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
cp -a "$SYS" "${SYS}.bak-${STAMP}" || fail "backup failed"
log "Backed up $SYS -> ${SYS}.bak-${STAMP}"
cp "$SNIPPET" "$MODULE" || fail "could not write $MODULE"
rm -f "$SNIPPET"
log "Wrote $MODULE"

if ! grep -q "app-configs-extra.nix" "$SYS"; then
  # Insert the import into the imports = [ ... ] list, or append a wrapper.
  if grep -qE '^\s*imports\s*=\s*\[' "$SYS"; then
    sed -i 's#\(imports\s*=\s*\[\)#\1 ./app-configs-extra.nix#' "$SYS" \
      || fail "could not inject import"
    log "Added ./app-configs-extra.nix to imports in $SYS"
  else
    fail "no 'imports = [ ... ]' found in $SYS; add 'imports = [ ./app-configs-extra.nix ];' manually then re-run"
  fi
fi

log "Running nixos-rebuild switch…"
# shellcheck disable=SC2086
nixos-rebuild switch $FLAKE_ARG || fail "nixos-rebuild failed (system unchanged; check the error above)"

log "Done. Open a NEW terminal to land in fish."
log "Confirm: nixos-rebuild list-generations | head ; systemctl --failed"
