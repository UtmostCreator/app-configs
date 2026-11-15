#!/usr/bin/env bash
# system-setup.sh — automate the NixOS SYSTEM layer that standalone Home
# Manager cannot set: fish as login shell, your user in trusted-users, a
# declarative non-destructive GC timer, the system time zone, the Docker
# daemon, and private Tailscale access. Then runs `nixos-rebuild switch`.
#
# Requires sudo (it edits /etc/nixos and rebuilds the system). It is:
#   - idempotent: skips settings already present; safe to re-run
#   - backed up: before any write it records every file it may touch (content,
#     mode, owner, symlink, or absent) in <nixos dir>.app-configs-backup-<stamp>/
#     and copies configuration.nix to a timestamped .bak
#   - validated: `nixos-rebuild dry-build` runs before the real rebuild; on a
#     dry-build or rebuild failure every file is restored exactly as recorded.
#     Exception, on every host: a `switch` that exits 4 (switch-to-configuration:
#     the new generation IS activated, but some units failed) or 2 (its activate
#     script failed, after the profile had already moved) keeps the new files,
#     because they match the running system and restoring them would leave
#     /etc/nixos and the running generation disagreeing. The failed units are
#     listed, the rollback command and the later restore step are printed, and
#     the run exits with that same code (never ignored). Exit 100 (the build or
#     the profile switch itself failed, nothing activated) and every other
#     code restore. The classification relies on nixos-rebuild-ng passing
#     switch-to-configuration's exit code through; the legacy nixos-rebuild
#     reports an activation failure as exit 1, which restores.
#   - report-first: default prints the plan; pass --apply to mutate
#
# NixOS-WSL (HOST_PROFILE=wsl, or detect-host says wsl): the same, plus the
# wsl module (wsl.defaultUser) and programs.nix-ld.enable, Docker and Tailscale OFF by default
# (ENABLE_DOCKER=1 opts in; DOCKER_GROUP=1 adds the docker group user,
# DOCKER_ROOTLESS=1 runs the daemon rootless; Docker is refused next to Docker
# Desktop integration), and `nixos-rebuild boot` instead of `switch` while the
# target user does not exist yet. configuration.nix must already be NixOS-WSL
# (it mentions nixos-wsl and sets wsl.enable = true); no wsl.* line is edited.
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
    -h|--help) sed -n '2,/^# Exit non-zero on failure/p' "$0"; exit 0 ;;
    *) printf '[system-setup] unknown arg: %s\n' "$a" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ops/lib/preflight.sh
source "$REPO_ROOT/ops/lib/preflight.sh"
log()  { printf '[system-setup:%s] %s\n' "$MODE" "$*"; }

# Backup/restore of every file an apply run may touch (see snapshot_state). The
# globals are filled in by snapshot_state; until then restore_state does nothing.
BACKUP_DIR=""
CREATED_FILES=()
SWITCH_STARTED=0
BOOT_STARTED=0
SNIPPET=""

# Put every recorded file back exactly as it was: absent stays absent, a file
# or symlink is copied back with cp -a (content, mode, owner, link target), and
# the .bak files this run created are removed. Cannot recurse into itself.
restore_state() {
  [[ -n "$BACKUP_DIR" && -f "$BACKUP_DIR/manifest.tsv" ]] || return 0
  local bd="$BACKUP_DIR" p st mode own name tgt f rc=0
  BACKUP_DIR=""
  while IFS=$'\t' read -r p st mode own name tgt; do
    rm -f -- "$p"
    case "$st" in
      file | symlink) cp -a -- "$bd/files/$name" "$p" || rc=1 ;;
    esac
  done < "$bd/manifest.tsv"
  for f in "${CREATED_FILES[@]+"${CREATED_FILES[@]}"}"; do rm -f -- "$f"; done
  if (( rc == 0 )); then
    printf '[system-setup:error] restored every touched file under %s to its recorded state (backup kept in %s)\n' "$NIXOS_DIR" "$bd" >&2
  else
    printf '[system-setup:error] RESTORE FAILED for at least one file; the originals are in %s\n' "$bd" >&2
  fi
}

