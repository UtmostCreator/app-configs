#!/usr/bin/env bash
# Offline Apache route-mix: per-minute counts per ROUTE_CLASSES class (plus other); explicit plain/gzip input. See ../README.md.
set -euo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/../log_summary.py" route-mix "${@}"
