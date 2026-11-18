#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: bash ops/macos-memory-report.sh [--help]\n'
  printf 'Show aggregate macOS memory and swap statistics (read-only).\n'
}

if [[ $# -eq 1 && ("$1" == "--help" || "$1" == "-h") ]]; then
  usage
  exit 0
fi
if [[ $# -ne 0 ]]; then
  usage >&2
  exit 64
fi
if [[ "$(uname -s)" != Darwin ]]; then
  printf '[macos-memory-report] This command requires macOS.\n' >&2
  exit 1
fi

report() {
  local label="$1"
  shift
  printf '\n== %s ==\n' "$label"
  if ! "$@"; then
    printf '[macos-memory-report] Could not query %s.\n' "$label" >&2
    failed=1
  fi
}

failed=0
report 'Physical memory (bytes)' /usr/sbin/sysctl -n hw.memsize
# -Q queries the current state; other modes can generate pressure.
report 'Memory pressure (query only)' /usr/bin/memory_pressure -Q
report 'Swap totals' /usr/sbin/sysctl -n vm.swapusage
report 'VM counters' /usr/bin/vm_stat
exit "$failed"
