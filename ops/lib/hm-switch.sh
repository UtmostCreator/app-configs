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
#   hm_attr PROFILE                        the flake output for a host profile
#   hm_switch_describe FLAKE_DIR PROFILE   the command line, for dry-run output
#
# PROFILE is the host profile; hm_switch and hm_switch_describe map it to the
# flake output with hm_attr (wsl on NixOS is wsl-nixos). hm_check_conflicts and
# hm_switch_raw take the attribute as given.
#
# FLAKE_DIR is the directory holding flake.nix (a "path:" prefix is fine).
#
# After a failed check, HM_CHECK_MSG holds the reason (a header line, then one
# line per colliding package with its file count) and HM_CHECK_FIX the command
# that resolves it. HM_CONFLICTS holds "<element>\t<file>" lines.
#
# The one exemption: a profile element named exactly "home-manager". Home Manager
# ships bin/home-manager itself (programs.home-manager.enable in
# nix/lib/mkhome.nix, for every profile), and the install docs and older ops/install.sh runs put it
# into the nix profile as a bootstrap tool, so it always collides on the first
# switch. hm_switch removes that element (after resolving the binary it still
# needs) and any other collision still stops, fail closed. install.sh no longer
# installs it; with no home-manager on PATH the switch runs it through
# `nix run nixpkgs#home-manager`.

# shellcheck source=ops/lib/profile-conflicts.sh
source "${BASH_SOURCE[0]%/*}/profile-conflicts.sh"
# shellcheck source=ops/lib/selection.sh
source "${BASH_SOURCE[0]%/*}/selection.sh"
# shellcheck source=ops/lib/wait-feedback.sh
source "${BASH_SOURCE[0]%/*}/wait-feedback.sh"

HM_CHECK_MSG=""
HM_CHECK_FIX=""
HM_CONFLICTS=()
HM_BACKUP_EXT="hm-bak"

