#!/usr/bin/env bash
# Detect host profile: macos | linux-desktop | linux-cli | wsl (= WSL2)
#
# Override the linux fallback with HOST_PROFILE_DEFAULT
# (default: linux-desktop). Override the whole answer with HOST_PROFILE.
#
# Usage:
#   bash ops/detect-host.sh
#   HOST_PROFILE_DEFAULT=linux-cli bash ops/detect-host.sh
#   HOST_PROFILE=wsl bash ops/detect-host.sh

set -euo pipefail

proc_version="${DETECT_HOST_PROC_VERSION:-/proc/version}"

usage() {
  cat <<'USAGE'
Usage: bash ops/detect-host.sh [--wsl-version | -h | --help]
Prints macos | linux-desktop | linux-cli | wsl. See the header for overrides.
USAGE
}
case "$#:${1:-}" in
  0:) ;;
  1:--wsl-version) ;;
  1:-h | 1:--help) usage; exit 0 ;;
  *) printf 'detect-host: unknown argument(s): %s\n' "$*" >&2; usage >&2; exit 2 ;;
esac

# --wsl-version: print 2 (WSL2), 1 (WSL1) or none. The repo supports WSL2
# only: WSL1 has no real Linux kernel or systemd, so Nix and the Home Manager
# user timers do not work there. WSL2 kernels say "microsoft-standard" (and
# usually "WSL2"); WSL1 reports a fake 4.4.0-*-Microsoft kernel.
if [[ "${1:-}" == --wsl-version ]]; then
  if grep -qiE 'microsoft-standard|wsl2' "$proc_version" 2>/dev/null; then
    echo 2
  elif grep -qiE 'microsoft|wsl' "$proc_version" 2>/dev/null; then
    echo 1
  else
    echo none
  fi
  exit 0
fi

if [[ -n "${HOST_PROFILE:-}" ]]; then
  case "$HOST_PROFILE" in
    macos|linux-desktop|linux-cli|wsl)
      echo "$HOST_PROFILE"
      exit 0
      ;;
    *)
      echo "unsupported HOST_PROFILE: $HOST_PROFILE" >&2
      exit 1
      ;;
  esac
fi

case "$(uname -s)" in
  Darwin)
    echo macos
    ;;
  Linux)
    # DETECT_HOST_PROC_VERSION: test override for the kernel version file.
    if grep -qiE 'microsoft|wsl' "$proc_version" 2>/dev/null; then
      echo wsl
    else
      echo "${HOST_PROFILE_DEFAULT:-linux-desktop}"
    fi
    ;;
  *)
    echo unsupported >&2
    exit 1
    ;;
esac
