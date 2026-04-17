#!/usr/bin/env bash
set -euo pipefail

backend="${1:-auto}"
shift || true

run_repomix() {
  repomix "$@"
}

run_files_to_prompt() {
  files-to-prompt "$@"
}

run_code2prompt() {
  code2prompt "$@"
}

if [[ "$backend" == "auto" ]]; then
  if command -v repomix >/dev/null 2>&1; then
    run_repomix "$@"
    exit 0
  fi
  if command -v files-to-prompt >/dev/null 2>&1; then
    run_files_to_prompt "$@"
    exit 0
  fi
  if command -v code2prompt >/dev/null 2>&1; then
    run_code2prompt "$@"
    exit 0
  fi
  echo "No supported context packer found. Install one of: repomix, files-to-prompt, code2prompt." >&2
  exit 1
fi

case "$backend" in
  repomix) run_repomix "$@" ;;
  files-to-prompt) run_files_to_prompt "$@" ;;
  code2prompt) run_code2prompt "$@" ;;
  *)
    echo "Unknown backend: $backend" >&2
    echo "Usage: $0 [auto|repomix|files-to-prompt|code2prompt] [args...]" >&2
    exit 2
    ;;
esac
