#!/usr/bin/env bash
# Group Laravel exception headers; WINDOW matches the header timestamp only.
set -euo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/../log_summary.py" laravel-errors "$@"
