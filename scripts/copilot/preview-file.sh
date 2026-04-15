#!/usr/bin/env bash
set -euo pipefail

file="${1:?file required}"

bat --style=numbers --color=always "$file"
