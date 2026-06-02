#!/usr/bin/env bash
# detect-os-disks.sh — read-only NVMe/SSD + OS detector for dual-boot setup.
#
# Scans block devices live and reports, per physical disk:
#   - whether it holds a Windows install (EFI System part + Microsoft reserved
#     / NTFS), a Linux install (Linux-fs root + EFI System), or neither
#   - which disk the CURRENTLY RUNNING OS booted from (marked [current])
#   - the partition layout that justifies each verdict
#
# It then PRINTS a suggested `myConfig.dualBoot` snippet for the
# nix/modules/nixos/dual-boot.nix module. It is purely advisory.
#
# SAFETY: read-only. It never writes config, never runs efibootmgr/bootctl
# install, never mounts or modifies any partition. It only reads lsblk/findmnt.
#
# Usage:
#   bash scripts/detect-os-disks.sh             # human report + suggestion
#   AI_OUTPUT=json bash scripts/detect-os-disks.sh   # machine-readable JSON
#
# Exit 0 = scan completed. Exit 1 = required tool missing.

set -uo pipefail

AI_OUTPUT="${AI_OUTPUT:-plain}"

have() { command -v "$1" >/dev/null 2>&1; }

for t in lsblk jq; do
  if ! have "$t"; then
    printf 'error: required tool missing: %s\n' "$t" >&2
    exit 1
  fi
done

# Disk that backs "/" of the running OS -> its parent physical disk.
# findmnt gives the source device; strip partition suffix to get the disk.
current_root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
current_disk=""
if [[ -n "$current_root_src" ]]; then
  # Resolve through device-mapper / by-uuid symlinks to a real node.
  real="$(readlink -f "$current_root_src" 2>/dev/null || echo "$current_root_src")"
  base="$(basename "$real")"
  # nvme0n1p2 -> nvme0n1 ; sda2 -> sda
  if [[ "$base" =~ ^(nvme[0-9]+n[0-9]+)p[0-9]+$ ]]; then
    current_disk="${BASH_REMATCH[1]}"
  elif [[ "$base" =~ ^([a-z]+)[0-9]+$ ]]; then
    current_disk="${BASH_REMATCH[1]}"
  fi
fi

# Single lsblk JSON snapshot drives the whole analysis.
lsblk_json="$(lsblk -J -o NAME,SIZE,TYPE,FSTYPE,PARTTYPENAME,PARTLABEL,MOUNTPOINT,UUID 2>/dev/null)"

# Per-disk classification done in jq so plain + json modes share one source.
#   windows  : has an "EFI System" part AND (a "Microsoft reserved" part OR an ntfs fs)
#   linux    : has an "EFI System" part AND a linux filesystem (ext*/btrfs/xfs/f2fs)
#   esp_only : has an EFI System part but no clear OS markers
#   data     : no EFI System part
analysis="$(printf '%s' "$lsblk_json" | jq --arg cur "$current_disk" '
  def is_linux_fs($f): ($f != null) and ($f | test("^(ext[234]|btrfs|xfs|f2fs)$"));
  [ .blockdevices[]
    | select(.type == "disk")
    | . as $d
    | ($d.children // []) as $parts
    | {
        name: $d.name,
        size: $d.size,
        current: ($d.name == $cur),
        has_esp:    ($parts | any(.parttypename == "EFI System")),
        has_msr:    ($parts | any(.parttypename == "Microsoft reserved")),
        has_ntfs:   ($parts | any(.fstype == "ntfs")),
        has_linux:  ($parts | any(is_linux_fs(.fstype))),
        has_swap:   ($parts | any(.fstype == "swap")),
        esp:        [ $parts[] | select(.parttypename == "EFI System")
                       | {name, size, uuid, mountpoint} ],
        parts:      [ $parts[] | {name, size, fstype, parttypename, mountpoint} ]
      }
    | .os = (
        if (.has_esp and (.has_msr or .has_ntfs)) then "windows"
        elif (.has_esp and .has_linux) then "linux"
        elif .has_esp then "esp-only"
        else "data" end)
  ]
')"

# Derive the suggestion inputs.
#   - linux disk == the one running NixOS (current + linux), else first linux disk
#   - windows on separate disk if a windows disk exists that is NOT the linux disk
linux_disk="$(printf '%s' "$analysis" | jq -r '
  ([.[] | select(.os=="linux" and .current)] | .[0].name)
  // ([.[] | select(.os=="linux")] | .[0].name) // ""')"
windows_disk="$(printf '%s' "$analysis" | jq -r '[.[] | select(.os=="windows")] | .[0].name // ""')"
windows_separate="false"
if [[ -n "$windows_disk" && "$windows_disk" != "$linux_disk" ]]; then
  windows_separate="true"
fi
# Linux ESP free-space-ish hint: small (<300M) suggests xbootldr if shared.
linux_esp_size="$(printf '%s' "$analysis" | jq -r --arg d "$linux_disk" '
  (.[] | select(.name==$d) | .esp[0].size) // ""')"

if [[ "$AI_OUTPUT" == "json" ]]; then
  printf '%s' "$analysis" | jq \
    --arg current "$current_disk" \
    --arg linux_disk "$linux_disk" \
    --arg windows_disk "$windows_disk" \
    --argjson windows_separate "$windows_separate" \
    '{
      schema: "detect-os-disks/v1",
      current_disk: $current,
      linux_disk: $linux_disk,
      windows_disk: $windows_disk,
      windows_on_separate_disk: $windows_separate,
      disks: .
    }'
  exit 0
