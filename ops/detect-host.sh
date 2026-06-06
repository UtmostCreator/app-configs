#!/usr/bin/env bash
# Detect host profile: macos | linux-desktop | linux-cli | wsl
#
# Override the linux fallback with HOST_PROFILE_DEFAULT
# (default: linux-desktop). Override the whole answer with HOST_PROFILE.
#
# Usage:
#   bash ops/detect-host.sh
#   HOST_PROFILE_DEFAULT=linux-cli bash ops/detect-host.sh
#   HOST_PROFILE=wsl bash ops/detect-host.sh

set -euo pipefail

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
    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
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
