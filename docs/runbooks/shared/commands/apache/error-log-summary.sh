#!/usr/bin/env bash
# Offline Apache error-log-summary; explicit plain/gzip input. See ../README.md.
set -euo pipefail
if (( $# == 0 )); then set -- /var/log/apache2/error.log; fi
exec python3 "$(dirname "${BASH_SOURCE[0]}")/../log_summary.py" error-log-summary "${@}"
