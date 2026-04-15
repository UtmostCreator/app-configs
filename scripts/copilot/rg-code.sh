#!/usr/bin/env bash
set -euo pipefail

pattern="${1:?pattern required}"
shift || true

rg -n --hidden \
  -g '!vendor' \
  -g '!node_modules' \
  -g '!dist' \
  -g '!.git' \
  "$pattern" "${@:-.}"
