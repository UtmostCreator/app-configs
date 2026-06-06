#!/usr/bin/env bash
# Detect the current system time zone (IANA name), e.g. "Europe/London".
#
# Single source of truth for the timedatectl parse used by install.sh,
# readiness.sh, and system-setup.sh. Prints "unknown" if it cannot be read
# (non-systemd host, timedatectl missing). Always exits 0 so callers can do
# `tz="$(bash ops/detect-timezone.sh)"` without tripping `set -e`.
#
# Usage:
#   bash ops/detect-timezone.sh        # -> Europe/London

set -uo pipefail

tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"

# Fallback for older systemd / when `show` is unavailable: parse `timedatectl`.
if [[ -z "$tz" ]]; then
  tz="$(timedatectl 2>/dev/null | awk -F': ' '/Time zone/ { print $2 }' | awk '{ print $1 }')"
fi

# Last-resort fallback: resolve /etc/localtime to a zoneinfo path.
if [[ -z "$tz" && -e /etc/localtime ]]; then
  link="$(readlink -f /etc/localtime 2>/dev/null || true)"
  tz="${link##*/zoneinfo/}"
  [[ "$tz" == "$link" ]] && tz=""   # no zoneinfo segment -> give up
fi

printf '%s\n' "${tz:-unknown}"