fi

# ---- human-readable report ----
printf '== Disk / OS scan (read-only) ==\n\n'
printf '%s' "$analysis" | jq -r '
  .[] |
  "Disk \(.name)  (\(.size))\(if .current then "   [current OS booted here]" else "" end)\n" +
  "  verdict: \(.os | ascii_upcase)\n" +
  ( [ .parts[]
      | "    - \(.name)  \(.size)  \(.fstype // "—")  \(.parttypename // "")\(if .mountpoint then "  mounted:\(.mountpoint)" else "" end)" ]
    | join("\n") ) + "\n"
'

printf '\n== Summary ==\n'
printf '  Current OS disk : %s\n' "${current_disk:-unknown}"
printf '  Linux (NixOS)   : %s\n' "${linux_disk:-none detected}"
printf '  Windows         : %s\n' "${windows_disk:-none detected}"
printf '  Windows layout  : %s\n' \
  "$([[ "$windows_separate" == "true" ]] && echo "separate disk from Linux" || echo "same disk / none")"

printf '\n== Suggested nix/modules/nixos/dual-boot.nix config ==\n'
printf '  (advisory only — review before applying to /etc/nixos)\n\n'
if [[ -z "$windows_disk" ]]; then
  cat <<'EOF'
  # No Windows install detected. Dual-boot is optional; you can leave the
  # module disabled, or enable it for a clean single-OS systemd-boot menu:
  myConfig.dualBoot.enable = true;
EOF
elif [[ "$windows_separate" == "true" ]]; then
  cat <<EOF
  # Windows is on a SEPARATE disk ($windows_disk) from Linux ($linux_disk).
  # systemd-boot cannot load it directly; enable the EDK2-shell chainload path,
  # then discover windowsDeviceHandle (see module docs: reboot into the
  # "EDK2 UEFI Shell" menu entry and run \`map -c\`).
  myConfig.dualBoot = {
    enable = true;
    windowsOnSeparateDisk = true;
    # windowsDeviceHandle = "HD0c1";  # REQUIRED: discover via \`map -c\`
  };
EOF
else
  cat <<EOF
  # Windows shares Linux's disk/ESP — systemd-boot auto-detects it.
  myConfig.dualBoot.enable = true;
EOF
  case "$linux_esp_size" in
    *M)
      n="${linux_esp_size%M}"; n="${n%.*}"
      if [[ "$n" =~ ^[0-9]+$ && "$n" -lt 300 ]]; then
        printf '  # NOTE: Linux ESP is small (%s). If sharing it with Windows is\n' "$linux_esp_size"
        printf '  # tight, consider an XBOOTLDR partition (see module xbootldrMountPoint).\n'
      fi
      ;;
  esac
fi
printf '\n  Reminder: this script changes nothing. Apply config yourself via\n'
# Backticks below are literal text shown to the user, not command substitution.
# shellcheck disable=SC2016
printf '  /etc/nixos + `nixos-rebuild`, and set UEFI boot order with efibootmgr.\n'
