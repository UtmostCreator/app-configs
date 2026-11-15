#!/usr/bin/env bash
# shellcheck shell=bash
# The one place that turns the local install selection (T-0042) into Nix
# arguments. Every host build, switch and eval call site passes SELECTION_ARGS,
# so a selection is never applied by one script and dropped by the next.
#
# Sourced by ops/lib/hm-switch.sh, ops/install.sh, ops/bootstrap.sh,
# ops/update-all.sh and ops/audit.sh; by the mise sync tasks (mise.toml); and by
# `bash -c` in the fish function hms (home/dot_config/fish/conf.d/cli.fish).
# ops/install.sh also sources ops/lib/selection-facts.sh (the shared facts; the
# read-only selection diff of ops/update-all.sh loads it too) and
# ops/lib/selection-preview.sh (write, prompts and preview), which no other
# script may load or call; this file holds only the builder, so a switch, a
# build or an audit never loads that code.
#
#   selection_dir    prints the directory that may hold selection.toml
#   selection_args   fills SELECTION_ARGS (empty when there is no local file)
#   selection_args_text   prints " <args>" for messages, or nothing
#   selection_override_args DIR / selection_override_text DIR   the same flag for
#                    another directory (the proposed selection of install.sh)
#
# SELECTION_ARGS is `--override-input selection path:<absolute dir>` only when
# <dir>/selection.toml exists. The override implies --no-write-lock-file, so
# nix/flake.lock is not touched. Pass it as
#   ${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"}
# (an empty array is an unbound variable under set -u before bash 4.4).
#
# The path is percent-encoded for the URL (space, ?, # and %), so a directory
# name with those characters is neither misparsed nor taken for another path.
# Those four characters are the only ones encoded: a directory name holding other
# shell-special characters (quote, $, backtick, ;) is printed as is, so the
# printed form is not guaranteed safe to paste into a shell.
# The directory is made absolute here, before any sudo: sudo may change HOME,
# and a relative path would mean something else inside the build.
# Validators, CI and `nix flake check` do not source this file: they evaluate
# the committed default selection.
#
# Test override: APP_CONFIGS_SELECTION_DIR (taken as given). Otherwise the
# directory is built from XDG_CONFIG_HOME or $HOME, so on WSL2 it is under the
# Linux $HOME. An XDG_CONFIG_HOME on a Windows drive (/mnt/<letter>) is ignored
# and $HOME/.config is used instead; selection_args says so once on stderr.

SELECTION_ARGS=()
SELECTION_OVERRIDE=()
SELECTION_DIR=""

# _sel_xdg_on_drive: true when XDG_CONFIG_HOME is a Windows drive mount (WSL2:
# /mnt/<letter> or below). Such a directory is slow, has no Unix permissions and
# is shared with Windows tools, so it is not a home for the selection.
_sel_xdg_on_drive() {
  case "${XDG_CONFIG_HOME:-}" in
    /mnt/[a-zA-Z] | /mnt/[a-zA-Z]/*) return 0 ;;
  esac
  return 1
}

selection_dir() {
  local base
  if [[ -n "${APP_CONFIGS_SELECTION_DIR:-}" ]]; then
    printf '%s\n' "$APP_CONFIGS_SELECTION_DIR"
    return 0
  fi
  if _sel_xdg_on_drive; then base="$HOME/.config"; else base="${XDG_CONFIG_HOME:-$HOME/.config}"; fi
  printf '%s\n' "$base/app-configs/selection"
}

# The note about an ignored drive is printed by selection_args (never from the
# $(selection_dir) subshell) and only once per process.
_SEL_DRIVE_NOTED=0

# selection_url_path PATH: PATH with the characters that break a Nix `path:` URL
# percent-encoded. `%` first, so the others are not encoded twice.
selection_url_path() {
  local p="$1" pct='%' hash='#' q='?' space=' '
  p="${p//"$pct"/%25}"
  p="${p//"$space"/%20}"
  p="${p//"$q"/%3F}"
  p="${p//"$hash"/%23}"
  printf '%s' "$p"
}

# selection_override_args DIR: fills SELECTION_OVERRIDE for the selection in DIR
# (empty when DIR has no selection.toml). The one builder of the flag, used for
# the local selection and for the proposed one the preview evaluates.
selection_override_args() {
  local dir="$1" abs
  SELECTION_OVERRIDE=()
  [[ -f "$dir/selection.toml" ]] || return 0
  abs="$(cd "$dir" 2>/dev/null && pwd -P)" || return 0
  SELECTION_OVERRIDE=(--override-input selection "path:$(selection_url_path "$abs")")
}

# selection_override_text DIR: the flag as it would be passed once DIR holds a
# selection (for a dry run that writes nothing); DIR is used as given.
selection_override_text() {
  printf -- '--override-input selection path:%s' "$(selection_url_path "$1")"
}

selection_args() {
  SELECTION_ARGS=()
  if [[ -z "${APP_CONFIGS_SELECTION_DIR:-}" && "$_SEL_DRIVE_NOTED" == 0 ]] && _sel_xdg_on_drive; then
    _SEL_DRIVE_NOTED=1
    printf 'selection: ignoring XDG_CONFIG_HOME=%s (a Windows drive under /mnt); using %s/.config\n' "$XDG_CONFIG_HOME" "$HOME" >&2
  fi
  SELECTION_DIR="$(selection_dir)"
  selection_override_args "$SELECTION_DIR"
  if ((${#SELECTION_OVERRIDE[@]})); then SELECTION_ARGS=("${SELECTION_OVERRIDE[@]}"); fi
}

selection_args_text() {
  if ((${#SELECTION_ARGS[@]})); then
    printf ' %s' "${SELECTION_ARGS[*]}"
  fi
}
