#!/usr/bin/env bash
# system-setup.sh — automate the NixOS SYSTEM layer that standalone Home
# Manager cannot set: fish as login shell, your user in trusted-users, a
# declarative non-destructive GC timer, and the system time zone. Then runs
# `nixos-rebuild switch`.
#
# Requires sudo (it edits /etc/nixos and rebuilds the system). It is:
#   - idempotent: skips settings already present; safe to re-run
#   - backed up: copies configuration.nix to a timestamped .bak first
#   - report-first: default prints the plan; pass --apply to mutate
#
# Usage:
#   bash ops/system-setup.sh                 # report only (no sudo needed)
#   sudo bash ops/system-setup.sh --apply    # apply + nixos-rebuild switch
#   USER_NAME=youruser sudo bash ops/system-setup.sh --apply
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYS="/etc/nixos/configuration.nix"
MODULE="/etc/nixos/app-configs-extra.nix"
[[ -f "$SYS" ]] || fail "$SYS not found"
USER_NAME="${USER_NAME:-${SUDO_USER:-$USER}}"
FLAKE_ARG=""
[[ -f /etc/nixos/flake.nix ]] && FLAKE_ARG="--flake /etc/nixos#nixos"

log "Target user: $USER_NAME"
log "System config: $SYS"
log "Rebuild cmd: nixos-rebuild switch ${FLAKE_ARG:-(non-flake)}"

SYSTEM_TIMEZONE="${SYSTEM_TIMEZONE:-Europe/London}"
cur_timezone="$(bash "$SCRIPT_DIR/detect-timezone.sh")"

# Two distinct questions, kept separate to make re-runs idempotent:
#
#   need_*  = should this setting be WRITTEN into the module we own ($MODULE)?
#             True when it is absent from the user's own configuration.nix ($SYS).
#             We deliberately ignore $MODULE here: $MODULE is fully regenerated
#             every run, so each managed setting must be re-emitted or it would be
#             dropped.
#
#   have_*  = is this setting ALREADY satisfied on the live system or in $MODULE?
#             Used only for the "nothing to do" early exit.
in_sys()    { grep -q "$1" "$SYS" 2>/dev/null; }
in_module() { [[ -f "$MODULE" ]] && grep -q "$1" "$MODULE" 2>/dev/null; }

need_fish=1; need_trusted=1; need_gc=1; need_timezone=1
in_sys "programs.fish.enable" && need_fish=0
in_sys "trusted-users" && need_trusted=0
in_sys "nix.gc" && need_gc=0
# Timezone: only let configuration.nix own it if it ALREADY pins our target zone;
# a stale `time.timeZone = "America/New_York"` must NOT suppress our module entry.
if grep -q "time.timeZone\s*=\s*\"${SYSTEM_TIMEZONE}\"" "$SYS" 2>/dev/null; then
  need_timezone=0
fi

# Already fully applied? (live state or already in the module we manage)
have_fish=0; have_trusted=0; have_gc=0; have_timezone=0
{ in_sys "programs.fish.enable" || in_module "programs.fish.enable"; } && have_fish=1
{ in_sys "trusted-users" || in_module "trusted-users"; } && have_trusted=1
{ in_sys "nix.gc" || in_module "nix.gc"; } && have_gc=1
{ [[ "$cur_timezone" == "$SYSTEM_TIMEZONE" ]] || in_module "time.timeZone"; } && have_timezone=1

if (( have_fish == 1 && have_trusted == 1 && have_gc == 1 && have_timezone == 1 )); then
  log "All recommended system settings already present."
  if [[ "$MODE" == "apply" ]]; then
    log "Running nixos-rebuild to ensure system is current…"
    # shellcheck disable=SC2086
    nixos-rebuild switch $FLAKE_ARG || fail "nixos-rebuild failed"
  fi
  log "Nothing to add. Done."
  exit 0
fi

