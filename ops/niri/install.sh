#!/usr/bin/env bash
# Install the reviewed linux-niri generation from the project live USB.
# Fresh external USB target only. Root/ESP inspection and rescue use the runbook.
usage() {
  printf '%s\n' 'Usage: bash ops/niri/install.sh [--scan]' \
    '       bash ops/niri/install.sh --install --target BY_ID --revision FULL_SHA --system STORE_PATH'
}

message() {
  printf '%s  %s\n' "$1" "$2"
  printf '%s elapsed=%ss stage=%s %s %s\n' "$(date -u +%FT%TZ)" "$SECONDS" "$phase" "$1" "$2" >> "$log"
}

stage() {
  phase=$1
  stage_events+=( "$(date -u +%FT%TZ) elapsed=${SECONDS}s stage=$phase started" )
  message INFO "[$1] $2"
  if [[ ${target_mounted:-false} == true ]]; then save_log; fi
}

# Call only for noninteractive, non-secret commands. Preserve both exits even
# when errexit is active or a logger fails after the child succeeds.
run_logged() {
  local label=$1
  shift
  local -a result
  local summary_rc=0
  if [[ -n ${persisted_log:-} ]]; then
    verify_mounts || return 1
    if "$@" 2>&1 | tee -a "$log" | sudo -n tee -a -- "$persisted_log" >/dev/null; then
      result=( "${PIPESTATUS[@]}" )
    else
      result=( "${PIPESTATUS[@]}" )
    fi
  elif "$@" 2>&1 | tee -a "$log" >/dev/null; then
    result=( "${PIPESTATUS[@]}" )
  else
    result=( "${PIPESTATUS[@]}" )
  fi
  message INFO "$label command_exit=${result[0]} logger_exit=${result[1]} target_logger_exit=${result[2]:-unused}" ||
    { summary_rc=1; printf 'FAIL  Could not save step status to the live log.\n' >&2; }
  if (( result[0] != 0 )); then return "${result[0]}"; fi
  if (( result[1] != 0 )); then return "${result[1]}"; fi
  if (( ${result[2]:-0} != 0 )); then return "${result[2]}"; fi
  return "$summary_rc"
}

save_log() {
  verify_mounts || return 1
  if [[ -z $persisted_log ]]; then
    sudo -n install -d -m 0700 /mnt/var/log/app-configs || return 1
    persisted_log=$(sudo -n mktemp /mnt/var/log/app-configs/install-XXXXXXXX.log) || return 1
  fi
  local snapshot
  snapshot=$(sudo -n mktemp /mnt/var/log/app-configs/.checkpoint-XXXXXXXX) || return 1
  sudo -n install -m 0600 -- "$log" "$snapshot" &&
    sudo -n mv -fT -- "$snapshot" "$persisted_log"
}

fail() {
  local status=$1 reason=$2
  trap - ERR INT TERM
  set +e
  message FAIL "$reason (exit $status)" >&2
  message INFO "Disk preparation: $preparation. System copy: $copy_state. First boot: unverified." >&2
  if [[ $preparation != unstarted ]]; then
    message ACTION 'Inspect the existing target from the live USB. Never repeat formatting for recovery.' >&2
  fi
  if [[ $target_mounted == true ]]; then
    if save_log; then printf 'Target log: %s\n' "$persisted_log" >&2
    else printf 'WARN  Could not persist the log to the verified target.\n' >&2; fi
  fi
  printf 'Private live log: %s (export before powering off).\n' "$log" >&2
  exit "$status"
}

require() {
  local reason=$1
  shift
  "$@" || fail 1 "$reason"
}

media_disk() {
  local source node
  source=$(findmnt -rn -M /iso -t iso9660 -o SOURCE) || return 1
  [[ -b "$source" ]] || return 1
  node=$(lsblk -snrpo NAME,TYPE "$source" | awk '$2 == "disk" {print $1}') || return 1
  [[ -b "$node" ]] || return 1
  printf '%s\n' "$node"
}

