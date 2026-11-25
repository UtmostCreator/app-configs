#!/usr/bin/env bash
# Invoked by the four commands in maintenance.nix, as the installed user.
set -euo pipefail

usage() {
  cat <<'HELP'
sys-install [--dry-run]           Build linux-niri and its integrated home
sys-readiness [SYSTEM REVISION]   Verify the booted profile or install receipt
sys-update                        Show current system generation and checkout
sys-update --apply                Stage the clean checkout for the next boot
sys-update rollback GENERATION    Select that generation once at next boot
sys-cleanup [--apply]             Report or clean caches, retaining generations
HELP
}

die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

# The active system may be a child of the system profile. Match closures so
# the same command works with either base graphics or any named specialisation.
variant_of() {
  local base=$1 running=$2 item
  if [[ $base == "$running" ]]; then printf '\n'; return; fi
  for item in "$base"/specialisation/*; do
    if [[ -L $item && $(readlink -e "$item") == "$running" ]]; then
      basename "$item"
      return
    fi
  done
  return 1
}

variant_system() {
  local base=$1 variant=$2 dir
  dir=$(readlink -e "${base}${variant:+/specialisation/$variant}") && [[ -x $dir/init ]] || return 1
  printf '%s\n' "$dir"
}

# The pinned systemd-boot builder embeds the generation in the BLS version
# and the closure in the init option. A display title can span generations.
entry_id() {
  local target=$1 generation=$2
  jq -er --arg init "init=$target/init" --arg generation "Generation $generation " '
    [.[] | select(
      (.id // "" | test("^nixos-[a-zA-Z0-9._-]+\\.conf$")) and
      (.version // "" | startswith($generation)) and
      (.options // "" | split(" ") | index($init) != null)
    ) | .id] | if length == 1 then .[0] else error("no unique matching NixOS boot entry") end'
}

entries() { sudo bootctl --esp-path=/boot --json=short list; }

clean_revision() {
  local changes
  changes=$(git -C "$1" status --porcelain --untracked-files=normal) || return 1
  [[ -z $changes ]] || { printf 'Review and commit checkout changes before staging.\n' >&2; return 1; }
  git -C "$1" rev-parse --verify HEAD
}

stage_update() {
  local repo=$1 base=$2 variant=$3 running=$4 generation=$5 profile=$6
  local revision flake path expected target old_id new_id current new_gen manifest failure_message
  local staged
  staged=$(readlink -e "$profile")
  revision=$(clean_revision "$repo") || return 1
  app-configs-verify-first-boot --storage-only || die 'Storage verification failed.'
  path=$(jq -nr --arg path "$repo" '$path | split("/") | map(@uri) | join("/")')
  flake="git+file://$path?dir=nix&rev=$revision"
  expected=$(nix build --no-update-lock-file --max-jobs 1 --cores 2 --no-link --print-out-paths \
    "$flake#nixosConfigurations.linux-niri.config.system.build.toplevel")
  target=$(variant_system "$expected" "$variant") || die 'Candidate lacks the booted specialisation or init.'
  if [[ $staged != "$base" && $staged != "$expected" ]]; then
    die 'A different system is already staged. Inspect bootctl list before updating.'
  fi
  if [[ $staged == "$base" && $expected == "$base" ]]; then
    echo 'PASS  This revision already builds the installed system.'
    return
  fi
  # Recheck after the potentially long build, before any privileged operation.
  app-configs-verify-first-boot --storage-only || die 'Storage verification failed.'
  [[ $(readlink -e "$profile") == "$staged" ]] || die 'System profile changed during build.'
  manifest=$(entries)
  old_id=$(entry_id "$running" "$generation" <<< "$manifest")
  jq -e --arg id "$old_id" 'any(.[]; .id == $id and .isSelected)' <<< "$manifest" >/dev/null ||
    die 'Cannot confirm the selected boot entry.'
  failure_message='Staging incomplete. Inspect bootctl list, then retry the same revision.'
  if [[ $staged == "$base" ]]; then
    jq -e --arg id "$old_id" 'any(.[]; .id == $id and .isDefault)' <<< "$manifest" >/dev/null ||
      die 'Selected and default boot entries differ. Review bootctl list first.'
    # Pin the working entry before changing the system profile or loader.conf.
    sudo bootctl --esp-path=/boot set-default "$old_id" || die 'Could not preserve the working boot entry.'
    printf 'INFO  Rollback entry: %s (generation %s)\n' "$old_id" "$generation"
    nixos-rebuild boot --sudo --max-jobs 1 --cores 2 --no-update-lock-file --flake "$flake#linux-niri" ||
      die "$failure_message"
  fi
  current=$(readlink -e "$profile")
  [[ $current == "$expected" ]] || die 'The staged system differs from the reviewed build.'
  new_gen=$(generation_number "$profile")
  manifest=$(entries)
  new_id=$(entry_id "$target" "$new_gen" <<< "$manifest") || die "$failure_message"
  # Only resume the exact requested build, while either the old entry or the
  # requested one is default. Preserve deliberate boot choices by the operator.
  jq -e --arg old "$old_id" --arg next "$new_id" '
    any(.[]; .id == $old and .isSelected) and
    any(.[]; (.id == $old or .id == $next) and .isDefault)
  ' <<< "$manifest" >/dev/null || die 'The boot selection changed. Review bootctl list.'
  sudo bootctl --esp-path=/boot set-default "$new_id" || die "$failure_message"
  entries | jq -e --arg id "$new_id" 'any(.[]; .id == $id and .isDefault)' >/dev/null ||
    die 'Could not verify the EFI default. Review bootctl list before rebooting.'
  printf 'PASS  Staged generation %s (%s), commit %s\n' "$new_gen" "${variant:-base}" "$revision"
  printf '      Reboot when ready. Recovery: sys-update rollback %s\n' "$generation"
}

generation_number() {
  local link
  link=$(readlink "$1") || return 1
  [[ ${link##*/} =~ ^system-([0-9]+)-link$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