# The flake output for a host profile: the ONE fail-closed resolver every build,
# check and switch site uses (update-all, bootstrap, hm_switch, the selection
# facts, audit; the fish `hms` function asks detect-host.sh --hm-attr directly).
# ops/detect-host.sh owns the mapping (--hm-attr; HOST_PROFILE=<profile> pins the
# profile, and wsl on NixOS is wsl-nixos). Prints the attribute and returns 0.
# If detect-host cannot answer, for ANY profile, it prints a message on stderr and
# returns 1: there is no fallback to the plain profile name. Callers that change
# something stop; read-only callers report "unknown".
hm_attr() {
  local profile="$1" attr
  if attr="$(HOST_PROFILE="$profile" bash "${BASH_SOURCE[0]%/*}/../detect-host.sh" --hm-attr 2>/dev/null)" && [[ -n "$attr" ]]; then
    printf '%s\n' "$attr"
    return 0
  fi
  printf >&2 '%s\n' "cannot choose the Home Manager output for host profile '$profile': ops/detect-host.sh --hm-attr failed or gave no answer"
  return 1
}

hm_switch_describe() {
  selection_args
  local attr
  # Display only: with no answer it names no attribute (#<unknown>) and fails;
  # hm_switch itself stops before any build or switch.
  attr="$(hm_attr "$2")" || {
    printf 'home-manager switch -b %s --flake %s#<unknown>%s\n' "$HM_BACKUP_EXT" "$1" "$(selection_args_text)"
    return 1
  }
  printf 'home-manager switch -b %s --flake %s#%s%s\n' "$HM_BACKUP_EXT" "$1" "$attr" "$(selection_args_text)"
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

  # An invalid local selection fails this build, before anything is activated.
  local out
  selection_args
  out="$(nix build --no-link --print-out-paths "$flake_dir#homeConfigurations.$profile.activationPackage" ${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"} 2>/dev/null | tail -n1)"
  if [[ -z "$out" || ! -d "$out/home-path" ]]; then
    HM_CHECK_MSG="cannot check nix-profile conflicts: could not build the $profile activation package"
    HM_CHECK_FIX="nix build --no-link $flake_dir#homeConfigurations.$profile.activationPackage$(selection_args_text)"
    return 2
  fi

  mapfile -t HM_CONFLICTS < <(profile_hm_conflicts "$manifest" "$out/home-path")
  if ((${#HM_CONFLICTS[@]})); then
    local pkgs
    pkgs="$(printf '%s\n' "${HM_CONFLICTS[@]}" | cut -f1 | sort -u | paste -sd' ' -)"
    # One line per package: "  <package>: <n> file(s), first <file>".
    HM_CHECK_MSG="hand-installed nix-profile package(s) collide with Home Manager:"$'\n'"$(printf '%s\n' "${HM_CONFLICTS[@]}" \
      | awk -F'\t' '{ n[$1]++; if (!($1 in first)) { first[$1] = $2; order[++k] = $1 } } END { for (i = 1; i <= k; i++) printf "  %s: %d file(s), first %s\n", order[i], n[order[i]], first[order[i]] }')"
    HM_CHECK_FIX="nix profile remove $pkgs   (Home Manager now provides it), then re-run"
    return 1
  fi
  return 0
}

# -b: a file Home Manager would clobber is moved to <file>.<ext> instead of
# failing the switch. Home Manager aborts when that backup already exists, so
# the failure message names the way out.
hm_switch_raw() {
  local flake_dir="$1" profile="$2" rc=0 hm
  selection_args
  # HM_BIN: a binary hm_switch resolved before removing the profile element that
  # provided it. No home-manager at all (a fresh machine): run it from nixpkgs.
  if [[ -n "${HM_BIN:-}" ]]; then
    hm=("$HM_BIN")
  elif command -v home-manager >/dev/null 2>&1; then
    hm=(home-manager)
  else
    hm=(nix run nixpkgs#home-manager --)
  fi
  "${hm[@]}" switch -b "$HM_BACKUP_EXT" --flake "$flake_dir#$profile" ${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"} || rc=$?
  if ((rc == 0)); then
    return 0
  fi
  printf >&2 '%s\n' \
    "home-manager switch failed. If it reports that a *.$HM_BACKUP_EXT file already exists," \
    "Home Manager refuses to overwrite that earlier backup: move or delete it and re-run."
  return "$rc"
}

# True when every colliding element is the bootstrap "home-manager" (see the
# header). HM_CONFLICTS must be non-empty.
_hm_only_bootstrap_conflicts() {
  local c
  for c in "${HM_CONFLICTS[@]}"; do
    [[ "${c%%$'\t'*}" == home-manager ]] || return 1
  done
  return 0
}

hm_switch() {
  local status=0 attr
  attr="$(hm_attr "$2")" || return 1
  # The check builds the whole activation package: minutes on a first run.
  wait_run "checking nix-profile conflicts (builds the Home Manager configuration)" \
    "1-10 minutes on a first install, seconds when cached" hm_check_conflicts "$1" "$attr" || status=$?
  if ((status == 1)) && _hm_only_bootstrap_conflicts; then
    # Only the bootstrap home-manager collides: Home Manager provides it from now
    # on. Keep the binary (its store path stays valid) for this switch, then drop
    # the element so the switch can install home-manager-path.
    local hm_path
    hm_path="$(command -v home-manager 2>/dev/null || true)"
    if [[ -n "$hm_path" ]] && hm_path="$(readlink -f "$hm_path")" && [[ -x "$hm_path" ]]; then
      HM_BIN="$hm_path"
    fi
    printf >&2 '%s\n' "[hm-switch] the profile's home-manager collides with the one Home Manager now provides; removing it first (nix profile remove home-manager)"
    nix profile remove home-manager || {
      printf >&2 '%s\n  Fix: nix profile remove home-manager, then re-run\n' "could not remove the bootstrap home-manager from the nix profile"
      return 1
    }
    status=0
  fi
  if ((status)); then
    printf >&2 '%s\n  Fix: %s\n' "$HM_CHECK_MSG" "$HM_CHECK_FIX"
    return 1
  fi
  wait_run "Home Manager switch (builds and activates; its progress is shown below)" \
    "2-15 minutes on a first install, under a minute when nothing changed" hm_switch_raw "$1" "$attr"
}
