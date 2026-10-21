#!/usr/bin/env bash
# Shared helpers for the gh-pr-* scripts: command checks and the repo
# include/exclude filter driven by the gh-pr-watch config file.
# Source this file; it expects the caller to have set `set -euo pipefail`.

CONFIG_PATH="${GH_PR_WATCH_CONFIG:-$HOME/.config/gh-pr-watch/config.yml}"

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  if ! has_cmd "$1"; then
    echo "Missing required command: $1" >&2
    exit 127
  fi
}

require_config() {
  if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "Missing config file: $CONFIG_PATH" >&2
    exit 1
  fi
}

read_list() {
  local expr="$1"
  yq -r "$expr" "$CONFIG_PATH" 2>/dev/null | sed '/^null$/d' || true
}

list_has() {
  local needle="$1"
  local haystack="$2"
  [[ -z "$haystack" ]] && return 1
  grep -Fxq "$needle" <<<"$haystack"
}

repo_allowed() {
  local full_repo="$1"
  local short_repo="${full_repo##*/}"
  local include_repos include_repo_names exclude_repos exclude_repo_names

  include_repos="$(read_list '.repos.include_repos // [] | .[]')"
  include_repo_names="$(read_list '.repos.include_repo_names // [] | .[]')"
  exclude_repos="$(read_list '.repos.exclude_repos // [] | .[]')"
  exclude_repo_names="$(read_list '.repos.exclude_repo_names // [] | .[]')"

  if list_has "$full_repo" "$exclude_repos" || list_has "$short_repo" "$exclude_repo_names"; then
    return 1
  fi

  if [[ -z "$include_repos" && -z "$include_repo_names" ]]; then
    return 0
  fi

  list_has "$full_repo" "$include_repos" || list_has "$short_repo" "$include_repo_names"
}
