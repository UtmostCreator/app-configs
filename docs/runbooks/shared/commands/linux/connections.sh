#!/usr/bin/env bash
# Established TCP connections grouped by peer. Usage: connections.sh [LOCAL_PORT=443]
set -euo pipefail
port=${1:-443}
command -v ss >/dev/null 2>&1 || { echo "ss not found" >&2; exit 1; }
echo "established on :$port: $(ss -Htn state established "( sport = :$port )" | wc -l)"
ss -Htn state established "( sport = :$port )" | awk '{print $4}' | sed 's/:[0-9]*$//' | sort | uniq -c | sort -nr | head -n 15
