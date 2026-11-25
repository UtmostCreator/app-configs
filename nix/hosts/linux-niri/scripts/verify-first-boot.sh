#!/usr/bin/env bash
# Read-only checks for the installed linux-niri system, as its normal user.
set -uo pipefail
export LC_ALL=C

usage() {
  echo 'Usage: verify-first-boot.sh [--json] [--online] EXPECTED_SYSTEM FULL_INSTALL_COMMIT'
  echo '       verify-first-boot.sh [--json] [--online] --current-profile FULL_INSTALL_COMMIT'
  echo '       verify-first-boot.sh [--json] --storage-only'
}
json=false
online=false
while (( $# > 0 )); do
  case $1 in
    --help|-h) usage; exit 0 ;;
    --online) online=true; shift ;;
    --json) json=true; shift ;;
    *) break ;;
  esac
done
store_system='^/nix/store/[a-z0-9]+-nixos-system-linux-niri-[a-zA-Z0-9._-]+$'
storage_only=false
if [[ $# == 1 && $1 == --storage-only ]]; then
  storage_only=true
elif [[ $# != 2 || ( $1 != --current-profile && ! $1 =~ $store_system ) || ! $2 =~ ^[[:xdigit:]]{40}$ ]]; then
  usage >&2
  exit 2
fi
if [[ $EUID == 0 || ! -r /etc/app-configs/linux-niri || -e /etc/app-configs/linux-niri-toplevel ]]; then
  echo 'Run as the normal user on the installed linux-niri system.' >&2
  exit 2
fi
if $json && ! command -v jq >/dev/null; then
  echo 'JSON output requires jq.' >&2
  exit 2
fi

failures=0
records=()
record() {
  local status=$1 required=$2 label=$3
  if [[ $required == true && ( $status == FAIL || $status == UNKNOWN ) ]]; then
    failures=$((failures + 1))
  fi
  if $json; then
    records+=( "$status"$'\t'"$required"$'\t'"$label" )
  else
    printf '%s  %s\n' "$status" "$label"
  fi
}
check() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    record PASS true "$label"
  else
    record FAIL true "$label"
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

root_health() {
  local mount_info fstype options devno extra device errors
  if ! mount_info=$(findmnt -nro FSTYPE,OPTIONS,MAJ:MIN -M / 2>/dev/null) ||
     [[ $mount_info == *$'\n'* ]]; then
    record UNKNOWN true 'Cannot identify the root mount'
    return 1
  fi
  read -r fstype options devno extra <<< "$mount_info"
  if [[ -z $fstype || -z $options || ! $devno =~ ^[0-9]+:[0-9]+$ || -n $extra ]]; then
    record UNKNOWN true 'Incomplete root mount information'
    return 1
  fi
  if [[ $fstype != ext4 ]]; then
    record FAIL true 'Expected an EXT4 root'
    return 1
  fi
  case ",$options," in
    *,emergency_ro,*) record FAIL true 'EXT4 root is emergency read-only'; return 1 ;;
    *,ro,*) record FAIL true 'EXT4 root is read-only'; return 1 ;;
    *,rw,*) record PASS true 'EXT4 root mount reports read-write' ;;
    *) record UNKNOWN true 'Cannot determine root mount access mode'; return 1 ;;
  esac

  # Follow the mounted device number. A second EXT4 volume can have a
  # different counter, even when its filesystem label matches the root.
  if ! device=$(readlink -e "/sys/dev/block/$devno") ||
     ! errors=$(cat "/sys/fs/ext4/${device##*/}/errors_count" 2>/dev/null) ||
     [[ ! $errors =~ ^[0-9]+$ ]]; then
    record UNKNOWN true 'Root EXT4 error count unavailable'
    return 1
  fi
  if [[ ! $errors =~ ^0+$ ]]; then
    record FAIL true "Root EXT4 recorded errors: $errors"
    return 1
  fi
  record PASS true 'Root EXT4 recorded errors: 0'
}

backing_disk() {
  local source
  source=$(findmnt -nro SOURCE -M "$1") || return 1
  lsblk -snrpo NAME,TYPE "$source" | awk '$2 == "disk" {print $1}'
}

