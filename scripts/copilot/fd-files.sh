#!/usr/bin/env bash
set -euo pipefail

query="${1:?query required}"
root="${2:-.}"

fd "$query" "$root"
