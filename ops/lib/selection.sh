#!/usr/bin/env bash
# shellcheck shell=bash
# The one place that turns the local install selection (T-0042) into Nix
# arguments. Sourced by hm-switch.sh, install.sh, bootstrap.sh, update-all.sh
# and audit.sh; every host build, switch and eval call site passes
# SELECTION_ARGS, so a selection is never applied by one script and dropped by
# the next.
#
#   selection_dir    prints the directory that may hold selection.toml
#   selection_args   fills SELECTION_ARGS (empty when there is no local file)
#   selection_args_text   prints " <args>" for messages, or nothing
#
# SELECTION_ARGS is `--override-input selection path:<absolute dir>` only when
# <dir>/selection.toml exists. The override implies --no-write-lock-file, so
# nix/flake.lock is not touched. Pass it as
#   ${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"}
# (an empty array is an unbound variable under set -u before bash 4.4).
#
# The directory is made absolute here, before any sudo: sudo may change HOME,
# and a relative path would mean something else inside the build.
# Validators, CI and `nix flake check` do not source this file: they evaluate
# the committed default selection.
#
# Test override: APP_CONFIGS_SELECTION_DIR. On WSL this resolves under the
# Linux $HOME like everywhere else, because it is built from $HOME.

SELECTION_ARGS=()
SELECTION_DIR=""

selection_dir() {
  printf '%s\n' "${APP_CONFIGS_SELECTION_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/app-configs/selection}"
}

selection_args() {
  local dir abs
  SELECTION_ARGS=()
  SELECTION_DIR="$(selection_dir)"
  dir="$SELECTION_DIR"
  [[ -f "$dir/selection.toml" ]] || return 0
  abs="$(cd "$dir" 2>/dev/null && pwd -P)" || return 0
  SELECTION_ARGS=(--override-input selection "path:$abs")
}

selection_args_text() {
  if ((${#SELECTION_ARGS[@]})); then
    printf ' %s' "${SELECTION_ARGS[*]}"
  fi
}