fail() {
  printf '[system-setup:error] %s\n' "$*" >&2
  [[ -z "$SNIPPET" ]] || rm -f -- "$SNIPPET"
  restore_state
  if (( SWITCH_STARTED == 1 )); then
    printf '[system-setup:error] a nixos-rebuild switch had started; to return to the previous generation run: sudo nixos-rebuild switch --rollback\n' >&2
  fi
  if (( BOOT_STARTED == 1 )); then
    printf '[system-setup:error] a nixos-rebuild boot had started; to drop it from the next boot run: sudo nixos-rebuild boot --rollback\n' >&2
  fi
  exit 1
}

# The test seams below point the script at fixtures. Report mode honours them
# anywhere. --apply honours SYSTEM_SETUP_NIXOS_DIR / SYSTEM_SETUP_ASSUME_NIXOS
# only under bats, with the directory inside $BATS_TEST_TMPDIR (no ".."): that
# is APPLY_SEAM=1, which also needs a stub nixos-rebuild on PATH from the same
# temp dir and refuses to run as root. preflight_bats_guard (below) then insists
# on a scratch HOME and a repo copy.
APPLY_SEAM=0
if [[ "$MODE" == apply && -n "${SYSTEM_SETUP_NIXOS_DIR:-}${SYSTEM_SETUP_ASSUME_NIXOS:-}" ]]; then
  if [[ -n "${BATS_TEST_TMPDIR:-}" && -n "${SYSTEM_SETUP_NIXOS_DIR:-}" \
    && "$SYSTEM_SETUP_NIXOS_DIR" != */../* && "$SYSTEM_SETUP_NIXOS_DIR" != */.. ]] \
    && _preflight_under "$SYSTEM_SETUP_NIXOS_DIR" "$BATS_TEST_TMPDIR"; then
    APPLY_SEAM=1
  else
    fail "--apply is refused while SYSTEM_SETUP_NIXOS_DIR / SYSTEM_SETUP_ASSUME_NIXOS is set (report-mode only test seams; under bats a fixture directory inside \$BATS_TEST_TMPDIR also works)"
  fi
fi
# Test guard: an apply run under bats must stay inside the test's scratch dir.
[[ "$MODE" == "apply" ]] && preflight_bats_guard system-setup "to apply" "$REPO_ROOT"

# SYSTEM_SETUP_ASSUME_NIXOS=1 is a test seam: it skips the host OS probe so the
# detection logic can be exercised against fixture configs on any host.
[[ "${SYSTEM_SETUP_ASSUME_NIXOS:-0}" == 1 ]] || [[ -f /etc/NIXOS ]] \
  || grep -qi '^ID=nixos' /etc/os-release 2>/dev/null \
  || fail "not NixOS — this script only applies to NixOS systems"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The host profile (macos | linux-desktop | linux-cli | wsl). Only `wsl` changes
# anything below: every IS_WSL branch is inert on the desktop.
HOST_PROFILE="${HOST_PROFILE:-$(bash "$SCRIPT_DIR/detect-host.sh" 2>/dev/null || echo unknown)}"
IS_WSL=0
[[ "$HOST_PROFILE" == wsl ]] && IS_WSL=1
# SYSTEM_SETUP_NIXOS_DIR is a test seam (default /etc/nixos); tests point it at
# a fixture directory (report mode, or apply under bats: see APPLY_SEAM).
NIXOS_DIR="${SYSTEM_SETUP_NIXOS_DIR:-/etc/nixos}"
SYS="$NIXOS_DIR/configuration.nix"
MODULE="$NIXOS_DIR/app-configs-extra.nix"
FLAKE="$NIXOS_DIR/flake.nix"
[[ -f "$SYS" ]] || fail "$SYS not found"
USER_NAME="${USER_NAME:-${SUDO_USER:-$USER}}"
FLAKE_ARG=""
[[ -f "$NIXOS_DIR/flake.nix" ]] && FLAKE_ARG="--flake $NIXOS_DIR#nixos"

