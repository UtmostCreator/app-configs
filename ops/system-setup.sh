#!/usr/bin/env bash
# system-setup.sh — automate the NixOS SYSTEM layer that standalone Home
# Manager cannot set: fish as login shell, your user in trusted-users, a
# declarative non-destructive GC timer, the system time zone, the Docker
# daemon, and private Tailscale access. Then runs `nixos-rebuild switch`.
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
#   ENABLE_DOCKER=0 sudo bash ops/system-setup.sh --apply   # skip docker daemon
#   ENABLE_TAILSCALE=0 sudo bash ops/system-setup.sh --apply # skip Tailscale
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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ops/lib/preflight.sh
source "$REPO_ROOT/ops/lib/preflight.sh"
log()  { printf '[system-setup:%s] %s\n' "$MODE" "$*"; }
fail() { printf '[system-setup:error] %s\n' "$*" >&2; exit 1; }

# The test seams below point the script at fixtures, never at a real system.
[[ "$MODE" != "apply" ]] \
  || [[ -z "${SYSTEM_SETUP_NIXOS_DIR:-}${SYSTEM_SETUP_ASSUME_NIXOS:-}" ]] \
  || fail "--apply is refused while SYSTEM_SETUP_NIXOS_DIR / SYSTEM_SETUP_ASSUME_NIXOS is set (report-mode only test seams)"
# Test guard: an apply run under bats must stay inside the test's scratch dir.
[[ "$MODE" == "apply" ]] && preflight_bats_guard system-setup "to apply" "$REPO_ROOT"

# SYSTEM_SETUP_ASSUME_NIXOS=1 is a test seam: it skips the host OS probe so the
# detection logic can be exercised against fixture configs on any host.
[[ "${SYSTEM_SETUP_ASSUME_NIXOS:-0}" == 1 ]] || [[ -f /etc/NIXOS ]] \
  || grep -qi '^ID=nixos' /etc/os-release 2>/dev/null \
  || fail "not NixOS — this script only applies to NixOS systems"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SYSTEM_SETUP_NIXOS_DIR is a test seam (default /etc/nixos); tests point it at
# a fixture directory and only ever run report mode.
NIXOS_DIR="${SYSTEM_SETUP_NIXOS_DIR:-/etc/nixos}"
SYS="$NIXOS_DIR/configuration.nix"
MODULE="$NIXOS_DIR/app-configs-extra.nix"
[[ -f "$SYS" ]] || fail "$SYS not found"
USER_NAME="${USER_NAME:-${SUDO_USER:-$USER}}"
FLAKE_ARG=""
[[ -f "$NIXOS_DIR/flake.nix" ]] && FLAKE_ARG="--flake $NIXOS_DIR#nixos"

log "Target user: $USER_NAME"
log "System config: $SYS"
log "Rebuild cmd: nixos-rebuild switch ${FLAKE_ARG:-(non-flake)}"

SYSTEM_TIMEZONE="${SYSTEM_TIMEZONE:-Europe/London}"
cur_timezone="$(bash "$SCRIPT_DIR/detect-timezone.sh")"

# Docker daemon (system service). A NixOS flake in /etc/nixos evaluates in PURE
# mode, which forbids importing an absolute path outside the flake dir (the repo
# lives under $HOME). So instead of importing the repo module by absolute path,
# we COPY the self-contained module into /etc/nixos and import it by RELATIVE
# path (./). The module (nix/modules/nixos/docker.nix) declares its own
# myConfig.docker options + config, so a standalone copy is complete.
# SCRIPT_DIR is <repo>/ops, so the module is one level up.
DOCKER_MODULE_SRC="$(cd "$SCRIPT_DIR/.." && pwd)/nix/modules/nixos/docker.nix"
DOCKER_MODULE_NAME="app-configs-docker.nix"     # basename inside /etc/nixos
DOCKER_MODULE_DST="$NIXOS_DIR/${DOCKER_MODULE_NAME}"

# On by default here so `sys-setup --apply` provisions docker.service; disable
# for a host that must not run the daemon with: ENABLE_DOCKER=0 sudo sys-setup --apply
ENABLE_DOCKER="${ENABLE_DOCKER:-1}"

