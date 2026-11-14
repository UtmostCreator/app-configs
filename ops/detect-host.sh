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
# DETECT_HOST_OSRELEASE (default /proc/sys/kernel/osrelease),
# DETECT_HOST_WSL_INTEROP (default /proc/sys/fs/binfmt_misc/WSLInterop) and
# DETECT_HOST_WSL_RUN (default /run/WSL).

set -euo pipefail

proc_version="${DETECT_HOST_PROC_VERSION:-/proc/version}"
osrelease="${DETECT_HOST_OSRELEASE:-/proc/sys/kernel/osrelease}"
wsl_interop="${DETECT_HOST_WSL_INTEROP:-/proc/sys/fs/binfmt_misc/WSLInterop}"
wsl_run="${DETECT_HOST_WSL_RUN:-/run/WSL}"

die() {
  echo "detect-host: $*" >&2
  exit 1
}

mode=profile
if [[ $# -eq 1 && ( "$1" == -h || "$1" == --help ) ]]; then
  echo "Usage: bash ops/detect-host.sh [--wsl-version | -h | --help]"
  echo "Prints macos | linux-desktop | linux-cli | wsl. See the header for overrides."
  exit 0
elif [[ $# -eq 1 && "$1" == --wsl-version ]]; then
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
# not work there. Rules, in order:
#   - "microsoft-standard" or "wsl2" in a release: WSL2.
#   - such a marker together with a plain "microsoft" release: ambiguous.
#   - a "microsoft" release with kernel major < 5 (WSL1's fake 4.4.0-*-Microsoft
#     kernel): WSL1. A "microsoft" release on 5.x or newer is ambiguous.
#   - no marker, WSL_DISTRO_NAME set: WSL2 only when the kernel is 5.x or newer
#     AND a WSL filesystem marker exists (WSLInterop or /run/WSL), because the
#     env var alone is inheritable. Otherwise ambiguous.
#   - nothing WSL-like: none.
# Ambiguity always fails with guidance to set HOST_PROFILE.
detect_wsl_version() {
  local rel releases v2=0 v1=0 v1major=0 major
  releases="$(kernel_releases)" || exit 1
  while IFS= read -r rel; do
    shopt -s nocasematch
    if [[ "$rel" == *microsoft-standard* || "$rel" == *wsl2* ]]; then
      v2=1
    elif [[ "$rel" == *microsoft* ]]; then
      v1=1
      v1major="${rel%%.*}"
    fi
    shopt -u nocasematch
  done <<<"$releases"
  rel="$(head -n1 <<<"$releases")"
  major="${rel%%.*}"
  if ((v1 && v2)); then
    die "ambiguous WSL kernel: markers disagree (${releases//$'\n'/ }); set HOST_PROFILE explicitly (e.g. HOST_PROFILE=wsl)"
  elif ((v2)); then
    echo 2
  elif ((v1)); then
    if [[ "$v1major" =~ ^[0-9]+$ ]] && ((v1major < 5)); then
      echo 1
    else
      die "ambiguous kernel release '$rel': Microsoft marker without microsoft-standard on a 5.x+ kernel; set HOST_PROFILE explicitly (e.g. HOST_PROFILE=wsl)"
    fi
  elif [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    if [[ "$major" =~ ^[0-9]+$ ]] && ((major >= 5)) &&
      [[ -e "$wsl_interop" || -e "$wsl_run" ]]; then
      echo 2
    else
      die "ambiguous: WSL_DISTRO_NAME=$WSL_DISTRO_NAME but release '$rel' has no WSL marker and no WSL filesystem marker confirms WSL2; set HOST_PROFILE explicitly (e.g. HOST_PROFILE=wsl)"
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