# Build the snippet. Every setting not owned by configuration.nix is (re)emitted
# so the regenerated $MODULE is always complete and never drops a prior setting.
SNIPPET="$(mktemp)"
{
  echo ""
  echo "# ─── Added by app-configs ops/system-setup.sh ───"
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
  (( need_timezone == 1 )) && {
    echo "  # Europe/London is the shipped default. mkForce makes this win over"
    echo "  # the stock installer line in /etc/nixos/configuration.nix (often"
    echo "  # America/New_York) without editing that file by hand. Override by"
    echo "  # re-running with SYSTEM_TIMEZONE=Area/City if this host needs a different zone."
    echo "  time.timeZone = lib.mkForce \"${SYSTEM_TIMEZONE}\";"
  }
  echo "}"
} > "$SNIPPET"

log "Would add the following to a new module imported by your system:"
sed 's/^/    /' "$SNIPPET"

if [[ "$MODE" != "apply" ]]; then
  log "Report only. Re-run with: sudo bash ops/system-setup.sh --apply"
  rm -f "$SNIPPET"
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || fail "--apply needs root: sudo bash ops/system-setup.sh --apply"

# Write as a SEPARATE module to avoid mangling the user's configuration.nix,
# and import it from configuration.nix if not already imported. ($MODULE is
# defined near the top alongside the detection logic.)
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
cp -a "$SYS" "${SYS}.bak-${STAMP}" || fail "backup failed"
log "Backed up $SYS -> ${SYS}.bak-${STAMP}"
cp "$SNIPPET" "$MODULE" || fail "could not write $MODULE"
rm -f "$SNIPPET"
log "Wrote $MODULE"

# Wire the module in. Strategy, most robust first:
#   1. flake systems: add to the flake's `modules = [ ... ]` (clean, flake-native)
#   2. else: add to configuration.nix `imports = [ ... ]` — handles BOTH the
#      same-line form (`imports = [`) and the common multi-line form
#      (`imports =\n  [ ...`) by inserting after the first `[` that follows
#      an `imports =` token. Uses awk for multi-line safety (sed is line-based).
FLAKE="/etc/nixos/flake.nix"
wired=0

if [[ -n "$FLAKE_ARG" && -f "$FLAKE" ]]; then
  if grep -q "app-configs-extra.nix" "$FLAKE"; then
    wired=1; log "flake already imports the module"
  elif grep -qE 'modules\s*=\s*\[' "$FLAKE"; then
    cp -a "$FLAKE" "${FLAKE}.bak-${STAMP}"
    # Insert after the line containing `modules = [`.
    awk '
      done==0 && /modules[[:space:]]*=[[:space:]]*\[/ { print; print "        ./app-configs-extra.nix"; done=1; next }
      { print }
    ' "$FLAKE" > "${FLAKE}.tmp" && mv "${FLAKE}.tmp" "$FLAKE"
    grep -q "app-configs-extra.nix" "$FLAKE" && { wired=1; log "Added ./app-configs-extra.nix to flake modules in $FLAKE (backup ${FLAKE}.bak-${STAMP})"; }
  fi
fi

if [[ "$wired" -eq 0 ]]; then
  if grep -q "app-configs-extra.nix" "$SYS"; then
    wired=1; log "configuration.nix already imports the module"
  else
    # Multi-line-safe: insert after the first '[' that opens the imports list.
    awk '
      done==0 && seen_imports==1 && /\[/ {
        sub(/\[/, "[ ./app-configs-extra.nix"); done=1; seen_imports=0; print; next
      }
      /imports[[:space:]]*=/ { seen_imports=1 }
      { print }
    ' "$SYS" > "${SYS}.tmp" && mv "${SYS}.tmp" "$SYS"
    grep -q "app-configs-extra.nix" "$SYS" && { wired=1; log "Added ./app-configs-extra.nix to imports in $SYS"; }
  fi
fi

[[ "$wired" -eq 1 ]] || fail "could not wire app-configs-extra.nix into flake.nix or configuration.nix; add it to an imports/modules list manually then re-run"

log "Running nixos-rebuild switch…"
# shellcheck disable=SC2086
nixos-rebuild switch $FLAKE_ARG || fail "nixos-rebuild failed (system unchanged; check the error above)"

log "Done. Open a NEW terminal to land in fish."
log "Confirm: nixos-rebuild list-generations | head ; systemctl --failed"