# Tailscale provides the private transport for loopback-only developer tools.
# The daemon is enabled here; joining a tailnet and configuring `tailscale
# serve` remain explicit, one-time user actions handled by dsh-remote-setup.
ENABLE_TAILSCALE="${ENABLE_TAILSCALE:-1}"

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
#
# Detection looks only at ACTIVE Nix text, deliberately without parsing strings:
# lines whose first non-blank character is `#`, and `/* ... */` blocks that
# START a line, are ignored; everything else counts (so a "/home/*/.cache"
# glob or a URL #fragment inside a string can never hide a real setting). A
# trailing `# comment` after code is therefore still searched — an accepted
# trade-off. The text is collapsed to one line so multi-line lists match.
#   - ANY `opt = ...` assignment means the USER owns the option; a literal
#     `false` is additionally reported ("disabled in configuration.nix; not
#     overriding"). We never override, since a second definition would conflict
#     at NixOS eval time.
#   - Edge: a line inside a '' string that starts with `/*` is treated as a
#     block-comment start and skipped (strings are not parsed).
#   - trusted-users must name the target user (or @wheel); another user's
#     entry does not make $USER_NAME trusted.
active_nix() {
  [[ -f "$1" ]] || return 0
  awk '
    inblock { if (index($0, "*/")) inblock = 0; next }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*\/\*/ { if (!index($0, "*/")) inblock = 1; next }
    { print }
  ' "$1" | tr '\n' ' '
}
in_text()   { local t; t="$(active_nix "$1")"; grep -Eq "$2" <<<"$t"; }
in_sys()    { in_text "$SYS" "$1"; }
in_module() { [[ -f "$MODULE" ]] && in_text "$MODULE" "$1"; }
# Regexes for "<dotted.option> = true" / "= false" / either (dots escaped).
opt_enabled()  { local o="${1//./\\.}"; printf '%s\\s*=\\s*true' "$o"; }
opt_disabled() { local o="${1//./\\.}"; printf '%s\\s*=\\s*false' "$o"; }
# opt_set: ANY assignment (true, false, lib.mkForce false, config.x ...) is
# user-owned; emitting our own definition next to it would conflict at eval time.
opt_set()      { local o="${1//./\\.}"; printf '%s\\s*=' "$o"; }
# nix.gc: any definition is user-owned; "off" via the dotted or the block form.
gc_disabled_re='nix\.gc\.automatic\s*=\s*false|nix\.gc\s*=\s*\{[^}]*automatic\s*=\s*false'
# trusted-users must list the target user (or the wheel group); [^;]* stays
# inside one assignment but spans lines.
trusted_re() { printf 'trusted-users[^;]*("%s"|"@wheel")' "$USER_NAME"; }

# Tell the user when their own config disables something we would manage.
note_disabled() { in_sys "$2" && log "$1 disabled in configuration.nix; not overriding"; return 0; }
note_disabled programs.fish "$(opt_disabled programs.fish.enable)"
note_disabled nix.gc "$gc_disabled_re"
(( ENABLE_DOCKER == 1 )) && note_disabled docker "$(opt_disabled virtualisation.docker.enable)"
(( ENABLE_TAILSCALE == 1 )) && note_disabled tailscale "$(opt_disabled services.tailscale.enable)"

need_fish=1; need_trusted=1; need_gc=1; need_timezone=1
in_sys "$(opt_set programs.fish.enable)" && need_fish=0
in_sys "$(trusted_re)" && need_trusted=0
in_sys 'nix\.gc' && need_gc=0
# Timezone: only let configuration.nix own it if it ALREADY pins our target zone;
# a stale `time.timeZone = "America/New_York"` must NOT suppress our module entry.
if in_sys "time\\.timeZone\\s*=\\s*\"${SYSTEM_TIMEZONE}\""; then
  need_timezone=0
fi
# Docker: only skip re-emitting the copied-module import + toggle if
# configuration.nix already provides docker itself (its own docker import or a
# direct virtualisation.docker.enable).
need_docker=0
if (( ENABLE_DOCKER == 1 )); then
  need_docker=1
  { in_sys "$(opt_set virtualisation.docker.enable)" || in_sys "${DOCKER_MODULE_NAME//./\\.}"; } && need_docker=0
fi
need_tailscale=0
if (( ENABLE_TAILSCALE == 1 )); then
  need_tailscale=1
  in_sys "$(opt_set services.tailscale.enable)" && need_tailscale=0
fi

# Already fully applied? (live state or already in the module we manage)
have_fish=0; have_trusted=0; have_gc=0; have_timezone=0; have_docker=1; have_tailscale=1
{ in_sys "$(opt_set programs.fish.enable)" || in_module "$(opt_enabled programs.fish.enable)"; } && have_fish=1
{ in_sys "$(trusted_re)" || in_module "$(trusted_re)"; } && have_trusted=1
{ in_sys 'nix\.gc' || in_module 'nix\.gc'; } && have_gc=1
{ [[ "$cur_timezone" == "$SYSTEM_TIMEZONE" ]] || in_module 'time\.timeZone'; } && have_timezone=1
# Docker is satisfied when disabled, or the daemon is live, or configuration.nix
# declares it, or our copied module is imported AND the copied file exists on disk
# (existence matters: a pure flake fails if the imported ./file is absent).
if (( ENABLE_DOCKER == 1 )); then
  have_docker=0
  { systemctl is-active docker >/dev/null 2>&1 \
    || in_sys "$(opt_set virtualisation.docker.enable)" || in_sys "${DOCKER_MODULE_NAME//./\\.}" \
    || { in_module "${DOCKER_MODULE_NAME//./\\.}" && in_module "$(opt_enabled myConfig.docker.enable)" \
         && [[ -f "$DOCKER_MODULE_DST" ]]; }; } && have_docker=1
