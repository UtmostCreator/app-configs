#!/usr/bin/env bash
# Shared helpers for ops/projects/*. Sourced by every script in
# this directory. Never run directly.
#
# What it does:
#   1. Locate ~/.config/projects/config.yaml (chezmoi-rendered).
#   2. Provide `proj_yq` to read values from it via yq.
#   3. Provide `proj_ids` to enumerate project ids.
#   4. Provide `proj_field <id> <dotted.path>` to read a per-project key.
#   5. Provide `proj_expand_path` for tilde expansion.
#   6. Provide `require_cmd` for prereq checking.
#
# Assumes yq (mikefarah, golang) is on PATH. Bootstrap installs it via
# Nix; mise tools:optional:install also includes it.

set -uo pipefail

PROJECTS_CONFIG="${PROJECTS_CONFIG:-$HOME/.config/projects/config.yaml}"

proj_log() {
  printf '[projects] %s\n' "$*" >&2
}

proj_fail() {
  printf '[projects][ERROR] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      proj_fail "missing required command: $cmd"
    fi
  done
}

proj_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

proj_check_config() {
  if [[ ! -f "$PROJECTS_CONFIG" ]]; then
    proj_fail "missing $PROJECTS_CONFIG — run 'chezmoi apply' (or 'mise run sync:apply')"
  fi
  require_cmd yq
}

proj_yq() {
  # Read a yq expression from $PROJECTS_CONFIG, never erroring out
  # on missing keys (returns empty string instead).
  proj_check_config
  yq -r "$@" "$PROJECTS_CONFIG" 2>/dev/null || true
}

proj_ids() {
  # List project ids in declaration order.
  proj_yq '.projects | keys | .[]'
}

proj_field() {
  # proj_field <id> <dotted.path>
  # Example: proj_field cms dir   →  ~/work/cms
  local id="$1"
  local path="$2"
  [[ -z "$id" || -z "$path" ]] && return 1
  proj_yq ".projects.\"$id\".$path // empty"
}

proj_field_default() {
  # proj_field_default <id> <path> <default>
  local id="$1" path="$2" default="$3"
  local value
  value="$(proj_field "$id" "$path")"
  if [[ -z "$value" || "$value" == "null" ]]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$value"
  fi
}

proj_expand_path() {
  # Tilde expansion + env-var expansion for a single path string.
  local p="$1"
  p="${p/#\~/$HOME}"
  # shellcheck disable=SC2086
  eval "printf '%s\n' \"$p\""
}

proj_tmux_session() {
  # Render a tmux session name from config or fall back to a default.
  local key="$1" default="$2"
  local value
  value="$(proj_yq ".tmux.${key} // empty")"
  [[ -z "$value" || "$value" == "null" ]] && value="$default"
  printf '%s\n' "$value"
}

proj_layout_percent() {
  # Read a percentage out of tmux.layout.<key>; default if missing.
  local key="$1" default="$2"
  local value
  value="$(proj_yq ".tmux.layout.${key} // empty")"
  if [[ -z "$value" || "$value" == "null" ]]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$value"
  fi
}

# tmux helpers — all idempotent, never destructive.

proj_tmux_session_exists() {
  local session="$1"
  tmux has-session -t "$session" 2>/dev/null
}

proj_tmux_attach() {
  local session="$1" detached="${2:-0}"
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$session"
  elif [[ "$detached" == "1" ]]; then
    proj_log "tmux session '$session' started in detached mode"
  else
    tmux attach-session -t "$session"
  fi
}

proj_tmux_pane_id() {
  local session="$1" window="$2"
  tmux display-message -p -t "$session:$window" '#{pane_id}'
}

proj_term_lines() {
  if proj_have_cmd tput; then
    tput lines 2>/dev/null || printf '40\n'
  else
    printf '40\n'
  fi
}

proj_term_cols() {
  if proj_have_cmd tput; then
    tput cols 2>/dev/null || printf '120\n'
  else
    printf '120\n'
  fi
}

# emit a single JSON object on stdout. Used by health/checks.d/*.sh.
# Usage: proj_emit ok|fail "section" "note" ["fix command"]
proj_emit() {
  local status="$1" section="$2" note="$3" fix="${4:-}"
  jq -nc \
    --arg name "$PROJ_CHECK_NAME" \
    --arg section "$section" \
    --arg status "$status" \
    --arg note "$note" \
    --arg fix "$fix" \
    '{name:$name, section:$section, status:$status, note:$note, fix:$fix}'
}
