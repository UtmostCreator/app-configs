#!/usr/bin/env bash
# Select the Kingston and scan it read-only from an independent Linux boot.
set -euo pipefail
export LC_ALL=C

usage() { printf '%s\n' 'Usage: bash scan-kingston.sh [--list]' 'Reads the selected 960 GB Kingston and saves a log beside this script.'; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

case "$#:$*" in
  0:) list_only=false ;;
  1:--list) list_only=true ;;
  1:--help|1:-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

# The installer uses the same mount and holder checks before touching a disk.
disk_idle() {
  local listing node kind mounts holders
  listing=$(lsblk -nr -o KNAME,TYPE "$1") || return 1
  [[ -n $listing ]] || return 1
  while read -r node kind; do
    [[ $kind == disk || $kind == part ]] || return 1
    mounts=$(lsblk -dnro MOUNTPOINTS "/dev/$node") || return 1
    [[ -z $mounts && -d /sys/class/block/$node/holders ]] || return 1
    holders=$(ls -A -- "/sys/class/block/$node/holders") || return 1
    [[ -z $holders ]] || return 1
  done <<< "$listing"
}

disk_identity() {
  local disk=$1 seq details
  seq=$(cat "/sys/class/block/$(basename "$disk")/diskseq") || return 1
  details=$(lsblk -bdnro MAJ:MIN,SIZE "$disk") || return 1
  printf '%s:%s\n' "$details" "$seq"
}

directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
inventory=$(lsblk -dnrp -o NAME,TYPE) || die 'Could not list physical disks.'
disks=()
choices=()
printf 'Attached disks\n'
while read -r disk kind; do
  [[ $kind == disk && $disk != /dev/zram* ]] || continue
  model=$(lsblk -dno MODEL "$disk" | xargs)
  bytes=$(lsblk -bdnro SIZE "$disk")
  details=$(lsblk -dno SIZE,TRAN "$disk")
  if [[ $model == 'KINGSTON SEDC500M960G' && $bytes == 960197124096 ]]; then
    disks+=("$disk")
    identity=$(disk_identity "$disk") || die "Cannot identify $disk."
    choices+=("$identity")
    if disk_idle "$disk"; then state='available'; else state='in use'; fi
    printf '  %d) %s  %s  %s  [%s]\n' "${#disks[@]}" "$disk" "$model" "$details" "$state"
  else
    printf '   - %s  %s  %s  [outside this scan]\n' "$disk" "$model" "$details"
  fi
done <<< "$inventory"

$list_only && exit 0
(( ${#disks[@]} > 0 )) || die 'No matching Kingston was found.'
read -r -p 'Select the Kingston number (Enter cancels): ' choice || exit 0
[[ -n $choice ]] || exit 0
disk=''
for i in "${!disks[@]}"; do
  if [[ $choice == "$((i + 1))" ]]; then
    disk="${disks[i]}"
    identity="${choices[i]}"
    break
  fi
done
[[ -n $disk ]] || die 'That selection is unavailable.'
disk_idle "$disk" || die 'The selected Kingston is mounted or has active holders. Boot the live USB and leave it unused.'
[[ -w $directory ]] || die 'Mount KINGSTONKIT writable to save the scan log.'
for tool in sudo badblocks blockdev timeout tee; do
  command -v "$tool" >/dev/null || die "Required tool unavailable: $tool."
done
sudo -v || die 'Administrator access is required.'
if [[ $(disk_identity "$disk") != "$identity" ]] || ! disk_idle "$disk"; then
  die 'Disk identity or usage changed. Run the selector again.'
fi

transport=$(lsblk -dnro TRAN "$disk")
sector_size=$(sudo blockdev --getss "$disk")
[[ $sector_size =~ ^[0-9]+$ && $sector_size -gt 0 ]] || die 'Could not determine logical sector size.'
log=$(mktemp -- "$directory/kingston-scan-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX.log")
printf 'Saving results to %s\n' "$log"
scan() {
  printf 'Started %s, disk %s, transport %s, sector size %s bytes\n' "$(date -u +%FT%TZ)" "$disk" "$transport" "$sector_size"
  if command -v smartctl >/dev/null; then
    smart=(-x)
    [[ $transport != usb ]] || smart+=(-d sat)
    sudo timeout 30s smartctl "${smart[@]}" "$disk" || printf 'SMART returned a nonzero status. See the report above.\n'
  else
    printf 'smartctl unavailable. Continuing with the read-only sector scan.\n'
  fi
  if [[ $(disk_identity "$disk") != "$identity" ]] || ! disk_idle "$disk"; then
    printf 'Disk identity or usage changed before the scan.\n' >&2
    return 2
  fi
  local result=0
  sudo timeout --foreground 6h badblocks -b "$sector_size" -c 8192 -sv "$disk" || result=$?
  printf 'Sector scan exit status: %s\n' "$result"
  return "$result"
}
status=0
scan 2>&1 | tee -- "$log" || status=$?
timeout 20s sync -f "$log" || die 'Could not flush the scan log to the USB stick.'
exit "$status"
