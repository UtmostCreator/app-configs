#!/usr/bin/env bash
# Read-only evidence from the installed session. Authentication and physical
# actions have separate acceptance entries in the installation runbook.
set -uo pipefail
export LC_ALL=C

case "${1:-}:$#" in
  :0|--online:1) ;;
  --help:1|-h:1) printf 'Usage: bash ops/niri/acceptance.sh [--online]\n'; exit 0 ;;
  *) printf 'Usage: bash ops/niri/acceptance.sh [--online]\n' >&2; exit 2 ;;
esac

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
revision=$(/run/booted-system/sw/bin/nixos-version --configuration-revision) || exit 2
if [[ ! $revision =~ ^[[:xdigit:]]{40}$ ]]; then
  printf 'FAIL  Booted system revision is unavailable\n' >&2
  exit 2
fi

required_status=0
probe() {
  local label=$1
  shift
  if timeout 6s "$@" >/dev/null 2>&1; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    required_status=1
  fi
}

printf 'Niri acceptance snapshot · %s\n' "$(date -u +%FT%TZ)"
printf 'Booted revision: %s\nBooted closure: %s\n' "$revision" "$(readlink -e /run/booted-system)"
printf 'Checkout revision: %s\n' "$(git -C "$repo" rev-parse HEAD)"
printf 'Checkout lock SHA-256: %s\n' "$(sha256sum <"$repo/nix/flake.lock" | cut -d' ' -f1)"
timeout 45s bash "$repo/ops/niri/verify-first-boot.sh" "$@" --current-profile "$revision" || required_status=1
if cmp -s "${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl" "$repo/nix/hosts/linux-niri/config.kdl"; then
  printf 'INFO  Deployed Niri config matches this checkout\n'
else
  printf 'INFO  Deployed Niri config differs from or is absent in this checkout\n'
fi

if [[ ${XDG_SESSION_TYPE:-} != wayland || ${XDG_CURRENT_DESKTOP:-} != niri || ! -S ${NIRI_SOCKET:-} ]]; then
  printf 'SKIP  Graphical probes require a terminal in Niri\n'
else
  probe 'Niri IPC responds' niri msg version
  if outputs=$(timeout 6s niri msg outputs 2>/dev/null); then
    printf 'INFO  Connected outputs: %s\n' "$(awk '/^Output / { count++ } END { print count+0 }' <<<"$outputs")"
  fi
  probe 'Niri keyboard layout list responds' niri msg keyboard-layouts
  for service in niri swayidle polkit-soteria vicinae pipewire wireplumber; do
    probe "Active user service: $service" systemctl --user is-active --quiet "$service.service"
  done
  if inhibitors=$(timeout 6s systemd-inhibit --list --no-pager 2>/dev/null) &&
    grep -qw swayidle <<<"$inhibitors"; then
    printf 'INFO  swayidle inhibitor listed\n'
  else
    printf 'WARN  No swayidle inhibitor observed\n'
  fi
  probe 'PipeWire has a default audio sink' wpctl get-volume @DEFAULT_AUDIO_SINK@
  if timeout 6s wpctl get-volume @DEFAULT_AUDIO_SOURCE@ >/dev/null 2>&1; then
    printf 'INFO  PipeWire has a default audio source\n'
  else
    printf 'WARN  No usable default audio source reported\n'
  fi
  for interface in FileChooser ScreenCast; do
    probe "Portal responds: $interface" busctl --user --auto-start=no get-property \
      org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop "org.freedesktop.portal.$interface" version
  done
  if names=$(timeout 6s busctl --user --acquired --no-legend --no-pager list 2>/dev/null); then
    for name in org.freedesktop.secrets org.freedesktop.Notifications org.kde.StatusNotifierWatcher; do
      state=$(awk -v name="$name" '$1 == name {found=1} END {print found ? "owned" : "unowned"}' <<<"$names")
      printf 'INFO  %s is %s\n' "$name" "$state"
    done
  else
    printf 'WARN  D-Bus owner list unavailable\n'
  fi
  for mime in x-scheme-handler/https x-scheme-handler/vscode application/pdf inode/directory x-scheme-handler/mailto; do
    value=$(timeout 6s xdg-mime query default "$mime" 2>/dev/null) || value=''
    printf 'INFO  MIME %s → %s\n' "$mime" "${value:-unset}"
  done
fi

for app in ghostty vicinae brave code keepassxc kopia php composer node pnpm python3 uv gh; do
  if command -v "$app" >/dev/null 2>&1; then
    printf 'INFO  Executable available: %s\n' "$app"
  else
    printf 'INFO  Executable absent from PATH: %s\n' "$app"
  fi
done

if ((required_status == 0)); then
  printf 'RESULT  Automated checks passed for the probes run. Physical acceptance is separate.\n'
else
  printf 'RESULT  Required automated checks failed or were unavailable.\n'
fi
exit "$required_status"