preflight() {
  require 'expected x86_64' test "$(uname -m)" = x86_64
  require 'boot the installer in 64-bit UEFI mode' test "$(cat /sys/firmware/efi/fw_platform_size)" = 64
  installer=$(media_disk)
  revision=$(cat /iso/APP-CONFIGS-REVISION)
  system=$(cat /etc/app-configs/linux-niri-toplevel)
  [[ "$revision" =~ ^[a-f0-9]{40}$ && "$system" =~ ^/nix/store/[a-z0-9]+-nixos-system-linux-niri-[a-zA-Z0-9._-]+$ ]]
  require 'recorded system closure is missing' test -x "$system/bin/switch-to-configuration"
  require 'live bundle does not match the revision marker' test \
    "$(git bundle list-heads /iso/app-configs.bundle refs/heads/main)" = "$revision refs/heads/main"
  printf 'revision=%s\nsystem=%s\ninstaller=%s\n' "$revision" "$system" "$installer" >> "$log"
  printf 'NixOS Installer · linux-niri\nx86_64 · UEFI · %s\n' "${system##*-linux-niri-}"
  message PASS 'System and live media verified.'
}

inventory() {
  lsblk -e7 -o NAME,TYPE,SIZE,MODEL,TRAN,FSTYPE,MOUNTPOINTS
  printf 'Use the physical label and a whole-disk link in /dev/disk/by-id/.\n'
}

disk_identity() {
  local resolved
  resolved=$(readlink -e "$target") || return 1
  [[ -b "$resolved" ]] || return 1
  lsblk -bdnro MAJ:MIN,SIZE,TYPE,TRAN,RO,SERIAL,WWN "$resolved"
}

disk_idle() {
  local listing node kind holders mounted
  listing=$(lsblk -nr -o KNAME,TYPE "$1") || return 1
  while read -r node kind; do
    [[ "$kind" == disk || "$kind" == part ]] || return 1
    holders=$(ls -A "/sys/class/block/$node/holders") || return 1
    mounted=$(lsblk -dnro MOUNTPOINTS "/dev/$node") || return 1
    [[ -z "$holders" && -z "$mounted" ]] || return 1
  done <<< "$listing"
}

select_disk() {
  local wwn serial
  [[ "$target" =~ ^/dev/disk/by-id/[a-zA-Z0-9_.:+-]+$ && ! "$target" =~ -part[0-9]+$ && -L $target ]] ||
    fail 1 'target must be a persistent whole-disk by-id link'
  disk=$(readlink -e "$target")
  require 'the live installer cannot be selected' test "$disk" != "$installer"
  [[ $(lsblk -dnro TYPE "$disk") == disk && $(lsblk -dnro TRAN "$disk") == usb && $(lsblk -dnro RO "$disk") == 0 ]] ||
    fail 1 'only a writable external USB disk is supported'
  wwn=$(lsblk -dnro WWN "$disk")
  serial=$(lsblk -dnro SERIAL "$disk")
  [[ "$wwn" =~ ^0x[[:xdigit:]]{6,}$ || "$serial" =~ ^[[:alnum:]_.-]{5,}$ ]] ||
    fail 1 'target lacks a stable WWN or serial'
  selected_identity=$(disk_identity)
  [[ -n $selected_identity ]]
  printf 'target=%s identity=%s\n' "$target" "$selected_identity" >> "$log"
}

blank_target() {
  local types signatures
  types=$(lsblk -nr -o TYPE "$disk") || return 1
  [[ $types == disk ]] || return 1
  signatures=$(sudo -n wipefs --noheadings --output TYPE -- "$target") || return 1
  [[ -z $signatures ]]
}

guard_isolation() {
  local disks allowed current_media active_swap swap
  current_media=$(media_disk) || return 1
  [[ "$current_media" == "$installer" ]] || return 1
  [[ "$(readlink -e "$target")" == "$disk" ]] || return 1
  [[ "$(disk_identity)" == "$selected_identity" ]] || return 1
  disks=$(lsblk -dnrpo NAME,TYPE |
    awk '$2 == "disk" && $1 !~ /^\/dev\/zram[0-9]+$/ {print $1}' | sort) || return 1
  allowed=$(printf '%s\n' "$disk" "$installer" | sort) || return 1
  [[ "$disks" == "$allowed" ]] || return 1
  active_swap=$(swapon --noheadings --raw --show=NAME) || return 1
  while IFS= read -r swap; do
    [[ -z $swap || $swap =~ ^/dev/zram[0-9]+$ ]] || return 1
  done <<< "$active_swap"
}

