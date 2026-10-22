#!/usr/bin/env bash
# Offline Apache status-distribution; explicit plain/gzip input. See ../README.md.
set -euo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/../log_summary.py" status-distribution "${@}"
