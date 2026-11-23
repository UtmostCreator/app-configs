#!/usr/bin/env bash
# Read-only checks for the installed laptop. Run as its normal user.
set -uo pipefail

usage() {
  echo 'Usage: bash ops/niri/verify-first-boot.sh EXPECTED_SYSTEM FULL_INSTALL_COMMIT'
}
if [[ ${1:-} == --help ]]; then usage; exit 0; fi
if [[ $# != 2 || $1 != /nix/store/*-nixos-system-linux-niri-* || ! $2 =~ ^[[:xdigit:]]{40}$ ]]; then
  usage >&2
  exit 2
fi
if [[ $EUID == 0 || ! -r /etc/app-configs/linux-niri || -e /etc/app-configs/linux-niri-toplevel ]]; then
  echo 'Run from the normal account on the booted Kingston.' >&2
  exit 2
fi

failures=0
check() {
  local label=$1
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label" >&2
    failures=$((failures + 1))
  fi
}
# Invoked by check, which records failures and continues with the remaining checks.
# shellcheck disable=SC2329
mount_matches() {
  local actual expected
  actual=$(findmnt -nro MAJ:MIN -M "$1") || return 1
  expected=$(lsblk -dnro MAJ:MIN "$2") || return 1
  [[ -n $expected && $actual == "$expected" ]]
}

# A clone of the disk may carry the same labels. Compare the actual backing disks.
# shellcheck disable=SC2329
same_disk() {
  local root_dev esp_dev root_disk esp_disk
  root_dev=$(findmnt -nro SOURCE -M /) || return 1
  esp_dev=$(findmnt -nro SOURCE -M /boot) || return 1
  root_disk=$(lsblk -snrpo NAME,TYPE "$root_dev" | awk '$2 == "disk" {print $1}') || return 1
  esp_disk=$(lsblk -snrpo NAME,TYPE "$esp_dev" | awk '$2 == "disk" {print $1}') || return 1
  [[ -n $root_disk && $root_disk != *$'\n'* && $esp_disk == "$root_disk" ]]
}

repo="$HOME/Projects/app-configs"
check 'Booted the recorded generation' test "$(readlink -f /run/booted-system)" = "$1"
check 'Root uses the installed LUKS mapper' mount_matches / /dev/mapper/linux-niri-root
check 'EFI partition mounted at /boot' test "$(findmnt -nro FSTYPE -M /boot)" = vfat
check 'ESP uses the installation partition label' mount_matches /boot /dev/disk/by-partlabel/linux-niri-esp
check 'Root and ESP use the same physical disk' same_disk
check 'Checkout uses the recorded commit' test "$(git -C "$repo" rev-parse HEAD)" = "$2"
check 'NetworkManager service' systemctl is-active --quiet NetworkManager.service
check 'Installed Niri configuration parses' niri validate
check 'Claude starts' claude --version
check 'Codex starts' codex --version
for folder in Projects Documents Downloads Pictures/Screenshots Scratch/{temp,logs,benchmarks,reports,screenshots} Archive/{projects,snapshots,imports}; do
  check "$folder exists" test -d "$HOME/$folder"
done
for folder in Scratch Archive; do
  check "$folder is a private directory" test "$(stat -c '%F:%a' "$HOME/$folder")" = 'directory:700'
done
exit "$((failures != 0))"