protected_receipt_path() {
  local owner mode
  read -r owner mode < <(stat -c '%u %a' "$1" 2>/dev/null) || return 1
  [[ $owner == 0 && $mode =~ ^[0-7]{3,4}$ ]] && (( (8#$mode & 0022) == 0 ))
}

check_disk_receipt() {
  local directory=/var/lib/app-configs receipt=/var/lib/app-configs/install-disk-id link
  local -a ids=()
  if [[ -e $directory || -L $directory ]]; then
    if [[ -L $directory || ! -d $directory || ! -x $directory ]] || ! protected_receipt_path "$directory"; then
      record UNKNOWN true 'Cannot inspect the installation disk identity receipt'
      return
    fi
  fi
  if [[ ! -e $receipt && ! -L $receipt ]]; then
    record UNKNOWN false 'Installation has no recorded disk identity'
    return
  fi
  if [[ ! -f $receipt || ! -r $receipt || -L $receipt ]] || ! protected_receipt_path "$receipt" ||
     ! mapfile -t ids < "$receipt" ||
     [[ ${#ids[@]} != 1 || ! ${ids[0]} =~ ^[a-zA-Z0-9][a-zA-Z0-9_.:+-]*$ || ${ids[0]} =~ -part[0-9]+$ ]] ||
     ! cmp -s "$receipt" <(printf '%s\n' "${ids[0]}"); then
    record FAIL true 'Installation disk identity receipt is invalid'
    return
  fi
  link=/dev/disk/by-id/${ids[0]}
  if [[ -L $link && -n $root_disk && $(readlink -e "$link" 2>/dev/null) == "$root_disk" ]]; then
    record PASS true 'Boot disk matches the recorded persistent identity'
  else
    record FAIL true 'Boot disk identity changed or unavailable; review the installation receipt'
  fi
}

finish() {
  if (( failures )); then
    result='Required checks failed or unavailable'
  else
    result='Required checks passed'
  fi
  if $json; then
    printf '%s\n' "${records[@]}" | jq -Rn --arg result "$result" '
      [inputs | split("\t") | {status: .[0], required: (.[1] == "true"), check: .[2]}]
      | {result: $result, checks: .}' || exit 1
  else
    printf 'RESULT  %s\n' "$result"
  fi
  exit "$((failures != 0))"
}

check 'Root uses the installed LUKS mapper' mount_matches / /dev/mapper/linux-niri-root
check 'Root mapper is an encrypted device' test "$(lsblk -dnro TYPE /dev/mapper/linux-niri-root 2>/dev/null)" = crypt
root_health
check 'EFI partition mounted at /boot' test "$(findmnt -nro FSTYPE -M /boot 2>/dev/null)" = vfat
check 'ESP uses the installation partition label' mount_matches /boot /dev/disk/by-partlabel/linux-niri-esp
root_disk=$(backing_disk / 2>/dev/null) || root_disk=''
esp_disk=$(backing_disk /boot 2>/dev/null) || esp_disk=''
if [[ -n $root_disk && $root_disk != *$'\n'* && $root_disk == "$esp_disk" ]]; then
  record PASS true 'Root and ESP use the same physical disk'
else
  record FAIL true 'Root and ESP use the same physical disk'
fi
check_disk_receipt
if $storage_only; then finish; fi

# Resolve only siblings under a registered base generation. A stand-alone store
# path with the right basename is insufficient to identify the booted system.
booted=$(readlink -e /run/booted-system 2>/dev/null) || booted=''
variant=''
matches_base() {
  local base=$1 child resolved
  [[ $base =~ $store_system && -n $booted ]] || return 1
  if [[ $base == "$booted" ]]; then return 0; fi
  for child in "$base"/specialisation/*; do
    [[ -L $child ]] || continue
    resolved=$(readlink -e "$child") || continue
    if [[ $resolved == "$booted" ]]; then
      variant=${child##*/}
      return 0
    fi
  done
  return 1
}

if [[ $1 == --current-profile ]]; then
  found=false
  for link in /nix/var/nix/profiles/system-[0-9]*-link; do
    [[ ${link##*/} =~ ^system-[0-9]+-link$ && -L $link ]] || continue
    [[ $(stat -c %u "$link" 2>/dev/null) == 0 ]] || continue
    base=$(readlink -e "$link" 2>/dev/null) || continue
    if matches_base "$base"; then found=true; break; fi
  done
  check 'Booted a registered linux-niri generation or its specialisation' "$found"
elif matches_base "$1" && [[ -z $variant || $variant == nvidia-open ]]; then
  if [[ $variant == nvidia-open ]]; then
    record PASS true 'Booted the recorded NVIDIA specialisation'
  else
    record PASS true 'Booted the recorded generation'
  fi
else
  record FAIL true 'Booted the recorded generation'
fi

active=$(readlink -e /run/current-system 2>/dev/null) || active=''
if [[ -n $booted && $active == "$booted" ]]; then
  record PASS true 'Active system matches the booted generation'
elif [[ $1 == --current-profile && $active =~ $store_system ]]; then
  record WARN false 'Active system differs from booted generation; review any live switch'
else
  record FAIL true 'Active system does not match the booted generation'
fi

available=$(df --output=avail -k / 2>/dev/null | awk 'END {print $1}')
if [[ $available =~ ^[0-9]+$ ]]; then
  if [[ $available =~ ^0+$ ]]; then
    record FAIL true 'Root filesystem has no available space'
  else
    record INFO false "Available root space: $available KiB"
  fi
else
  record UNKNOWN true 'Available root space could not be measured'
fi

repo="$HOME/Projects/app-configs"
export GIT_NO_LAZY_FETCH=1 GIT_NO_REPLACE_OBJECTS=1
if [[ $(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) != "$repo" ]]; then
  record FAIL true 'Expected checkout is unavailable'
elif [[ $(git -C "$repo" rev-parse HEAD 2>/dev/null) == "$2" ]]; then
  record PASS true 'Checkout uses the recorded commit'
elif [[ $1 == --current-profile ]] && git -C "$repo" merge-base --is-ancestor "$2" HEAD >/dev/null 2>&1; then
  record INFO true 'Checkout advanced from the recorded install commit'
# The author-metadata rewrite replaced this deployed commit with the same Git
# tree (545b99037e19a0872f0165401a82c1d16f23d530). Keep exact handoff strict.
elif [[ $1 == --current-profile && $2 == 26f3bbdc116a474d175d2d8c2ff09145cf64e889 ]] &&
     git -C "$repo" merge-base --is-ancestor 000f889360c327bb65615cee3948f250141ba8b2 HEAD >/dev/null 2>&1; then
  record INFO true 'Checkout includes the verified replacement for the install commit'
else
  record FAIL true 'Checkout uses the recorded commit'
fi

# Status can normally refresh the index or invoke a configured filesystem monitor.
# Suppress both during the automatic read-only check.
if ! changes=$(GIT_OPTIONAL_LOCKS=0 git -C "$repo" -c core.fsmonitor=false -c core.hooksPath=/dev/null status --porcelain --untracked-files=normal 2>/dev/null); then
  record UNKNOWN true 'Checkout worktree state unavailable'
elif [[ -z $changes ]]; then
  record PASS true 'Checkout worktree is clean'
elif [[ $1 == --current-profile ]]; then
  record WARN false 'Checkout contains local changes'
else
  record FAIL true 'Checkout contains local changes'
fi

failed_units() {
  local label=$1 units
  shift
  if ! units=$(timeout 5 systemctl "$@" list-units --state=failed --no-legend --no-pager --plain 2>/dev/null); then
    record UNKNOWN true "Could not query failed $label units"
  elif [[ -n $units ]]; then
    record FAIL true "Failed $label units present"
  else
    record PASS true "No failed $label units"
  fi
}

# systemd first-login jobs can execute during startup. Avoid waiting on the
# same user target which is waiting for this job.
state=$(timeout 5 systemctl is-system-running 2>/dev/null)
case $state in
  running) record PASS true 'System manager is running' ;;
  initializing|starting) record UNKNOWN true 'System manager is starting; retry after boot' ;;
  degraded|maintenance|stopping|offline) record FAIL true 'System manager is not running normally' ;;
  *) record UNKNOWN true 'System manager state unavailable' ;;
esac
failed_units system
failed_units user --user
check 'NetworkManager service' timeout 5 systemctl is-active --quiet NetworkManager.service
niri_config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
if [[ $niri_config == /* && -f $niri_config && -r $niri_config ]]; then
  check 'Installed Niri configuration parses' timeout 8 niri validate -c "$niri_config"
else
  record FAIL true 'Installed Niri configuration unavailable'
fi
check 'Claude CLI version available' timeout 12 claude --version
check 'Codex CLI version available' timeout 12 codex --version
for folder in Projects Documents Downloads Pictures Pictures/Screenshots Scratch/{temp,logs,benchmarks,reports,screenshots} Archive/{projects,snapshots,imports}; do
  if [[ -d $HOME/$folder && -O $HOME/$folder && ! -L $HOME/$folder ]]; then
    record PASS true "$folder is an owned directory"
  else
    record FAIL true "$folder is an owned directory"
  fi
done
for folder in Scratch Archive; do
  check "$folder is a private directory" test "$(stat -c '%F:%a:%u' "$HOME/$folder" 2>/dev/null)" = "directory:700:$EUID"
done

missing_tools=()
for tool in ip ping nmcli nmtui curl getent findmnt lsblk smartctl nvme cryptsetup e2fsck lspci lsusb journalctl systemctl jq rfkill; do
  type -P "$tool" >/dev/null || missing_tools+=("$tool")
done
if (( ${#missing_tools[@]} )); then
  for tool in "${missing_tools[@]}"; do
    record WARN false "Diagnostic command unavailable: $tool"
  done
else
  record PASS false 'Diagnostic commands available on PATH'
fi

if [[ $variant == nvidia-open ]]; then
  check 'Selected NVIDIA driver responds' timeout 8 nvidia-smi --query-gpu=driver_version --format=csv,noheader
else
  record SKIP false 'NVIDIA probe applies to the NVIDIA specialisation'
fi
if [[ -n ${NIRI_SOCKET:-} ]]; then
  check 'Niri session responds to output query' timeout 5 niri msg outputs
else
  record SKIP false 'Niri output query requires the graphical session'
fi

if devices=$(timeout 5 nmcli -t -f TYPE,STATE device status 2>/dev/null); then
  if awk -F: '$1 != "loopback" && $2 ~ /^connected( |$)/ {found=1} END {exit !found}' <<< "$devices"; then
    record PASS false 'NetworkManager reports a connected interface'
  else
    record SKIP false 'No connected NetworkManager interface'
  fi
else
  record UNKNOWN false 'NetworkManager interface state unavailable'
fi

if ! route4=$(timeout 3 ip -4 route show default 2>/dev/null) ||
   ! route6=$(timeout 3 ip -6 route show default 2>/dev/null); then
  record UNKNOWN false 'Default route query unavailable'
elif [[ -z $route4 && -z $route6 ]]; then
  record SKIP false 'Offline; no default route'
elif ! $online; then
  record PASS false 'Default route present'
  record SKIP false 'External DNS and HTTPS probes available with --online'
else
  record PASS false 'Default route present'
  if timeout 5 getent ahosts cache.nixos.org >/dev/null 2>&1; then
    record PASS false 'Nix cache DNS lookup'
    if timeout 8 curl --disable --fail --silent --output /dev/null --max-time 6 https://cache.nixos.org/nix-cache-info; then
      record PASS false 'Nix cache HTTPS request'
    else
      record WARN false 'Nix cache HTTPS request unavailable'
    fi
  else
    record WARN false 'Nix cache DNS lookup unavailable'
    record SKIP false 'HTTPS probe requires DNS'
  fi
fi
record SKIP false 'For kernel storage errors inspect sudo journalctl -k -b'
record SKIP false 'For archived and active journal integrity run sudo journalctl --verify'
record SKIP false 'Inspect SMART using sudo smartctl -x on the verified installation disk'
if [[ -d /var/log/app-configs ]]; then
  record INFO false 'Inspect private installation logs with sudo ls -lt /var/log/app-configs'
else
  record WARN false 'Private installation log directory unavailable'
fi

finish