main() {
  local cmd=$1 repo="$HOME/Projects/app-configs" profile=/nix/var/nix/profiles/system
  local generation base running variant target id revision parent lock_fd
  shift
  case ${1:-} in -h|--help) usage; return;; esac
  [[ $EUID != 0 && -r /etc/app-configs/linux-niri && ! -e /etc/app-configs/linux-niri-toplevel ]] ||
    die 'Run as the normal user on the installed linux-niri system.'
  case "$cmd:$#:${1:-}" in
    install:0:|install:1:--dry-run) exec bash "$repo/ops/install.sh" --host linux-niri "$@" ;;
    cleanup:0:|cleanup:1:--apply) exec bash "$repo/ops/cleanup.sh" "$@" ;;
    readiness:0:)
      revision=$(/run/booted-system/sw/bin/nixos-version --configuration-revision)
      exec app-configs-verify-first-boot --current-profile "$revision" ;;
    readiness:2:*) exec app-configs-verify-first-boot "$@" ;;
    update:0:|update:1:--apply|update:2:rollback) ;;
    *) usage >&2; return 2 ;;
  esac
  generation=$(generation_number "$profile") || die 'Cannot identify the system profile generation.'
  base=$(readlink -e "$profile")
  running=$(readlink -e /run/booted-system)
  if [[ $# == 0 ]]; then
    printf 'Booted system: %s\nSystem profile (generation %s): %s\n' "$running" "$generation" "$base"
    git -C "$repo" status --short --branch
    return
  fi
  [[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR && -O $XDG_RUNTIME_DIR ]] ||
    die 'Run from a normal logged-in user session.'
  exec {lock_fd}>>"$XDG_RUNTIME_DIR/app-configs-maintenance.lock"
  flock -n "$lock_fd" || die 'Another Niri maintenance command is active.'
  # A staged profile or a one-shot rollback may differ from the booted one.
  # Resolve the origin of the working closure from retained system generations.
  if ! variant=$(variant_of "$base" "$running"); then
    base=''
    for parent in "$profile"-*-link; do
      [[ -L $parent ]] || continue
      if variant=$(variant_of "$(readlink -e "$parent")" "$running"); then
        base=$(readlink -e "$parent")
        [[ ${parent##*/} =~ ^system-([0-9]+)-link$ ]] || die 'Invalid system generation link.'
        generation=${BASH_REMATCH[1]}
        break
      fi
    done
    [[ -n $base ]] || die 'Cannot identify the booted generation and variant.'
  fi
  if [[ $1 == rollback ]]; then
    [[ $2 =~ ^[1-9][0-9]*$ && -L $profile-$2-link ]] || die 'Choose an existing numeric generation.'
    app-configs-verify-first-boot --storage-only || die 'Storage verification failed.'
    target=$(variant_system "$profile-$2-link" "$variant") || die 'That generation lacks the booted variant.'
    id=$(entries | entry_id "$target" "$2") || die 'Cannot resolve that rollback entry.'
    sudo bootctl --esp-path=/boot set-oneshot "$id"
    printf 'PASS  Generation %s (%s) selected for the next boot only.\n' "$2" "${variant:-base}"
    return
  fi
  stage_update "$repo" "$base" "$variant" "$running" "$generation" "$profile"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