log "Target user: $USER_NAME"
log "System config: $SYS"

# `boot` instead of `switch` on NixOS-WSL while the target user does not exist
# yet: activating a system whose wsl.defaultUser is missing would fail or hang
# mid-switch, so the new generation only becomes the next boot's.
# SYSTEM_SETUP_USER_EXISTS=0|1 is a test seam, honoured only under bats: it pins
# the answer so a test does not depend on the host's users or on getent.
user_exists() {
  if [[ -n "${BATS_TEST_TMPDIR:-}" && -n "${SYSTEM_SETUP_USER_EXISTS:-}" ]]; then
    [[ "$SYSTEM_SETUP_USER_EXISTS" == 1 ]]
    return
  fi
  getent passwd "$USER_NAME" >/dev/null 2>&1
}
REBUILD_VERB=switch
if (( IS_WSL == 1 )) && ! user_exists; then
  REBUILD_VERB=boot
fi
log "Rebuild cmd: nixos-rebuild $REBUILD_VERB ${FLAKE_ARG:-(non-flake)} (validated first with nixos-rebuild dry-build)"

SYSTEM_TIMEZONE="${SYSTEM_TIMEZONE:-Europe/London}"
# The zone is written into Nix text, so it must look like Area/City (or UTC):
# letters, digits, _ + - in slash-separated parts, no empty part.
[[ "$SYSTEM_TIMEZONE" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] \
  || fail "invalid SYSTEM_TIMEZONE '$SYSTEM_TIMEZONE' (expected Area/City, for example Europe/London or America/Los_Angeles)"
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

# NixOS-WSL module (nix/modules/nixos/wsl.nix): wsl.defaultUser,
# copied next to configuration.nix like the Docker module, for the same
# pure-eval reason, and imported by relative path.
WSL_MODULE_SRC="$(cd "$SCRIPT_DIR/.." && pwd)/nix/modules/nixos/wsl.nix"
WSL_MODULE_NAME="app-configs-wsl.nix"
WSL_MODULE_DST="$NIXOS_DIR/${WSL_MODULE_NAME}"

# On by default here so `sys-setup --apply` provisions docker.service; disable
# for a host that must not run the daemon with: ENABLE_DOCKER=0 sudo sys-setup --apply
# Off by default on NixOS-WSL (ENABLE_DOCKER=1 opts in).
ENABLE_DOCKER="${ENABLE_DOCKER:-$(( IS_WSL == 1 ? 0 : 1 ))}"
# NixOS-WSL only: DOCKER_GROUP=1 adds the target user to the docker group
# (default: myConfig.docker.user = null, no group management), DOCKER_ROOTLESS=1
# runs the daemon rootless. Both are ignored on every other host.
DOCKER_GROUP="${DOCKER_GROUP:-0}"
DOCKER_ROOTLESS="${DOCKER_ROOTLESS:-0}"

# Tailscale provides the private transport for loopback-only developer tools.
# The daemon is enabled here; joining a tailnet and configuring `tailscale
# serve` remain explicit, one-time user actions handled by dsh-remote-setup.
# Off by default on NixOS-WSL (ENABLE_TAILSCALE=1 opts in).
ENABLE_TAILSCALE="${ENABLE_TAILSCALE:-$(( IS_WSL == 1 ? 0 : 1 ))}"

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

# NixOS-WSL only. configuration.nix must already be a NixOS-WSL config: it
# mentions nixos-wsl and sets wsl.enable = true (active text only, comments do
# not count). We never edit a wsl.* line; this only checks. Re-checked after
# the wiring so a bad edit is caught before any rebuild.
wsl_guard() {
  local t; t="$(active_nix "$SYS")"
  grep -Eiq 'nixos-wsl' <<<"$t" && grep -Eq 'wsl\.enable[[:space:]]*=[[:space:]]*true' <<<"$t"
}
if (( IS_WSL == 1 )); then
  wsl_guard || fail "HOST_PROFILE=wsl, but $SYS is not a NixOS-WSL configuration (it must mention nixos-wsl and set wsl.enable = true). Nothing was changed."
  # Docker next to Docker Desktop's WSL integration would run two daemons.
  # The directory is overridable only under bats (SYSTEM_SETUP_DOCKER_DESKTOP_DIR).
  docker_desktop_dir=/mnt/wsl/docker-desktop
  [[ -n "${BATS_TEST_TMPDIR:-}" && -n "${SYSTEM_SETUP_DOCKER_DESKTOP_DIR:-}" ]] \
    && docker_desktop_dir="$SYSTEM_SETUP_DOCKER_DESKTOP_DIR"
  if (( ENABLE_DOCKER == 1 )) \
    && { [[ -e "$docker_desktop_dir" ]] \
         || { in_sys "$(opt_set wsl.docker-desktop.enable)" && ! in_sys "$(opt_disabled wsl.docker-desktop.enable)"; }; }; then
    fail "Docker Desktop's WSL integration is present (/mnt/wsl/docker-desktop or wsl.docker-desktop.enable); refusing ENABLE_DOCKER=1 so two Docker daemons do not clash. Use ENABLE_DOCKER=0."
  fi
fi

# Tell the user when their own config disables something we would manage.
note_disabled() { in_sys "$2" && log "$1 disabled in configuration.nix; not overriding"; return 0; }
note_disabled programs.fish "$(opt_disabled programs.fish.enable)"
note_disabled nix.gc "$gc_disabled_re"
(( ENABLE_DOCKER == 1 )) && note_disabled docker "$(opt_disabled virtualisation.docker.enable)"
(( ENABLE_TAILSCALE == 1 )) && note_disabled tailscale "$(opt_disabled services.tailscale.enable)"

need_fish=1; need_trusted=1; need_gc=1; need_timezone=1
# nix-ld (NixOS-WSL only): user-owned when configuration.nix assigns it at all.
need_nixld=0
need_flakes=0
if (( IS_WSL == 1 )); then
  need_nixld=1
  in_sys "$(opt_set programs.nix-ld.enable)" && need_nixld=0
  # Flakes for ops/install.sh and sys-update; a list option, so a user-owned
  # setting is left alone rather than merged.
  need_flakes=1
  in_sys 'nix\.settings\.experimental-features|experimental-features\s*=' && need_flakes=0
fi
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
have_fish=0; have_trusted=0; have_gc=0; have_timezone=0; have_docker=1; have_tailscale=1; have_wsl=1
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

# NixOS-WSL: satisfied when the wsl module is imported and its copy is current.
if (( IS_WSL == 1 )); then
  have_wsl=0
  { in_module "${WSL_MODULE_NAME//./\\.}" && [[ -f "$WSL_MODULE_DST" ]] \
    && cmp -s "$WSL_MODULE_SRC" "$WSL_MODULE_DST" \
    && in_module 'environment\.systemPackages[^[]*\[[^]]*\bgit\b[^]]*\bcurl\b' \
    && { (( need_flakes == 0 )) || in_module 'experimental-features'; }; } && have_wsl=1
fi

# Apply-mode environment. A real run needs root. The bats fixture run (APPLY_SEAM)
# refuses root and needs the stub nixos-rebuild from the bats temp dir on PATH,
# so a test can never reach the real nixos-rebuild.
require_apply_env() {
  if (( APPLY_SEAM == 1 )); then
    [[ "$(id -u)" -ne 0 ]] || fail "the fixture apply (bats seam) refuses to run as root"
    local nr; nr="$(command -v nixos-rebuild || true)"
    if [[ -z "$nr" || "$nr" == */../* ]] || ! _preflight_under "$nr" "$BATS_TEST_TMPDIR"; then
      fail "fixture apply needs a stub nixos-rebuild on PATH from inside \$BATS_TEST_TMPDIR (found: ${nr:-none})"
    fi
  else
    [[ "$(id -u)" -eq 0 ]] || fail "--apply needs root: sudo bash ops/system-setup.sh --apply"
  fi
}

# Validate with dry-build on EVERY host, then the real rebuild. A failure here
# goes through fail(), which restores every recorded file; after a started
# switch it also prints the rollback command.
rebuild_system() {
  log "Validating with nixos-rebuild dry-build…"
  # shellcheck disable=SC2086
  nixos-rebuild dry-build $FLAKE_ARG || fail "nixos-rebuild dry-build failed (nothing was activated; files restored if this run changed any)"
  log "Running nixos-rebuild $REBUILD_VERB…"
  [[ "$REBUILD_VERB" == switch ]] && SWITCH_STARTED=1
  [[ "$REBUILD_VERB" == boot ]] && BOOT_STARTED=1
  local rc=0
  # shellcheck disable=SC2086
  nixos-rebuild "$REBUILD_VERB" $FLAKE_ARG || rc=$?
  if (( rc == 4 || rc == 2 )) && [[ "$REBUILD_VERB" == switch ]]; then
    # Activated (4: units failed; 2: the activate script failed after the profile
    # moved). Keep the files (BACKUP_DIR cleared so fail() does not restore) and
    # still fail the run with the same code; it is never ignored.
    local kept="$BACKUP_DIR"
    BACKUP_DIR=""; SWITCH_STARTED=0
    printf '[system-setup:error] nixos-rebuild switch activated the new generation, but not cleanly (exit %s: failed units or a failed activate script). The new files in %s stay: they match the running system.\n' "$rc" "$NIXOS_DIR" >&2
    [[ -z "$kept" ]] || printf '[system-setup:error] the originals are kept in %s\n' "$kept" >&2
    printf '[system-setup:error] failed units (systemctl --failed):\n' >&2
    systemctl --failed --no-legend 2>&1 | sed 's/^/[system-setup:error]   /' >&2
    printf '[system-setup:error] to return to the previous generation run: sudo nixos-rebuild switch --rollback\n' >&2
    [[ -z "$kept" ]] || printf '[system-setup:error] after that rollback, restore /etc/nixos from %s (manifest.tsv lists every file, its state and its copy under files/)\n' "$kept" >&2
    exit "$rc"
  fi
  (( rc == 0 )) || fail "nixos-rebuild $REBUILD_VERB failed (exit $rc; check the error above)"
  SWITCH_STARTED=0; BOOT_STARTED=0
}

if (( have_fish == 1 && have_trusted == 1 && have_gc == 1 && have_timezone == 1 && have_docker == 1 && have_tailscale == 1 && have_wsl == 1 )); then
  log "All recommended system settings already present."
  if [[ "$MODE" == "apply" ]]; then
    require_apply_env
    log "Running nixos-rebuild to ensure system is current…"
    rebuild_system
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
  # ONE imports list: a second `imports =` in the same attrset is a Nix error.
  imports_list=""
  (( need_docker == 1 )) && imports_list="./$DOCKER_MODULE_NAME"
  (( IS_WSL == 1 )) && imports_list="${imports_list:+$imports_list }./$WSL_MODULE_NAME"
  (( need_docker == 1 )) && {
    echo "  # Docker daemon via the self-contained module copied next to this file"
    echo "  # (./$DOCKER_MODULE_NAME). Copied rather than imported by absolute path"
    echo "  # because a pure-eval flake forbids importing outside /etc/nixos."
    if (( IS_WSL == 1 )) && [[ "$DOCKER_GROUP" != 1 ]]; then
      echo "  # myConfig.docker.enable turns on the daemon; no docker group membership"
      echo "  # on NixOS-WSL (DOCKER_GROUP=1 adds ${USER_NAME}). ENABLE_DOCKER=0 removes it."
    else
      echo "  # myConfig.docker.enable turns on the daemon and adds ${USER_NAME} to the"
      echo "  # docker group. Disable with ENABLE_DOCKER=0 when re-running this script."
    fi
  }
  (( IS_WSL == 1 )) && {
    echo "  # NixOS-WSL: wsl.defaultUser from the module copied next to this"
    echo "  # file (./$WSL_MODULE_NAME). wsl.* lines in configuration.nix are never edited."
  }
  [[ -z "$imports_list" ]] || echo "  imports = [ $imports_list ];"
  (( need_docker == 1 )) && {
    echo "  myConfig.docker.enable = true;"
    if (( IS_WSL == 1 )) && [[ "$DOCKER_GROUP" != 1 ]]; then
      echo "  myConfig.docker.user = null;"
    else
      echo "  myConfig.docker.user = \"${USER_NAME}\";"
    fi
    (( IS_WSL == 1 )) && [[ "$DOCKER_ROOTLESS" == 1 ]] && echo "  myConfig.docker.rootless = true;"
  }
  (( need_nixld == 1 )) && {
    echo "  # Lets prebuilt binaries (the claude and codex CLIs) run on NixOS-WSL."
    echo "  programs.nix-ld.enable = true;"
  }
  (( IS_WSL == 1 )) && {
    echo "  # A bare NixOS-WSL has no git or curl, which ops/install.sh, ops/doctor.sh and"
    echo "  # sys-update need before Home Manager exists."
    echo "  environment.systemPackages = with pkgs; [ git curl ];"
  }
  (( need_flakes == 1 )) && {
    echo "  # Flakes for ops/install.sh and sys-update."
    echo "  nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];"
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

require_apply_env

# Record EVERY file this run may touch before the first write: content, mode,
# owner, symlink target, or "absent". restore_state (called by fail) puts them
# back exactly. One stamped dir next to the nixos dir (not inside it: a pure
# flake copies its whole directory into the store). manifest.tsv columns, tab
# separated: path, state (file|symlink|absent), mode, owner:group, name of the
# copy under files/, symlink target ("-" when none). cp -a keeps a symlink a
# symlink and keeps mode, owner and times.
snapshot_state() {
  BACKUP_DIR="${NIXOS_DIR%/}.app-configs-backup-${STAMP}"
  local p st mode own name tgt manifest="$BACKUP_DIR/manifest.tsv"
  mkdir -m 700 "$BACKUP_DIR" "$BACKUP_DIR/files" 2>/dev/null \
    || { BACKUP_DIR=""; fail "cannot create the backup directory ${NIXOS_DIR%/}.app-configs-backup-${STAMP}"; }
  : > "$manifest"
  for p in "$SYS" "$FLAKE" "$MODULE" "$DOCKER_MODULE_DST" "$WSL_MODULE_DST" \
           "$NIXOS_DIR/flake.lock" "${SYS}.tmp" "${FLAKE}.tmp"; do
    name="$(basename "$p")"; mode="-"; own="-"; tgt="-"
    if [[ -L "$p" ]]; then
      st="symlink"; tgt="$(readlink "$p")"
    elif [[ -f "$p" ]]; then
      st="file"
    elif [[ -e "$p" ]]; then
      fail "$p exists but is neither a file nor a symlink; refusing to touch $NIXOS_DIR"
    else
      st="absent"; name="-"
    fi
    if [[ "$st" != absent ]]; then
      mode="$(stat -c '%a' "$p")"; own="$(stat -c '%U:%G' "$p")"
      cp -a -- "$p" "$BACKUP_DIR/files/$name" \
        || { rm -f "$manifest"; fail "cannot back up $p"; }
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$p" "$st" "$mode" "$own" "$name" "$tgt" >> "$manifest"
  done
  log "Recorded the state of every touched file in $BACKUP_DIR"
}

# Write as a SEPARATE module to avoid mangling the user's configuration.nix,
# and import it from configuration.nix if not already imported. ($MODULE is
# defined near the top alongside the detection logic.)
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
# Two runs in the same second must not share a backup dir or .bak names.
while [[ -e "${NIXOS_DIR%/}.app-configs-backup-${STAMP}" || -e "${SYS}.bak-${STAMP}" ]]; do STAMP="${STAMP}x"; done
snapshot_state
cp -a "$SYS" "${SYS}.bak-${STAMP}" || fail "backup failed"
CREATED_FILES+=("${SYS}.bak-${STAMP}")
log "Backed up $SYS -> ${SYS}.bak-${STAMP}"
# --remove-destination: never write through a symlink to somewhere else.
cp --remove-destination "$SNIPPET" "$MODULE" || fail "could not write $MODULE"
rm -f "$SNIPPET"; SNIPPET=""
log "Wrote $MODULE"

# Docker module: keep the copied ./app-configs-docker.nix in sync with the repo
# so the relative import in $MODULE always resolves under pure evaluation.
if (( ENABLE_DOCKER == 1 )); then
  [[ -f "$DOCKER_MODULE_SRC" ]] || fail "docker module not found at $DOCKER_MODULE_SRC"
  cp --remove-destination "$DOCKER_MODULE_SRC" "$DOCKER_MODULE_DST" || fail "could not write $DOCKER_MODULE_DST"
  log "Copied docker module -> $DOCKER_MODULE_DST"
elif [[ -e "$DOCKER_MODULE_DST" || -L "$DOCKER_MODULE_DST" ]]; then
  # Docker disabled this run and $MODULE no longer imports it: drop the stale
  # copy so no orphaned file lingers in /etc/nixos.
  rm -f "$DOCKER_MODULE_DST"
  log "Removed stale $DOCKER_MODULE_DST (ENABLE_DOCKER=0)"
fi

# NixOS-WSL module, same reason as the Docker copy.
if (( IS_WSL == 1 )); then
  [[ -f "$WSL_MODULE_SRC" ]] || fail "wsl module not found at $WSL_MODULE_SRC"
  cp --remove-destination "$WSL_MODULE_SRC" "$WSL_MODULE_DST" || fail "could not write $WSL_MODULE_DST"
  log "Copied wsl module -> $WSL_MODULE_DST"
fi

# Wire the module in. Strategy, most robust first:
#   1. flake systems: add to the flake's `modules = [ ... ]` (clean, flake-native)
#   2. else: add to configuration.nix `imports = [ ... ]` — handles BOTH the
#      same-line form (`imports = [`) and the common multi-line form
#      (`imports =\n  [ ...`) by inserting after the first `[` that follows
#      an `imports =` token. Uses awk for multi-line safety (sed is line-based).
wired=0

if [[ -n "$FLAKE_ARG" && -f "$FLAKE" ]]; then
  if grep -q "app-configs-extra.nix" "$FLAKE"; then
    wired=1; log "flake already imports the module"
  elif grep -qE 'modules\s*=\s*\[' "$FLAKE"; then
    cp -a "$FLAKE" "${FLAKE}.bak-${STAMP}"
    CREATED_FILES+=("${FLAKE}.bak-${STAMP}")
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
    # The same-line form (`imports = [`, the stock NixOS-WSL one) is handled on
    # its own line; without that rule the awk skipped it and picked a later `[`.
    awk '
      /^[[:space:]]*#/ { print; next }
      done==0 && /imports[[:space:]]*=/ && /\[/ {
        sub(/\[/, "[ ./app-configs-extra.nix"); done=1; print; next
      }
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

# The wiring must not have broken the NixOS-WSL configuration.
if (( IS_WSL == 1 )); then
  wsl_guard || fail "$SYS no longer looks like a NixOS-WSL configuration after wiring the module"
fi

rebuild_system

log "Done. Open a NEW terminal to land in fish."
log "Confirm: nixos-rebuild list-generations | head ; systemctl --failed"
