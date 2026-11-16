#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # CHEZMOI_SOURCE_ARGS is read by the files that source this one
# One decision for every plain `chezmoi` call in ops/: does it need
# --source=<repo>?
#
# `chezmoi init --source=<repo>` (ops/install.sh, ops/bootstrap.sh) does not
# persist sourceDir. On a host without ~/.local/share/chezmoi (NixOS-WSL) every
# later plain `chezmoi apply|diff|status|verify|managed` then fails with
# "stat ~/.local/share/chezmoi: no such file". The decision is the one
# ops/lib/selection-facts.sh made first: no --source when `chezmoi source-path`
# already resolves (readlink -f) to <repo>/<.chezmoiroot>, so a configured host
# renders templates with its own sourceDir spelling; otherwise --source=<repo>.
# An empty or failing `chezmoi source-path` and a failing readlink both mean
# "not configured", so the arg is added.
#
#   chezmoi_source_set REPO_ROOT   sets CHEZMOI_SOURCE_ARGS to () or (--source=REPO_ROOT),
#                                  CHEZMOI_SOURCE_STATE and CHEZMOI_SOURCE_PATH
#   chezmoi_source_hint            prints "" or "--source=<repo> " (shell-quoted) for advice text
#
# CHEZMOI_SOURCE_STATE (the args above are the same in every state but configured):
#   configured    source-path resolves to <repo>/<.chezmoiroot>: no --source needed.
#   unconfigured  source-path fails or prints nothing, readlink fails, or it names a
#                 directory that does not exist. Real chezmoi prints its default
#                 ~/.local/share/chezmoi with rc 0 even when that is missing, so the
#                 directory is tested (-d), not the exit status. This is the
#                 NixOS-WSL case: --source=<repo> is the right call.
#   other         chezmoi is configured for an EXISTING directory that is not this
#                 repo (another clone; this repo is a worktree). Read-only uses
#                 (status, diff, verify, readiness, audit) still pass --source=<repo>.
#                 A mutating caller must not: templates bake .chezmoi.sourceDir into
#                 the files they write (sys-update, DOTFILES_DIR), so ops/update-all.sh
#                 refuses --apply in this state ("run sys-update from that checkout").
#                 CHEZMOI_SOURCE_PATH holds that directory.
#
# Use: chezmoi_source_set "$REPO_ROOT"; chezmoi ${CHEZMOI_SOURCE_ARGS[@]+"${CHEZMOI_SOURCE_ARGS[@]}"} apply
# The array form is bash 3.2 safe (no bash 4 builtins, and the ${a[@]+...} spelling
# survives an empty array under set -u).
# Defines functions and variables only. Sourced by ops/lib/selection-facts.sh,
# ops/update-all.sh, ops/audit.sh, ops/bootstrap.sh, ops/readiness.sh,
# ops/snapshot-home.sh and ops/unix/ssh-agent-setup.sh.

CHEZMOI_SOURCE_ARGS=()
CHEZMOI_SOURCE_STATE=unconfigured
CHEZMOI_SOURCE_PATH=""

chezmoi_source_set() {
  local repo="$1" root="" configured real want
  CHEZMOI_SOURCE_ARGS=("--source=$repo")
  CHEZMOI_SOURCE_STATE=unconfigured
  CHEZMOI_SOURCE_PATH=""
  if [[ -f "$repo/.chezmoiroot" ]]; then root="$(head -n1 "$repo/.chezmoiroot")"; fi
  configured="$(chezmoi source-path </dev/null 2>/dev/null | head -n1)" || return 0
  [[ -n "$configured" ]] || return 0
  real="$(readlink -f "$configured" 2>/dev/null)" || return 0
  want="$(readlink -f "$repo${root:+/$root}" 2>/dev/null)" || return 0
  if [[ "$real" == "$want" ]]; then
    CHEZMOI_SOURCE_ARGS=()
    CHEZMOI_SOURCE_STATE=configured
  elif [[ -d "$configured" ]]; then
    CHEZMOI_SOURCE_STATE=other
    CHEZMOI_SOURCE_PATH="$configured"
  fi
  return 0
}

chezmoi_source_hint() {
  if [[ "${#CHEZMOI_SOURCE_ARGS[@]}" -gt 0 ]]; then printf '%q ' "${CHEZMOI_SOURCE_ARGS[0]}"; fi
}