fi
if (( ENABLE_TAILSCALE == 1 )); then
  have_tailscale=0
  { systemctl is-active tailscaled >/dev/null 2>&1 \
    || in_sys "$(opt_set services.tailscale.enable)" \
    || in_module "$(opt_enabled services.tailscale.enable)"; } && have_tailscale=1
fi

if (( have_fish == 1 && have_trusted == 1 && have_gc == 1 && have_timezone == 1 && have_docker == 1 && have_tailscale == 1 )); then
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
  (( need_docker == 1 )) && {
    echo "  # Docker daemon via the self-contained module copied next to this file"
    echo "  # (./$DOCKER_MODULE_NAME). Copied rather than imported by absolute path"
    echo "  # because a pure-eval flake forbids importing outside /etc/nixos."
    echo "  # myConfig.docker.enable turns on the daemon and adds ${USER_NAME} to the"
    echo "  # docker group. Disable with ENABLE_DOCKER=0 when re-running this script."
    echo "  imports = [ ./$DOCKER_MODULE_NAME ];"
    echo "  myConfig.docker.enable = true;"
    echo "  myConfig.docker.user = \"${USER_NAME}\";"
  }
  (( need_fish == 1 ))    && {
    echo "  programs.fish.enable = true;"
    echo "  users.users.\"${USER_NAME}\".shell = pkgs.fish;"
  }
  (( need_trusted == 1 )) && echo "  nix.settings.trusted-users = [ \"root\" \"${USER_NAME}\" ];"
  (( need_gc == 1 ))      && {
    echo "  nix.gc = { automatic = true; dates = \"weekly\"; options = \"--delete-older-than 14d\"; };"
    # A user-defined nix.optimise.automatic must not get a second definition.
    in_sys 'nix\.optimise\.automatic\s*=' || echo "  nix.optimise.automatic = true;"
  }
  (( need_timezone == 1 )) && {
    echo "  # Europe/London is the shipped default. mkForce makes this win over"
    echo "  # the stock installer line in /etc/nixos/configuration.nix (often"
    echo "  # America/New_York) without editing that file by hand. Override by"
    echo "  # re-running with SYSTEM_TIMEZONE=Area/City if this host needs a different zone."
    echo "  time.timeZone = lib.mkForce \"${SYSTEM_TIMEZONE}\";"
  }
  (( need_tailscale == 1 )) && {
    echo "  # Private remote access for loopback-only developer services."
    echo "  services.tailscale.enable = true;"
    echo "  # Keep user services available after logout and across headless boots."
    echo "  users.users.\"${USER_NAME}\".linger = true;"
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

# Docker module: keep the copied ./app-configs-docker.nix in sync with the repo
# so the relative import in $MODULE always resolves under pure evaluation.
if (( ENABLE_DOCKER == 1 )); then
  [[ -f "$DOCKER_MODULE_SRC" ]] || fail "docker module not found at $DOCKER_MODULE_SRC"
  cp "$DOCKER_MODULE_SRC" "$DOCKER_MODULE_DST" || fail "could not write $DOCKER_MODULE_DST"
  log "Copied docker module -> $DOCKER_MODULE_DST"
elif [[ -f "$DOCKER_MODULE_DST" ]]; then
  # Docker disabled this run and $MODULE no longer imports it: drop the stale
  # copy so no orphaned file lingers in /etc/nixos.
  rm -f "$DOCKER_MODULE_DST"
  log "Removed stale $DOCKER_MODULE_DST (ENABLE_DOCKER=0)"
fi

# Wire the module in. Strategy, most robust first:
#   1. flake systems: add to the flake's `modules = [ ... ]` (clean, flake-native)
#   2. else: add to configuration.nix `imports = [ ... ]` — handles BOTH the
#      same-line form (`imports = [`) and the common multi-line form
#      (`imports =\n  [ ...`) by inserting after the first `[` that follows
#      an `imports =` token. Uses awk for multi-line safety (sed is line-based).
FLAKE="$NIXOS_DIR/flake.nix"
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
