#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v lychee >/dev/null 2>&1; then
  echo "lychee is required for link checks" >&2
  exit 127
fi

exec lychee \
  --offline \
  --no-progress \
  --format detailed \
  "docs/**/*.md" \
  "AI-universal-rules/docs/**/*.md" \
  "AI-universal-rules/templates/**/*.md"
