#!/usr/bin/env bash
# Established TCP connections grouped by peer; a connection is not an HTTP request.
set -euo pipefail
port=${1:-443}
[[ "$port" =~ ^[0-9]+$ ]] && (( 10#$port >= 1 && 10#$port <= 65535 )) || { echo 'PORT must be 1..65535' >&2; exit 2; }
data=$(ss -Htn state established "( sport = :$port )")
printf 'established on :%s: ' "$port"
awk 'NF {n++} END {print n+0}' <<< "$data"
# With state filtering, ss omits the State column: peer is field 4.
awk 'NF {peer=$4; sub(/:[^:]+$/, "", peer); gsub(/^\[|\]$/, "", peer); c[peer]++}
     END {for (peer in c) print c[peer], peer}' <<< "$data" | sort -nr | sed -n '1,15p'
