#!/usr/bin/env bash
set -euo pipefail

mode="${1:?mode required}" # S | G | L | blame
search_target="${2:?target required}"
file="${3:-}"

case "$mode" in
  S)
    if [[ -n "$file" ]]; then
      git log -S "$search_target" -p -- "$file"
    else
      git log -S "$search_target" -p
    fi
    ;;
  G)
    if [[ -n "$file" ]]; then
      git log -G "$search_target" -p -- "$file"
    else
      git log -G "$search_target" -p
    fi
    ;;
  L)
    git log -L "$search_target"
    ;;
  blame)
    if [[ -z "$file" ]]; then
      echo "file required for blame mode" >&2
      exit 1
    fi

    git blame -L "$search_target" "$file"
    ;;
  *)
    echo "unknown mode: $mode" >&2
    exit 1
    ;;
esac