guard_fresh_target() {
  local mounts contents
  guard_isolation || return 1
  disk_idle "$disk" || return 1
  blank_target || return 1
  [[ ! -L /mnt && ! -e /dev/mapper/linux-niri-root &&
     ! -e /dev/disk/by-partlabel/linux-niri-esp && ! -e /dev/disk/by-partlabel/linux-niri-luks ]] || return 1
  mounts=$(findmnt -rn -o TARGET) || return 1
  if grep -Eq '^/mnt(/|$)' <<< "$mounts"; then return 1; fi
  if [[ -e /mnt ]]; then
    [[ -d /mnt ]] || return 1
    contents=$(ls -A /mnt) || return 1
    [[ -z $contents ]] || return 1
  fi
}

validate_deployment() {
  local checkout=$scratch/checkout flake preview
  git clone -q -b main /iso/app-configs.bundle "$checkout" >> "$log" 2>&1
  test "$(git -C "$checkout" rev-parse HEAD)" = "$revision"
  test -f "$checkout/ops/niri/verify-first-boot.sh"
  account=$(timeout 60 nix eval --offline --raw -f "$checkout/nix/vars/default.nix" username 2>> "$log")
  [[ "$account" =~ ^[a-z_][a-z0-9_-]*$ && "$account" != root ]]
  flake="git+file://$checkout?dir=nix&rev=$revision"
  preview=$(timeout 600 nix run --max-jobs 1 --cores 2 --no-update-lock-file "$flake#disko" -- \
    --dry-run --mode format,mount --flake "$flake#linux-niri" --argstr targetDisk "$target" 2>> "$log")
  printf '%s\n' "$preview" >> "$log"
  prepare=${preview##*$'\n'}
  [[ "$prepare" == /nix/store/*-disko-format-mount/bin/disko-format-mount && -x "$prepare" ]]
  bash -n "$prepare"
  grep -Fxq "  device=$target" "$prepare"
}

explain_credentials() {
  printf '%s\n' \
    'Choose two different secrets before continuing.' \
    '  LUKS passphrase: unlocks the encrypted SSD before NixOS starts.' \
    '  Login password: signs in to NixOS after unlock and authorizes sudo.' \
    'Save both in a password manager you can open on another device.' \
    'Choose a long LUKS passphrase you can type at the boot screen.' \
    'Enter each secret only when its password prompt appears.'
}

confirm_erase() {
  local answer
  require 'isolate all other drives and ensure the target is idle and fresh' guard_fresh_target
  explain_credentials
  message WARN 'Disko will partition and format the selected blank disk.'
  printf '%s · %s\n' "$(lsblk -dno MODEL "$disk")" "$(lsblk -dno SIZE "$disk")"
  printf '%s · serial %s · WWN %s\n' "$disk" "$(lsblk -dno SERIAL "$disk")" "$(lsblk -dno WWN "$disk")"
  printf 'Compare deployment %s with your reviewed record.\n' "${revision:0:12}"
  printf 'Target: %s\n' "$target"
  read -r -p 'To erase, retype the entire displayed by-id path (Enter cancels): ' answer ||
    fail 2 'operator cancelled'
  [[ $answer == "$target" ]] || fail 2 'operator cancelled or target did not match'
}

prepare_disk() {
  require 'disk identity, signatures, mounts or isolation changed' guard_fresh_target
  preparation='attempted; changes unknown'

  message INFO 'Enter and repeat the LUKS passphrase that unlocks the SSD at boot.'
  # Keep all interactive Disko output, including prompts, outside the log.
  local disko_status=0
  sudo -n timeout --foreground 15m bash -c 'exec 9>/dev/null; export BASH_XTRACEFD=9; exec bash "$1"' bash "$prepare" || disko_status=$?
  message INFO "Disko command_exit=$disko_status"
  if (( disko_status != 0 )); then
    message WARN 'Disko stopped before the login-password stage.'
    message INFO 'Use lsblk -f to see whether the root partition shows crypto_LUKS.'
    fail "$disko_status" 'disk preparation did not complete'
  fi
  require 'root and EFI mounts do not trace to the target SSD' verify_mounts
  preparation=verified
  target_mounted=true
  save_log
}

verify_mounts() {
  local mount expected source actual path fstype options
  for mount in /mnt /mnt/boot; do
    case "$mount" in
      /mnt) expected=/dev/mapper/linux-niri-root; fstype=ext4 ;;
      /mnt/boot) expected=/dev/disk/by-partlabel/linux-niri-esp; fstype=vfat ;;
    esac
    [[ "$(findmnt -nro FSTYPE -M "$mount")" == "$fstype" ]] || return 1
    options=$(findmnt -nro OPTIONS -M "$mount") || return 1
    [[ ,$options, == *,rw,* && ,$options, != *,ro,* && ,$options, != *,emergency_ro,* ]] || return 1
    source=$(findmnt -nro SOURCE -M "$mount") || return 1
    actual=$(readlink -e "$expected") || return 1
    [[ "$(readlink -e "$source")" == "$actual" ]] || return 1
    path=$(lsblk -snrpo NAME,TYPE "$actual" | awk '$2 == "disk" {print $1}') || return 1
    [[ "$path" == "$disk" && "$(disk_identity)" == "$selected_identity" ]] || return 1
  done
}

install_system() {
  require 'disk isolation changed before system installation' guard_isolation
  message INFO "Copying NixOS. Details: $log"
  require 'target mount identity or health changed' verify_mounts
  copy_state=attempted
  run_logged system-copy sudo -n timeout --foreground 90m nixos-install \
    --no-root-passwd --no-channel-copy --root /mnt --system "$system"
  copy_state=completed
  message PASS 'System copy completed.'
  save_log
}

configure_account() {
  message INFO "Set the login password for $account. Use it to sign in or run sudo."
  local password_rc=0
  sudo -n timeout --foreground 15m nixos-enter --root /mnt -c "passwd $account" || password_rc=$?
  message INFO "Account enrolment command_exit=$password_rc"
  (( password_rc == 0 )) || fail "$password_rc" 'account enrolment failed'
  sudo -n nixos-enter --root /mnt -c "passwd -S $account" | awk '$2 == "P" { valid=1 } END { exit !valid }'
  sudo -n install -d -m 0755 /mnt/var/lib/app-configs
  sudo -n install -m 0644 /iso/app-configs.bundle /mnt/var/lib/app-configs/install.bundle
  printf '%s\n' "$revision" | sudo -n tee /mnt/var/lib/app-configs/install-revision >/dev/null
  sudo -n install -m 0644 /dev/stdin /mnt/var/lib/app-configs/seed-home.sh <<'SEED'
set -euo pipefail
test "$(id -u)" -ne 0
[[ "$HOME" = /* && "$HOME" != / && -d "$HOME" && ! -L "$HOME" ]]
cd "$HOME"
folders=(Projects Documents Downloads Pictures Pictures/Screenshots Scratch Scratch/{temp,logs,benchmarks,reports,screenshots} Archive Archive/{projects,snapshots,imports})
for dir in "${folders[@]}"; do
  test ! -L "$dir"
  [[ ! -e "$dir" || -d "$dir" ]]
done
test ! -e Projects/app-configs && test ! -L Projects/app-configs
for dir in "${folders[@]}"; do
  [[ -d "$dir" ]] || mkdir -m 0700 -- "$dir"
done
git clone -b main /var/lib/app-configs/install.bundle Projects/app-configs
git -C Projects/app-configs remote set-url origin https://github.com/UtmostCreator/app-configs.git
SEED
  run_logged seed-home sudo -n timeout --foreground 10m nixos-enter --root /mnt \
    -c "su - $account -c 'bash /var/lib/app-configs/seed-home.sh'"
  sudo -n unlink /mnt/var/lib/app-configs/seed-home.sh
}

verify_installation() {
  local installed checkout installed_revision wwn stable_id
  require 'disk isolation changed before verification' guard_isolation
  require 'root and EFI mounts do not trace to the target SSD' verify_mounts
  installed=$(sudo -n nixos-enter --root /mnt -c 'readlink -f /nix/var/nix/profiles/system')
  require 'installed system profile mismatch' test "$installed" = "$system"
  require 'portable EFI fallback missing' sudo -n test -s /mnt/boot/EFI/BOOT/BOOTX64.EFI
  checkout=$(sudo -n nixos-enter --root /mnt -c "su - $account -c 'git -C ~/Projects/app-configs rev-parse HEAD'")
  require 'installed checkout mismatch' test "$checkout" = "$revision"
  installed_revision=$(sudo -n cat /mnt/var/lib/app-configs/install-revision)
  require 'installed deployment record mismatch' test "$installed_revision" = "$revision"
  # Prefer a drive WWN that resolves to the verified disk across transports.
  stable_id=${target##*/}
  wwn=$(lsblk -dnro WWN "$disk")
  if [[ $wwn =~ ^0x[[:xdigit:]]+$ && $(readlink -e "/dev/disk/by-id/wwn-$wwn") == "$disk" ]]; then
    stable_id="wwn-$wwn"
  fi
  printf '%s\n' "$stable_id" | sudo -n install -m 0644 /dev/stdin /mnt/var/lib/app-configs/install-disk-id
  printf '%s\n' "$system" | sudo -n install -m 0644 /dev/stdin /mnt/var/lib/app-configs/install-system
  message PASS 'System profile, EFI fallback, account and repository verified.'
  stage_events+=( "$(date -u +%FT%TZ) elapsed=${SECONDS}s stage=07/08 verified" )
  stage 08/08 'Flush and release target'
  # Only the live system can observe the final unmount and mapper closure.
  printf '%s\n' "${stage_events[@]}" |
    sudo -n install -m 0644 /dev/stdin /mnt/var/lib/app-configs/install-stages
  sudo -n sync -f /mnt/boot
  sudo -n sync -f /mnt
  sudo -n umount /mnt/boot
  sudo -n umount /mnt
  target_mounted=false
  sudo -n cryptsetup close linux-niri-root
}

main() {
  set -Eeuo pipefail
  export LC_ALL=C
  umask 077
  local -a stage_events=()
  local mode=scan mode_arg='' expected_revision='' expected_system=''
  local target='' disk='' installer='' revision='' system='' account='' prepare='' selected_identity=''
  local scratch log phase=01/08 preparation=unstarted copy_state=unstarted target_mounted=false persisted_log=''
  while (( $# )); do
    case "$1" in
      --install|--scan)
        [[ -z $mode_arg ]] || { usage >&2; return 2; }
        mode_arg=$1; mode=${1#--} ;;
      --target|--revision|--system)
        (( $# >= 2 )) && [[ -n $2 && $2 != --* ]] || { usage >&2; return 2; }
        case "$1" in
          --target) target=$2 ;; --revision) expected_revision=$2 ;; --system) expected_system=$2 ;;
        esac
        shift ;;
      --help|-h) usage; return 0 ;;
      *) usage >&2; return 2 ;;
    esac
    shift
  done
  if [[ $mode == install ]]; then
    [[ -n $target && $expected_revision =~ ^[0-9a-f]{40}$ && $expected_system == /nix/store/* ]] ||
      { usage >&2; return 2; }
    [[ -t 0 && $EUID != 0 ]] || { echo 'Install from the interactive console as the ordinary live user.' >&2; return 2; }
  elif [[ -n $target || -n $expected_revision || -n $expected_system ]]; then
    usage >&2; return 2
  fi

  if [[ ${IN_DISKO_TEST+x} || ${DETECT_OS_DISKS_CURRENT_DISK+x} || ${DETECT_OS_DISKS_LSBLK_JSON+x} ]]; then
    echo 'Fixture overrides are forbidden in the live installer.' >&2
    return 2
  fi
  scratch=$(mktemp -d /tmp/niri-install.XXXXXXXX)
  log=$scratch/install.log
  : > "$log"
  printf 'Private live log: %s\n' "$log"
  trap 'fail "$?" "command failed at line $LINENO"' ERR
  trap 'fail 130 "interrupted by Ctrl+C"' INT
  trap 'fail 143 "terminated"' TERM
  stage 01/08 'System preflight'
  preflight
  stage 02/08 'Disk selection'
  inventory
  if [[ $mode == scan ]]; then
    message PASS 'Scan complete.'
    trap - ERR INT TERM
    return
  fi
  require 'reviewed revision mismatch' test "$expected_revision" = "$revision"
  require 'reviewed system path mismatch' test "$expected_system" = "$system"
  exec 8>"/run/user/$(id -u)/niri-disk-install.lock"
  require 'another installer holds the lock' flock -n 8
  select_disk
  sudo -v
  require 'expected only the installer and an idle blank USB target' guard_fresh_target
  stage 03/08 'Deployment verification'
  validate_deployment
  stage 04/08 'Destructive confirmation'
  confirm_erase
  stage 05/08 'Disk preparation'
  prepare_disk
  stage 06/08 'System installation'
  install_system
  stage 07/08 'Account and bootloader verification'
  require 'target changed before account enrolment' verify_mounts
  configure_account
  verify_installation
  message PASS 'Target unmounted and encryption mapping closed.'
  printf 'Installed log: %s\n' "${persisted_log#/mnt}"
  printf 'Run sudo poweroff, remove the installer and boot the SSD to verify first login.\n'
  trap - ERR INT TERM
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
