#!/usr/bin/env bash
# Detect host profile: macos | linux-desktop | linux-cli | wsl (= WSL2)
#
# Prints the profile on stdout and exits 0. On any failure (unsupported OS,
# unreadable kernel info, WSL1, ambiguous WSL kernel, bad input) prints a
# diagnostic on stderr, prints nothing on stdout and exits non-zero.
#
# Override the linux fallback with HOST_PROFILE_DEFAULT (linux-desktop or
# linux-cli; default linux-desktop). Override the whole answer with
# HOST_PROFILE.
#
# Usage:
#   bash ops/detect-host.sh
#   bash ops/detect-host.sh --wsl-version     # prints 2, 1 or none
#   HOST_PROFILE_DEFAULT=linux-cli bash ops/detect-host.sh
#   HOST_PROFILE=wsl bash ops/detect-host.sh
#
# Test overrides: DETECT_HOST_PROC_VERSION (default /proc/version) and
# DETECT_HOST_OSRELEASE (default /proc/sys/kernel/osrelease).

set -euo pipefail

proc_version="${DETECT_HOST_PROC_VERSION:-/proc/version}"
osrelease="${DETECT_HOST_OSRELEASE:-/proc/sys/kernel/osrelease}"

die() {
  echo "detect-host: $*" >&2
  exit 1
}

mode=profile
if [[ $# -eq 1 && "$1" == --wsl-version ]]; then
  mode=wslver
elif [[ $# -gt 0 ]]; then
  echo "detect-host: unknown argument: $*" >&2
  echo "usage: detect-host.sh [--wsl-version]" >&2
  exit 2
fi

# Kernel release strings to classify: the osrelease file and the release
# token of /proc/version ("Linux version <release> ..."). Only these tokens
# are inspected, never the whole /proc/version line (builder names, compiler
# strings), so unrelated "microsoft"/"wsl" text cannot cause a false match.
kernel_releases() {
  local found=0 line
  if [[ -r "$osrelease" ]] && line="$(head -n1 "$osrelease")" && [[ -n "$line" ]]; then
    echo "$line"
    found=1
  fi
  if [[ -r "$proc_version" ]] && line="$(sed -nE '1s/^Linux version ([^ ]+).*/\1/p' "$proc_version")" && [[ -n "$line" ]]; then
    echo "$line"
    found=1
  fi
  ((found)) || die "cannot read kernel release from $osrelease or $proc_version"
}

# Print 2 (WSL2), 1 (WSL1) or none. The repo supports WSL2 only: WSL1 has no
# real Linux kernel or systemd, so Nix and the Home Manager user timers do
# not work there. WSL2 kernels say "microsoft-standard" (or "WSL2"); WSL1
# reports a fake 4.4.0-*-Microsoft kernel. A kernel with neither marker is
# WSL2 only if WSL_DISTRO_NAME is set and the kernel is 5.x or newer (custom
# WSL2 builds); an older unmarked kernel under WSL_DISTRO_NAME is ambiguous
# and fails. Markers that disagree also fail.
detect_wsl_version() {
  local rel releases v2=0 v1=0 major
  releases="$(kernel_releases)" || exit 1
  while IFS= read -r rel; do
    shopt -s nocasematch
    if [[ "$rel" == *microsoft-standard* || "$rel" == *wsl2* ]]; then
      v2=1
    elif [[ "$rel" == *microsoft* ]]; then
      v1=1
    fi
    shopt -u nocasematch
  done <<<"$releases"
  if ((v1 && v2)); then
    die "ambiguous WSL kernel: markers disagree (${releases//$'\n'/ }); set HOST_PROFILE explicitly"
  elif ((v2)); then
    echo 2
  elif ((v1)); then
    echo 1
  elif [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    major="$(head -n1 <<<"$releases")"
    major="${major%%.*}"
    if [[ "$major" =~ ^[0-9]+$ ]] && ((major >= 5)); then
      echo 2
    else
      die "ambiguous kernel under WSL_DISTRO_NAME=$WSL_DISTRO_NAME (release $(head -n1 <<<"$releases")); set HOST_PROFILE explicitly"
    fi
  else
    echo none
  fi
}

if [[ "$mode" == wslver ]]; then
  # No uname here: wsl-check.sh runs this with a minimal PATH. $OSTYPE is a
  # bash builtin variable.
  case "$OSTYPE" in
    darwin*) echo none ;;
    linux*) detect_wsl_version ;;
    *) die "unsupported OS: $OSTYPE" ;;
  esac
  exit 0
fi

if [[ -n "${HOST_PROFILE:-}" ]]; then
  case "$HOST_PROFILE" in
    macos|linux-desktop|linux-cli|wsl)
      echo "$HOST_PROFILE"
      exit 0
      ;;
    *) die "unsupported HOST_PROFILE: $HOST_PROFILE" ;;
  esac
fi

case "$(uname -s)" in
  Darwin)
    echo macos
    ;;
  Linux)
    wsl="$(detect_wsl_version)" || exit 1
    case "$wsl" in
      2) echo wsl ;;
      1) die "WSL1 is not supported (no systemd, no real Linux kernel for Nix); convert with: wsl --set-version <distro> 2" ;;
      *)
        default="${HOST_PROFILE_DEFAULT:-linux-desktop}"
        case "$default" in
          linux-desktop|linux-cli) echo "$default" ;;
          *) die "unsupported HOST_PROFILE_DEFAULT: $default (use linux-desktop or linux-cli)" ;;
        esac
        ;;
    esac
    ;;
  *)
    die "unsupported OS: $(uname -s)"
    ;;
esac
