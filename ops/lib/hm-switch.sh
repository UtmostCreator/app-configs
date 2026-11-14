#!/usr/bin/env bash
# shellcheck shell=bash
# The one way this repo switches Home Manager. Sourced by update-all.sh,
# install.sh, bootstrap.sh and the codebase-memory-mcp updater, so they cannot
# drift apart again (only update-all.sh used to check for profile conflicts,
# and several callers lacked -b).
#
#   hm_check_conflicts FLAKE_DIR PROFILE   0 clean, 1 conflicts, 2 cannot check
#   hm_switch_raw FLAKE_DIR PROFILE        the switch itself (-b hm-bak)
#   hm_switch FLAKE_DIR PROFILE            check, then switch
#   hm_switch_describe FLAKE_DIR PROFILE   the command line, for dry-run output
#
# FLAKE_DIR is the directory holding flake.nix (a "path:" prefix is fine).
#
# After a failed check, HM_CHECK_MSG holds a one-line reason and HM_CHECK_FIX
# the command that resolves it. HM_CONFLICTS holds "<element>\t<file>" lines.

# shellcheck source=ops/lib/profile-conflicts.sh
source "${BASH_SOURCE[0]%/*}/profile-conflicts.sh"

HM_CHECK_MSG=""
HM_CHECK_FIX=""
HM_CONFLICTS=()
HM_BACKUP_EXT="hm-bak"

hm_switch_describe() {
  printf 'home-manager switch -b %s --flake %s#%s\n' "$HM_BACKUP_EXT" "$1" "$2"
}

# A missing manifest (or no way to run jq) is an error here, not "no conflicts": the plain
# profile_hm_conflicts treats missing input as empty, which would let a broken
# check pass as a clean one. The one legitimate empty case is a host without
# any nix profile, which cannot hold hand-installed packages.
hm_check_conflicts() {
  local flake_dir="$1" profile="$2"
  local manifest="${HM_PROFILE_MANIFEST:-$HOME/.nix-profile/manifest.json}"
  HM_CHECK_MSG=""; HM_CHECK_FIX=""; HM_CONFLICTS=()

  if [[ ! -e "$manifest" && ! -e "$(dirname "$manifest")" ]]; then
    return 0
  fi
  # A fresh bootstrap has a nix profile but often no jq yet. Installing jq into
  # the profile would itself collide with Home Manager, so borrow it from nixpkgs.
  if ! command -v jq >/dev/null 2>&1; then
    if command -v nix >/dev/null 2>&1; then
      jq() { nix run nixpkgs#jq -- "$@"; }
    else
      HM_CHECK_MSG="cannot check nix-profile conflicts: neither jq nor nix is on PATH"
      HM_CHECK_FIX="put nix on PATH (source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh)"
      return 2
    fi
  fi
  if [[ ! -f "$manifest" ]]; then
    HM_CHECK_MSG="cannot check nix-profile conflicts: $manifest is missing"
    HM_CHECK_FIX="nix profile list"
    return 2
  fi

  local out
  out="$(nix build --no-link --print-out-paths "$flake_dir#homeConfigurations.$profile.activationPackage" 2>/dev/null | tail -n1)"
  if [[ -z "$out" || ! -d "$out/home-path" ]]; then
    HM_CHECK_MSG="cannot check nix-profile conflicts: could not build the $profile activation package"
    HM_CHECK_FIX="nix build --no-link $flake_dir#homeConfigurations.$profile.activationPackage"
    return 2
  fi

  mapfile -t HM_CONFLICTS < <(profile_hm_conflicts "$manifest" "$out/home-path")
  if ((${#HM_CONFLICTS[@]})); then
    local pkgs
    pkgs="$(printf '%s\n' "${HM_CONFLICTS[@]}" | cut -f1 | sort -u | paste -sd' ' -)"
    HM_CHECK_MSG="hand-installed nix-profile package(s) collide with Home Manager: ${HM_CONFLICTS[*]//$'\t'/ ships }"
    HM_CHECK_FIX="nix profile remove $pkgs   (Home Manager now provides it), then re-run"
    return 1
  fi
  return 0
}

# -b: a file Home Manager would clobber is moved to <file>.<ext> instead of
# failing the switch. Home Manager aborts when that backup already exists, so
# the failure message names the way out.
hm_switch_raw() {
  local flake_dir="$1" profile="$2" rc=0
  home-manager switch -b "$HM_BACKUP_EXT" --flake "$flake_dir#$profile" || rc=$?
  if ((rc == 0)); then
    return 0
  fi
  printf >&2 '%s\n' \
    "home-manager switch failed. If it reports that a *.$HM_BACKUP_EXT file already exists," \
    "Home Manager refuses to overwrite that earlier backup: move or delete it and re-run."
  return "$rc"
}

hm_switch() {
  local status=0
  hm_check_conflicts "$1" "$2" || status=$?
  if ((status)); then
    printf >&2 '%s\n  Fix: %s\n' "$HM_CHECK_MSG" "$HM_CHECK_FIX"
    return 1
  fi
  hm_switch_raw "$1" "$2"
}
