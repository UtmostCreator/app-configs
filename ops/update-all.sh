#!/usr/bin/env bash
# Update everything this repo manages — the Linux/NixOS equivalent of the
# macOS `brewup` shell function, with the safety a config repo deserves.
#
# Lifecycle. An apply first takes the update lock and creates its state
# directory; nothing else is mutated until PRECHECK has passed in full:
#
#   PRECHECK  canonical repo path, git state, upstream, tools, disk
#   PLAN      what would run (this is all report mode does)
#   SNAPSHOT  dotfiles, flake.lock, Home Manager generation, tool versions
#   PREPARE   git pull · flake update/check · host build (nothing activated;
#             a failure here restores flake.lock)
#   ACTIVATE  chezmoi · home-manager / darwin-rebuild · the profile must then
#             point at the closure PREPARE built (always checked)
#   VERIFY    gate: the default browser works (skipped by --skip-verify)
#   COMMIT    flake.lock, only after a verified activation
#   MAINTAIN  nix profile · mise · hooks · Syncthing ignores (warn only)
#   CHECKS    managed files, required commands, user services (advisory)
#   CLEANUP   safe, non-destructive (ops/cleanup.sh)
#   SUMMARY   package delta, warnings worth acting on, rollback handle
#
# Command output is captured to a run log; the terminal keeps one line per
# step. Failures and --verbose bring the raw text back.
#
# Usage:
#   bash ops/update-all.sh                 # report only (default; no changes)
#   bash ops/update-all.sh --apply         # update, with one confirmation
#   bash ops/update-all.sh --apply --yes   # unattended
#   bash ops/update-all.sh rollback        # undo the last update
#
# Flags:
#   --apply           actually update (default is report-only)
#   --yes, -y         skip the confirmation prompt
#   --allow-dirty     update even though the worktree has local changes
#   --no-pull         never fast-forward the repo from its upstream
#   --full-check      nix flake check --all-systems (every platform)
#   --force           chezmoi apply --force (overwrite local edits to targets)
#   --gc              also reclaim generations older than KEEP_DAYS (14)
#   --no-cleanup      skip the cleanup phase (same as NO_CLEANUP=1)
#   --skip-verify     skip the VERIFY gate and the CHECKS (the profile target
#                     check still runs)
#   --verbose, -v     mirror command output to the terminal
#
# Exit codes:
#   0    success (warnings allowed)
#   1    a failed precondition or step, or an incomplete rollback
#   2    usage error (unknown argument)
#   3    refused: bats test running against the real HOME or repository
#   4    host detection failed (set HOST_PROFILE)
#   5    another sys-update holds the lock
#   129  hung up (SIGHUP)
#   130  interrupted (SIGINT)
#   131  quit (SIGQUIT)
#   141  broken pipe (SIGPIPE)
#   143  terminated (SIGTERM)

set -uo pipefail

# Re-exec contract with a parent sys-update (consumed by the pull/re-exec step):
# read once and unset at once, so no step command ever inherits them.
# shellcheck disable=SC2034  # read by the re-exec/adoption code
REEXEC_CHILD="${SYS_UPDATE_REEXEC:-}"
# shellcheck disable=SC2034
PARENT_RUN_ID="${SYS_UPDATE_RUN_ID:-}"
# shellcheck disable=SC2034
PULLED_FROM="${SYS_UPDATE_PULLED_FROM:-}"
unset SYS_UPDATE_REEXEC SYS_UPDATE_RUN_ID SYS_UPDATE_PULLED_FROM

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=ops/lib/update-facts.sh
source "$REPO_ROOT/ops/lib/update-facts.sh"
# shellcheck source=ops/lib/preflight.sh
source "$REPO_ROOT/ops/lib/preflight.sh"
# hm-switch.sh also sources profile-conflicts.sh (profile_hm_conflicts).
# shellcheck source=ops/lib/hm-switch.sh
source "$REPO_ROOT/ops/lib/hm-switch.sh"
# shellcheck source=ops/lib/update-ui.sh
source "$REPO_ROOT/ops/lib/update-ui.sh"
# shellcheck source=ops/update-version-report.sh
source "$REPO_ROOT/ops/update-version-report.sh"

MODE="report"
SUBCOMMAND=""
ASSUME_YES=0
ALLOW_DIRTY=0
DO_PULL=1
FULL_CHECK=0
CHEZMOI_FORCE=0
DO_GC=0
DO_CLEANUP=1
DO_VERIFY=1
VERBOSE=0
[[ "${NO_CLEANUP:-0}" == 1 ]] && DO_CLEANUP=0

STATE_DIR="${SYS_UPDATE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sys-update}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
LOCK_OWNED=0   # 1 only once this process has taken the lock itself
# 1 only for a process that created the run record it writes to: report mode,
# rollback and a refused run never write to a run's metadata.
RUN_META_OWNED=0
# Where an apply is, for the EXIT handler: precheck, snapshot, prepare,
# activate, verify, commit, maintain, checks, cleanup, summary.
PHASE=precheck
RUN_DIR="$STATE_DIR/runs"
RUN_LOG="$RUN_DIR/$RUN_ID.log"
RUN_META="$RUN_DIR/$RUN_ID.meta"
LOCK_BACKUP="$RUN_DIR/$RUN_ID.flake.lock"
# Home Manager's own activate rule decides where its profile lives: the XDG
# state directory when it exists, else the per-user Nix profile directory.
HM_PROFILE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles"
HM_PROFILE_DIR_OK=1
if [[ ! -d "$HM_PROFILE_DIR" ]]; then
  _hm_alt="${NIX_STATE_DIR:-/nix/var/nix}/profiles/per-user/${USER:-$(id -un)}"
  if [[ -d "$_hm_alt" ]]; then HM_PROFILE_DIR="$_hm_alt"; else HM_PROFILE_DIR_OK=0; fi
fi
HM_PROFILE="$HM_PROFILE_DIR/home-manager"
LOCK_FILE="$STATE_DIR/lock"
LOCK_DIR="$STATE_DIR/lock.d"

# ── lock ────────────────────────────────────────────────────────────────────
# One apply at a time. Two modes: flock(1) where it exists (the kernel drops the
# lock when every process holding the descriptor is gone; the lock is not tied
# to this process alone, so after SIGKILL an orphaned _ui_progress ticker can
# still hold it until it exits), else an mkdir lock with an owner file (macOS).
# The flock file is never unlinked.
# Every step command runs through run_step, which closes the lock descriptor,
# so a daemon a step leaves behind cannot keep the lock after we exit.

LOCK_MODE=""
use_flock() {
  [[ "${SYS_UPDATE_FORCE_MKDIR_LOCK:-0}" != 1 ]] && have flock && [[ -d /proc/self/fd ]]
}

lock_refuse_flock() {
  {
    printf 'sys-update: another sys-update is running (lock: %s)\n' "$LOCK_FILE"
    if have fuser; then printf '  holders:\n'; fuser -v "$LOCK_FILE" 2>&1 | sed 's/^/    /'
    elif have lsof; then printf '  holders:\n'; lsof "$LOCK_FILE" 2>&1 | sed 's/^/    /'; fi
    printf '  Wait for it to finish; the lock is released when that process exits.\n'
    printf '  A stray update-all.sh process (for example an orphan of a killed run) may be holding it; if no update is running, kill that process.\n'
  } >&2
}

lock_refuse_mkdir() {
  local owner_pid="" owner_run=""
  { read -r owner_pid owner_run < "$LOCK_DIR/owner"; } 2>/dev/null || true
  {
    printf 'sys-update: another sys-update holds the lock (%s)\n' "$LOCK_DIR"
    if [[ "$owner_pid" =~ ^[0-9]+$ ]]; then
      printf '  owner:   pid %s, run %s\n' "$owner_pid" "${owner_run:-?}"
      printf '  process: %s\n' "$(ps -p "$owner_pid" -o command= 2>/dev/null || echo 'not running')"
      printf '  Note: a pid can be reused, so a live process of that pid is not proof the owner is alive.\n'
    else
      printf '  owner:   unknown (no readable owner file)\n'
    fi
    printf '  If you are sure no update is running, remove the lock yourself:\n'
    printf '    rm -rf %q\n' "$LOCK_DIR"
  } >&2
}

# acquire_lock exits 5 when the lock is held, 1 when it cannot be set up.
acquire_lock() {
  mkdir -p "$STATE_DIR" || { printf 'sys-update: cannot create %s\n' "$STATE_DIR" >&2; exit 1; }
  if use_flock; then
    LOCK_MODE=flock
    exec 9>"$LOCK_FILE" || { printf 'sys-update: cannot open %s\n' "$LOCK_FILE" >&2; exit 1; }
    flock -n 9 || { lock_refuse_flock; exit 5; }
  else
    LOCK_MODE="mkdir"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then lock_refuse_mkdir; exit 5; fi
    # Owner file: written whole, then moved into place.
    if ! { printf '%s %s\n' "$$" "$RUN_ID" > "$LOCK_DIR/owner.$$" && mv -f "$LOCK_DIR/owner.$$" "$LOCK_DIR/owner"; }; then
      rm -rf "$LOCK_DIR"
      printf 'sys-update: cannot record the lock owner in %s\n' "$LOCK_DIR" >&2; exit 1
    fi
  fi
  LOCK_OWNED=1
}

# Only the owner (this pid and run id) removes an mkdir lock; a flock lock is
# released by the kernel when the process exits.
# shellcheck disable=SC2329  # invoked from on_exit
release_lock() {
  [[ "$LOCK_OWNED" == 1 && "$LOCK_MODE" == mkdir ]] || return 0
  [[ "$(cat "$LOCK_DIR/owner" 2>/dev/null)" == "$$ $RUN_ID" ]] && rm -rf "$LOCK_DIR"
  return 0
}

# Report mode never locks; it only mentions a running update.
lock_is_held() {
  if use_flock; then [[ -e "$LOCK_FILE" ]] && ! flock -n "$LOCK_FILE" true 2>/dev/null
  else [[ -d "$LOCK_DIR" ]]; fi
}

# run_step <label> <command...>: ui_run with the lock descriptor closed.
run_step() { ui_run "$@" 9>&-; }

have() { command -v "$1" >/dev/null 2>&1; }
# Paths read better as ~/… and the home prefix is never the interesting part.
# The backslash matters: an unescaped ~ in the replacement is tilde-expanded
# back to the real home directory before it is ever substituted.
tilde() { printf '%s\n' "${1/#$HOME/\~}"; }
hm_generation() {
  local link; link="$(readlink "$HM_PROFILE" 2>/dev/null)" || return 1
  [[ "$link" =~ -([0-9]+)-link$ ]] && printf '%s\n' "${BASH_REMATCH[1]}"
}
# meta_put returns the write status: a record that cannot be written is a
# rollback handle that does not exist.
meta_put() { [[ "$RUN_META_OWNED" == 1 && -n "${RUN_META:-}" ]] || return 1; printf '%s=%s\n' "$1" "$2" >> "$RUN_META"; }
meta_get() { sed -n "s/^$2=//p" "$1" | tail -1; }
meta_failed() {
  ui_err "metadata" "cannot write '$1' to $(tilde "$RUN_META") — refusing to apply without a rollback record"
  exit 1
}

# set_status <value>: the run's phase marker, read by rollback.
set_status() { meta_put status "$1"; }

# restore_guarded <meta> <label> <file> <backup> <hash key>
#
# Puts a backup back only while the file still holds what this update wrote, so
# an edit somebody else made in the meantime is never overwritten. The rule:
#   file equals the backup                   -> nothing to do
#   a hash was recorded (<hash key>)         -> restore only if the file still has it
#   no hash recorded                         -> restore only if lock_was_clean=1
#   anything else                            -> keep the file and warn
# The safety of this guard rests on the .failed copy of what was replaced, kept
# next to the backup: other agent sessions may edit this repo concurrently, and
# the sys-update lock does not stop them.
# Returns 0 when the file ends up as the backup (or was left correctly), 1 when
# it was kept, 2 when the restore itself failed.
# shellcheck disable=SC2329  # reached from on_exit

restore_guarded() {
  local meta="$1" label="$2" file="$3" backup="$4" key="$5" hash cur tmp="$3.tmp.$$"
  [[ -n "$backup" && -f "$backup" ]] || return 0
  cmp -s -- "$backup" "$file" 2>/dev/null && return 0
  hash="$(meta_get "$meta" "$key")"
  if [[ -n "$hash" ]]; then
    cur="$(git hash-object -- "$file" 2>/dev/null || true)"
    if [[ "$cur" != "$hash" ]]; then
      ui_warn "$label" "changed since the update wrote it; left in place (previous content: $(tilde "$backup"))"
      return 1
    fi
  elif [[ "$(meta_get "$meta" lock_was_clean)" != 1 ]]; then
    ui_warn "$label" "had local edits before the update and no record of what it wrote; left in place (previous content: $(tilde "$backup"))"
    return 1
  fi
  [[ -e "$file" ]] && cp -- "$file" "$backup.failed" 2>/dev/null
  if cp -- "$backup" "$tmp" && mv -f -- "$tmp" "$file"; then
    ui_ok "$label" "restored"
    return 0
  fi
  rm -f -- "$tmp"
  ui_err "$label" "restore failed"
  return 2
}

# The files this run's update writes, restored from this run's backups.
# shellcheck disable=SC2329  # reached from on_exit

restore_run_files() {
  restore_guarded "$RUN_META" "flake.lock" "$REPO_ROOT/nix/flake.lock" "$LOCK_BACKUP" flake_lock_hash_written
  restore_guarded "$RUN_META" "Brave release" "$REPO_ROOT/nix/packages/brave/release.json" \
    "$RUN_DIR/$RUN_ID.brave.json" brave_release_hash_written
  return 0
}

# What a failed or interrupted run leaves behind, by phase. Idempotent: the
# EXIT trap is the only caller.
# shellcheck disable=SC2329  # reached from on_exit

run_failed() {
  case "$PHASE" in
    snapshot) set_status failed:snapshot ;;
    prepare)  restore_run_files; set_status failed:prepare ;;
    activate) restore_run_files; set_status failed:activate
              printf '  Roll back with: sys-update rollback   (Home Manager generation %s)\n' "${HM_GEN_BEFORE:-unknown}" ;;
    verify)   set_status failed:verify ;;
    *)        ui_warn "update" "stopped during the $PHASE phase; the update itself was already committed or applied" ;;
  esac
}

# EXIT, INT, TERM, HUP, QUIT and PIPE are trapped before anything can take the lock or start a
# background job.
# shellcheck disable=SC2329  # invoked through the EXIT trap
on_exit() {
  local rc=$?
  trap - EXIT
  # Background jobs first: the _ui_progress ticker is a forked subshell that
  # keeps a copy of the lock descriptor and survives SIGINT. Left alive it
  # would hold the lock after this process is gone.
  # shellcheck disable=SC2046
  kill $(jobs -p) 2>/dev/null; wait 2>/dev/null
  if [[ "$RUN_META_OWNED" == 1 ]]; then
    ((rc == 0)) || run_failed
    meta_put exit_code "$rc" 2>/dev/null
  fi
  ui_cleanup
  release_lock
  exit "$rc"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
trap 'exit 131' QUIT
trap 'exit 141' PIPE

for arg in "$@"; do
  case "$arg" in
    rollback)      SUBCOMMAND="rollback" ;;
    --apply)       MODE="apply" ;;
    --yes|-y)      ASSUME_YES=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --no-pull)     DO_PULL=0 ;;
    --full-check)  FULL_CHECK=1 ;;
    --force)       CHEZMOI_FORCE=1 ;;
    --gc)          DO_GC=1 ;;
    --no-cleanup)  DO_CLEANUP=0 ;;
    --skip-verify) DO_VERIFY=0 ;;
    --verbose|-v)  VERBOSE=1 ;;
    --last)        : ;;  # accepted for `rollback --last` symmetry
    -h|--help)     awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
    *) printf 'sys-update: unknown argument: %s (try --help)\n' "$arg" >&2; exit 2 ;;
  esac
done

# detect-host.sh validates an explicit HOST_PROFILE too and explains a failure
# on stderr; there is no silent fallback to a desktop profile.
# Rollback never reads the host profile, so it does not depend on detection.
# Test guard (ops/lib/preflight.sh), before anything else: under bats an apply
# or rollback run must stay inside the test's scratch HOME and repo copy (an
# install test once switched Home Manager on the dev machine). Exit 3.
if [[ "$MODE" == apply || "$SUBCOMMAND" == rollback ]]; then
  preflight_bats_guard sys-update "to apply" "$REPO_ROOT"
fi

if [[ "$SUBCOMMAND" != rollback ]] && ! HOST_PROFILE="$(bash "$REPO_ROOT/ops/detect-host.sh")"; then
  printf 'sys-update: host detection failed; set HOST_PROFILE to macos, linux-desktop, linux-cli or wsl\n' >&2
  exit 4
fi
# An explicit HOST_PROFILE=wsl is echoed back unchecked; it must still mean WSL2.
if [[ "$SUBCOMMAND" != rollback && "$HOST_PROFILE" == wsl ]] \
  && [[ "$(bash "$REPO_ROOT/ops/detect-host.sh" --wsl-version 2>/dev/null)" == 1 ]]; then
  printf 'sys-update: WSL1 is not supported (no systemd, no real Linux kernel for Nix). Convert from PowerShell: wsl --set-version <distro> 2   (list distros: wsl --list --verbose)\n' >&2
  exit 4
fi

[[ "$MODE" == apply && "$SUBCOMMAND" != rollback ]] && acquire_lock

# ── rollback ────────────────────────────────────────────────────────────────

do_rollback() {
  local last meta gen hm_path lock snapshot
  last="$STATE_DIR/last-run"
  [[ -f "$last" ]] || { printf 'sys-update: no recorded run to roll back (looked in %s)\n' "$STATE_DIR" >&2; exit 1; }
  meta="$(cat "$last")"
  [[ -f "$meta" ]] || { printf 'sys-update: recorded run is gone: %s\n' "$meta" >&2; exit 1; }

  gen="$(meta_get "$meta" hm_gen_before)"
  hm_path="$(meta_get "$meta" hm_path_before)"
  lock="$(meta_get "$meta" flake_lock_backup)"
  local brave_backup
  brave_backup="$(meta_get "$meta" brave_release_backup)"
  snapshot="$(meta_get "$meta" snapshot_dir)"

  ui_init "" 0
  printf '%sROLLBACK · %s%s\n' "$UI_C_BOLD" "$(meta_get "$meta" run_id)" "$UI_C_OFF"
  ui_section "Will restore"
  [[ -n "$hm_path" ]] && ui_info "home-manager" "generation ${gen:-?} ($hm_path)"
  [[ -n "$lock" && -f "$lock" ]] && ui_info "flake.lock" "$(tilde "$lock")"
  [[ -n "$snapshot" ]] && ui_info "dotfiles" "$(tilde "$snapshot") (restored manually, see below)"

  if [[ "$ASSUME_YES" != 1 ]]; then
    printf '\nProceed with rollback? [y/N] '
    read -r ans
    [[ "$ans" == y || "$ans" == Y ]] || { echo "Aborted"; exit 1; }
  fi

  ui_section "Rolling back"
  local failed=0

  # The update committed its new locks, so restoring the old ones leaves the
  # worktree dirty and the next sys-update would refuse. Remember now, before
  # touching anything, whether those files were clean: only then is the
  # restore ours to commit.
  local restore_files=() restore_clean=0
  [[ -n "$lock" && -f "$lock" ]] && restore_files+=(nix/flake.lock)
  [[ -n "$brave_backup" && -f "$brave_backup" ]] && restore_files+=(nix/packages/brave/release.json)
  if ((${#restore_files[@]})) && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1 \
    && git -C "$REPO_ROOT" diff --quiet HEAD -- "${restore_files[@]}" 2>/dev/null; then
    restore_clean=1
  fi
  if [[ -n "$hm_path" && -x "$hm_path/activate" ]]; then
    if run_step "home-manager" "$hm_path/activate"; then
      ui_ok "home-manager" "generation ${gen:-?} re-activated"
    else
      ui_err "home-manager" "re-activation failed"; failed=1
    fi
  else
    ui_skip "home-manager" "previous generation no longer in the store"
  fi

  if [[ -n "$lock" && -f "$lock" ]]; then
    if cp "$lock" "$REPO_ROOT/nix/flake.lock"; then
      ui_ok "flake.lock" "restored"
    else
      ui_err "flake.lock" "restore failed"; failed=1
    fi
  else
    ui_skip "flake.lock" "no backup recorded"
  fi

  if [[ -n "$brave_backup" && -f "$brave_backup" ]]; then
    if cp "$brave_backup" "$REPO_ROOT/nix/packages/brave/release.json"; then
      ui_ok "Brave release" "restored"
    else
      ui_err "Brave release" "restore failed"; failed=1
    fi
  fi

  if ((${#restore_files[@]})) && [[ "$failed" == 0 ]] \
    && ! git -C "$REPO_ROOT" diff --quiet HEAD -- "${restore_files[@]}" 2>/dev/null; then
    if [[ "$restore_clean" != 1 ]]; then
      ui_warn "locks" "not committed (they had local edits before the rollback): ${restore_files[*]}"
    elif run_step "locks" git -C "$REPO_ROOT" commit --only -m "chore(nix): roll back flake inputs" -- "${restore_files[@]}"; then
      ui_ok "locks" "committed ($(git -C "$REPO_ROOT" rev-parse --short HEAD))"
    else
      ui_warn "locks" "restored but the commit failed; commit them before the next sys-update"
    fi
  fi

  if [[ -n "$snapshot" && -d "$snapshot" ]]; then
    ui_info "dotfiles" "restore with: cp -a $snapshot/. \$HOME/"
  fi

  printf '\n'
  if [[ "$failed" == 0 ]]; then
    ui_ok "rollback" "done"; exit 0
  fi
  ui_err "rollback" "incomplete"; exit 1
}

[[ "$SUBCOMMAND" == "rollback" ]] && do_rollback

# ── header ──────────────────────────────────────────────────────────────────

if [[ "$MODE" == "apply" ]]; then
  mkdir -p "$RUN_DIR" 2>/dev/null || true
  ui_init "$RUN_LOG" "$VERBOSE"
else
  ui_init "" "$VERBOSE"
  UI_DRY_RUN=1
fi

printf '%sSYSTEM UPDATE · %s%s' "$UI_C_BOLD" "$HOST_PROFILE" "$UI_C_OFF"
[[ "$MODE" == "report" ]] && printf '%s   (report — nothing will be changed)%s' "$UI_C_DIM" "$UI_C_OFF"
printf '\n'

# ── 1. PRECHECK ─────────────────────────────────────────────────────────────

ui_section "Preflight"
if [[ "$MODE" == "report" ]] && lock_is_held; then
  ui_info "lock" "another sys-update is running (this report takes no lock)"
fi
PRECHECK_FAILED=0
precheck_fail() { ui_err "$1" "$2"; PRECHECK_FAILED=1; }

ui_ok "repo" "$(tilde "$REPO_ROOT")"
# One canonical identity: chezmoi's source directory is only ever shown as an
# alias, never as a second repository.
CHEZMOI_SRC="$HOME/.local/share/chezmoi"
if [[ -e "$CHEZMOI_SRC" ]] && [[ "$(readlink -f "$CHEZMOI_SRC" 2>/dev/null)" == "$REPO_ROOT"* ]] && [[ "$VERBOSE" == 1 ]]; then
  ui_info "source alias" "$(tilde "$CHEZMOI_SRC") → $(tilde "$REPO_ROOT")"
fi

IFS=$'\t' read -r GIT_STATE GIT_MODIFIED GIT_UNTRACKED <<< "$(git_worktree_state "$REPO_ROOT")"
GIT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
GIT_UPSTREAM="$(git_upstream "$REPO_ROOT")"
# git_upstream: 0 with empty output = no upstream, 1 = configured but not
# resolvable, 2 = not a repository (see ops/lib/update-facts.sh).
GIT_UPSTREAM_RC=$?

if [[ "$GIT_STATE" == "no-repo" ]]; then
  ui_info "git" "not a git repository; repo self-update disabled"
  DO_PULL=0
else
  case "$GIT_UPSTREAM_RC" in
    0)
      if [[ -n "$GIT_UPSTREAM" ]]; then
        ui_ok "branch" "$GIT_BRANCH → $GIT_UPSTREAM"
      else
        ui_info "branch" "$GIT_BRANCH (no upstream; repo self-update disabled)"
        DO_PULL=0
      fi ;;
    1)
      DO_PULL=0
      if [[ "$MODE" == "apply" ]]; then
        precheck_fail "upstream" "$GIT_BRANCH has an upstream that cannot be resolved (check: git -C $REPO_ROOT status -sb)"
      else
        ui_warn "upstream" "$GIT_BRANCH has an upstream that cannot be resolved; repo self-update disabled"
      fi ;;
    *)
      DO_PULL=0
      ui_info "branch" "$GIT_BRANCH (upstream unknown; repo self-update disabled)" ;;
  esac
  case "$GIT_STATE" in
    error)
      # Fail closed: when git itself cannot say, the tree is not known to be clean.
      DO_PULL=0
      precheck_fail "worktree" "could not read the worktree status (git status failed)" ;;
    clean)
      ui_ok "worktree" "clean" ;;
    dirty)
      # Fail closed. Updating on top of local changes mixes three unrelated
      # sources of conflict (your edits, upstream commits, a new lock), which
      # is exactly what you do not want to untangle later.
      if [[ "$ALLOW_DIRTY" == 1 ]]; then
        # Flakes ignore untracked files, so new files under nix/ would fail
        # the flake check halfway through. Name them now.
        mapfile -t UNTRACKED_NIX < <(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- nix/ 2>/dev/null)
        if ((${#UNTRACKED_NIX[@]})); then
          precheck_fail "flake" "untracked files under nix/ are invisible to the flake; run: git add ${UNTRACKED_NIX[*]}"
        fi
        ui_warn "worktree" "$GIT_MODIFIED modified, $GIT_UNTRACKED untracked — updating anyway (--allow-dirty)"
        ui_note warn git "updated from a dirty worktree: $GIT_MODIFIED modified, $GIT_UNTRACKED untracked"
        DO_PULL=0
      else
        precheck_fail "worktree" "$((GIT_MODIFIED + GIT_UNTRACKED)) uncommitted changes ($GIT_MODIFIED modified, $GIT_UNTRACKED untracked)"
      fi ;;
  esac
fi

# Required tools. In report mode a missing tool is information, not a failure:
# the point of a report is to show what the update would do.
REQUIRED=(git nix chezmoi)
[[ "$HOST_PROFILE" == linux-desktop && -f "$REPO_ROOT/nix/packages/brave/release.json" ]] && REQUIRED+=(curl jq)
if [[ "$HOST_PROFILE" == "macos" ]]; then REQUIRED+=(darwin-rebuild); else REQUIRED+=(home-manager); fi
MISSING=()
for t in "${REQUIRED[@]}"; do have "$t" || MISSING+=("$t"); done
if [[ "${#MISSING[@]}" -eq 0 ]]; then
  ui_ok "tools" "${REQUIRED[*]}"
elif [[ "$MODE" == "apply" ]]; then
  precheck_fail "tools" "missing: ${MISSING[*]} (run: sys-install)"
else
  ui_warn "tools" "missing: ${MISSING[*]} (run: sys-install)"
fi

# Home Manager's profile directory (not used on macOS, which has no HM profile).
if [[ "$HM_PROFILE_DIR_OK" == 0 && "$HOST_PROFILE" != "macos" ]]; then
  if [[ "$MODE" == "apply" ]]; then
    precheck_fail "home-manager profile" "no profile directory found (looked in $HM_PROFILE_DIR and ${NIX_STATE_DIR:-/nix/var/nix}/profiles/per-user/${USER:-$(id -un)})"
  else
    ui_warn "home-manager profile" "no profile directory found (looked in $HM_PROFILE_DIR and ${NIX_STATE_DIR:-/nix/var/nix}/profiles/per-user/${USER:-$(id -un)})"
  fi
fi

# Hand-edited managed files. chezmoi asks before overwriting a target that
# changed since it last wrote it, and with --no-tty that question ends in an
# unexplained EOF halfway through the update. Ask it here instead, while
# nothing has been mutated. The first status column is "changed since chezmoi
# wrote it", the second "apply would change it"; only both together prompt.
# Targets owned by a modify_ script never prompt: chezmoi feeds them the live
# file and writes the merge (e.g. ~/.claude/settings.json, VS Code's
# settings.json), so an app rewriting them is expected, not a conflict.
CHEZMOI_CONFLICTS=()
CHEZMOI_STATUS_OK=1
if have chezmoi; then
  # A failing `chezmoi status` is not "no local edits": it means unknown.
  if _chezmoi_status="$(chezmoi status 2>/dev/null)"; then
    mapfile -t _chezmoi_edited < <(printf '%s\n' "$_chezmoi_status" \
      | awk 'substr($0,1,1)=="M" && substr($0,2,1)!=" " {print substr($0,4)}')
  else
    CHEZMOI_STATUS_OK=0
    _chezmoi_edited=()
    if [[ "$MODE" == "apply" ]]; then
      precheck_fail "managed files" "chezmoi status failed, so local edits cannot be ruled out (run: chezmoi status)"
    else
      ui_warn "managed files" "chezmoi status failed, so local edits cannot be ruled out (run: chezmoi status)"
    fi
  fi
  if [[ "${#_chezmoi_edited[@]}" -gt 0 ]]; then
    _chezmoi_dest="$(chezmoi target-path 2>/dev/null || true)"
    for _target in "${_chezmoi_edited[@]}"; do
      _source="$(chezmoi source-path "${_chezmoi_dest:-$HOME}/$_target" 2>/dev/null || true)"
      [[ "${_source##*/}" == modify_* ]] && continue
      CHEZMOI_CONFLICTS+=("$_target")
    done
  fi
  if [[ "$CHEZMOI_STATUS_OK" == 0 ]]; then
    :   # already reported above
  elif [[ "${#CHEZMOI_CONFLICTS[@]}" -eq 0 ]]; then
    ui_ok "managed files" "no local edits"
  elif [[ "$CHEZMOI_FORCE" == 1 ]]; then
    ui_warn "managed files" "${#CHEZMOI_CONFLICTS[@]} hand-edited, will be overwritten (--force): ${CHEZMOI_CONFLICTS[*]}"
    ui_note warn chezmoi "overwrote local edits to: ${CHEZMOI_CONFLICTS[*]}"
  elif [[ "$MODE" == "apply" ]]; then
    precheck_fail "managed files" "${#CHEZMOI_CONFLICTS[@]} edited since chezmoi wrote them: ${CHEZMOI_CONFLICTS[*]}"
  else
    ui_warn "managed files" "${#CHEZMOI_CONFLICTS[@]} edited since chezmoi wrote them: ${CHEZMOI_CONFLICTS[*]}"
  fi
fi

# Disk. A Nix update that runs out of space mid-build is a bad afternoon.
DISK_TARGET="/nix"; [[ -d "$DISK_TARGET" ]] || DISK_TARGET="$HOME"
DISK_FREE_KB="$(df -Pk "$DISK_TARGET" 2>/dev/null | awk 'NR==2 {print $4}')"
if [[ -n "${DISK_FREE_KB:-}" ]]; then
  DISK_FREE_GIB=$((DISK_FREE_KB / 1024 / 1024))
  if (( DISK_FREE_KB < 2 * 1024 * 1024 )); then
    precheck_fail "disk" "${DISK_FREE_GIB} GiB free on $DISK_TARGET — too little for a Nix build"
  elif (( DISK_FREE_KB < 10 * 1024 * 1024 )); then
    ui_warn "disk" "${DISK_FREE_GIB} GiB free on $DISK_TARGET (tight; consider sys-cleanup --gc)"
  else
    ui_ok "disk" "${DISK_FREE_GIB} GiB free on $DISK_TARGET"
  fi
fi

[[ -f "$REPO_ROOT/nix/flake.nix" ]] || precheck_fail "flake" "$REPO_ROOT/nix/flake.nix not found"

if [[ "$PRECHECK_FAILED" == 1 ]]; then
  printf '\n%sUpdate stopped before anything was changed.%s\n\n' "$UI_C_BOLD" "$UI_C_OFF"
  if [[ "$GIT_STATE" == "dirty" && "$ALLOW_DIRTY" != 1 ]]; then
    # Name the files: a bare count sends people to --allow-dirty instead of
    # committing (or porting) the actual change.
    mapfile -t _changed < <(git -C "$REPO_ROOT" status --short --untracked-files=all 2>/dev/null)
    printf '  Changed:\n'
    printf '    %s\n' "${_changed[@]:0:10}"
    (( ${#_changed[@]} > 10 )) && printf '    … and %d more\n' "$(( ${#_changed[@]} - 10 ))"
    printf '  Resolve:   git -C %s status\n' "$REPO_ROOT"
    printf '             git -C %s commit -am "chore(config): local changes"\n' "$REPO_ROOT"
    printf '             git -C %s stash push -u -m "before sys-update"\n' "$REPO_ROOT"
    printf '  Override:  sys-update --allow-dirty\n\n'
  fi
  if [[ "${#CHEZMOI_CONFLICTS[@]}" -gt 0 && "$CHEZMOI_FORCE" != 1 ]]; then
    printf '  Inspect:   chezmoi diff %s\n' "${CHEZMOI_CONFLICTS[@]/#/~/}"
    printf '  Keep:      port the edit into the repo source, then: chezmoi apply %s\n' "${CHEZMOI_CONFLICTS[@]/#/~/}"
    printf '  Discard:   sys-update --force   (the repo version wins)\n\n'
  fi
  exit 1
fi

# ── 2. PLAN / confirmation ──────────────────────────────────────────────────

if [[ "$MODE" == "apply" && "$ASSUME_YES" != 1 ]]; then
  printf '\nUpdate everything (flake inputs, Home Manager, chezmoi, mise) on host=%s? [y/N] ' "$HOST_PROFILE"
  read -r ans
  [[ "$ans" == y || "$ans" == Y ]] || { echo "Aborted"; exit 1; }
fi

# ── 3. SNAPSHOT ─────────────────────────────────────────────────────────────

HM_PKGS_BEFORE=""; PROFILE_PKGS_BEFORE=""; MISE_BEFORE=""; MISE_OK=0
HM_GEN_BEFORE=""; HM_PATH_BEFORE=""; SNAPSHOT_DIR=""; BUILD_OUT=""

# Only a lock that matches HEAD is ours to commit afterwards; local edits to it
# (possible under --allow-dirty) are the user's to keep or discard. Decided
# here so the run record can carry it (it is also what a restore will trust).
LOCK_WAS_CLEAN=0
UPDATE_FILES=(nix/flake.lock)
[[ -f "$REPO_ROOT/nix/packages/brave/release.json" ]] && UPDATE_FILES+=(nix/packages/brave/release.json)
if [[ "$GIT_STATE" != "no-repo" ]] \
  && git -C "$REPO_ROOT" ls-files --error-unmatch nix/flake.lock >/dev/null 2>&1 \
  && git -C "$REPO_ROOT" diff --quiet HEAD -- "${UPDATE_FILES[@]}" 2>/dev/null; then
  LOCK_WAS_CLEAN=1
fi

if [[ "$MODE" == "apply" ]]; then
  ui_section "Snapshot"
  PHASE=snapshot
  RUN_META_OWNED=1
  # Every record is checked: a rollback handle that could not be written must
  # stop the run here, before anything is changed.
  meta_put run_id "$RUN_ID" || meta_failed run_id
  meta_put repo "$REPO_ROOT" || meta_failed repo
  meta_put host "$HOST_PROFILE" || meta_failed host
  meta_put hm_profile "$HM_PROFILE" || meta_failed hm_profile
  meta_put log "$RUN_LOG" || meta_failed log
  meta_put lock_was_clean "$LOCK_WAS_CLEAN" || meta_failed lock_was_clean

  HM_GEN_BEFORE="$(hm_generation || true)"
  HM_PATH_BEFORE="$(profile_target "$HM_PROFILE")"
  if [[ -n "$HM_GEN_BEFORE" ]]; then meta_put hm_gen_before "$HM_GEN_BEFORE" || meta_failed hm_gen_before; fi
  if [[ -n "$HM_PATH_BEFORE" ]]; then meta_put hm_path_before "$HM_PATH_BEFORE" || meta_failed hm_path_before; fi
  HM_PKGS_BEFORE="$(packages_in_profile "$HM_PROFILE")"
  PROFILE_PKGS_BEFORE="$(packages_in_profile "$HOME/.nix-profile")"
  if MISE_BEFORE="$(mise_versions)"; then MISE_OK=1; fi
  ui_ok "package state" "$(printf '%s\n' "$HM_PKGS_BEFORE" | grep -cvFx -e "$UVR_EMPTY_SET" -e "") Home Manager packages recorded"

  if [[ -f "$REPO_ROOT/nix/flake.lock" ]]; then
    if cp "$REPO_ROOT/nix/flake.lock" "$LOCK_BACKUP" 2>/dev/null; then
      meta_put flake_lock_backup "$LOCK_BACKUP" || meta_failed flake_lock_backup
      ui_ok "flake.lock" "backed up"
    else
      ui_err "flake.lock" "backup failed"; exit 1
    fi
  fi

  if [[ -f "$REPO_ROOT/nix/packages/brave/release.json" ]]; then
    if cp "$REPO_ROOT/nix/packages/brave/release.json" "$RUN_DIR/$RUN_ID.brave.json"; then
      meta_put brave_release_backup "$RUN_DIR/$RUN_ID.brave.json" || meta_failed brave_release_backup
    else
      ui_err "Brave release" "backup failed"; exit 1
    fi
  fi

  # Fail closed: no snapshot script, or a failed snapshot, means no way back.
  # --print-dir keeps stdout to the directory alone; stderr is shown on
  # failure and always appended to the run log.
  if [[ ! -x "$REPO_ROOT/ops/snapshot-home.sh" ]]; then
    ui_err "dotfiles" "snapshot script missing or not executable — refusing to apply without a way back"
    exit 1
  fi
  SNAPSHOT_ERR="$(mktemp "${TMPDIR:-/tmp}/sys-update-snapshot.XXXXXX")"
  if SNAPSHOT_DIR="$("$REPO_ROOT/ops/snapshot-home.sh" --print-dir 2>"$SNAPSHOT_ERR" < /dev/null)" \
      && [[ -n "$SNAPSHOT_DIR" && -d "$SNAPSHOT_DIR" ]]; then
    cat "$SNAPSHOT_ERR" >> "$RUN_LOG"
    meta_put snapshot_dir "$SNAPSHOT_DIR" || meta_failed snapshot_dir
    ui_ok "dotfiles" "snapshot → $(tilde "$SNAPSHOT_DIR")"
  else
    cat "$SNAPSHOT_ERR" >> "$RUN_LOG"
    UI_LAST_LOG="$SNAPSHOT_ERR"
    ui_err "dotfiles" "snapshot failed — refusing to apply without a way back"
    exit 1
  fi

  # The pointer moves only now, once the record is complete, and atomically
  # (temp file + rename): a reader never sees a half-written or premature one.
  meta_put status started || meta_failed status
  if ! { [[ ! -d "$STATE_DIR/last-run" ]] && printf '%s\n' "$RUN_META" > "$STATE_DIR/last-run.tmp.$$" \
         && mv -f "$STATE_DIR/last-run.tmp.$$" "$STATE_DIR/last-run"; } 2>/dev/null; then
    rm -f "$STATE_DIR/last-run.tmp.$$"
    ui_err "last-run" "cannot write $(tilde "$STATE_DIR/last-run") — refusing to apply without a rollback pointer"
    exit 1
  fi

  # Keep the last N runs. Logs are cheap, but not unbounded. Everything a run
  # owns is named "<run id>.*"; the run last-run points at is never pruned.
  KEEP_RUNS="${SYS_UPDATE_KEEP_RUNS:-20}"
  mapfile -t OLD_RUNS < <(find "$RUN_DIR" -maxdepth 1 -name '*.meta' -type f 2>/dev/null \
    | LC_ALL=C sort -r | tail -n "+$((KEEP_RUNS + 1))")
  for old_meta in ${OLD_RUNS[@]+"${OLD_RUNS[@]}"}; do
    [[ "$old_meta" == "$RUN_META" ]] && continue
    old_id="$(basename "$old_meta" .meta)"
    [[ -n "$old_id" ]] || continue
    for old_file in "$RUN_DIR/$old_id".*; do
      [[ -e "$old_file" ]] && rm -f -- "$old_file"
    done
    rm -rf -- "${STATE_DIR:?}/gcroots/$old_id"
  done
  PHASE=prepare
fi

# ── 4. APPLY ────────────────────────────────────────────────────────────────

ui_section "$([[ "$MODE" == apply ]] && echo Updating || echo Plan)"
STEP_FAILED=0
step_fail() { ui_err "$1" "$2"; STEP_FAILED=1; }
# phase_status <value>: record a phase marker; a lost marker is a warning here,
# because only "activating" (set_status ... || meta_failed) must not be lost.
phase_status() { set_status "$1" || ui_warn "metadata" "could not record status=$1"; }
update_failed() {
  printf '\n%sUpdate failed.%s Full log: %s\n' "$UI_C_ERR" "$UI_C_OFF" "${RUN_LOG:-n/a}"
}

# git pull ------------------------------------------------------------------
if [[ "$DO_PULL" == 1 ]]; then
  HEAD_BEFORE="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
  if run_step "git pull" git -C "$REPO_ROOT" pull --ff-only; then
    if [[ "$MODE" == "apply" ]]; then
      HEAD_AFTER="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
      if [[ "$HEAD_BEFORE" == "$HEAD_AFTER" ]]; then ui_ok "git pull" "already current"
      else ui_ok "git pull" "$(git -C "$REPO_ROOT" rev-list --count "$HEAD_BEFORE..$HEAD_AFTER" 2>/dev/null || echo some) new commit(s)"; fi
    fi
  else
    # Offline or diverged must not stop a local-config update.
    ui_warn "git pull" "failed (offline or diverged); continuing with local config"
    ui_note warn git "could not fast-forward from $GIT_UPSTREAM — see the run log"
  fi
elif [[ "$GIT_STATE" != "no-repo" ]]; then
  ui_skip "git pull" "$([[ "$GIT_STATE" == dirty ]] && echo 'worktree has local changes' || echo 'no upstream configured')"
fi

# flake inputs --------------------------------------------------------------
lock_inputs() {
  [[ -f "$1" ]] && have jq || return 0
  jq -r '.nodes | to_entries[] | [.key, (.value.locked.rev // .value.locked.narHash // "")] | @tsv' "$1" 2>/dev/null
}
LOCK_BEFORE="$(lock_inputs "$REPO_ROOT/nix/flake.lock")"

# record_written_hash <meta key> <file>: the content hash of a file a writer
# step just produced, kept even when the step failed. A later restore only
# overwrites the file while it still has this content.
record_written_hash() {
  [[ "$MODE" == apply && -f "$2" ]] || return 0
  local hash
  if ! hash="$(git hash-object -- "$2")" || ! meta_put "$1" "$hash"; then
    step_fail "metadata" "cannot record $1 — a restore could not tell whose edit the file holds"
  fi
}

run_step "flake inputs" nix flake update --flake "$REPO_ROOT/nix"; FLAKE_UPDATE_RC=$?
record_written_hash flake_lock_hash_written "$REPO_ROOT/nix/flake.lock"
if [[ "$FLAKE_UPDATE_RC" == 0 ]]; then
  if [[ "$MODE" == "apply" ]]; then
    LOCK_AFTER="$(lock_inputs "$REPO_ROOT/nix/flake.lock")"
    if [[ -n "$LOCK_BEFORE" && -n "$LOCK_AFTER" ]]; then
      read -r _ n_up n_add n_rm _ <<< "$(package_delta "$LOCK_BEFORE" "$LOCK_AFTER" | grep '^summary' | tr '\t' ' ')"
      if (( n_up + n_add + n_rm == 0 )); then ui_ok "flake inputs" "already current"
      else ui_ok "flake inputs" "$((n_up + n_add)) input(s) updated"; fi
    else
      ui_ok "flake inputs" "refreshed"
    fi
  fi
  ui_scan_warnings
else
  step_fail "flake inputs" "nix flake update failed"
fi

# Linux Brave is packaged here because nixpkgs no longer provides it. Refresh
# the binary lock alongside flake inputs so browser security updates continue.
if [[ "$STEP_FAILED" == 0 && "$HOST_PROFILE" == linux-desktop ]] \
  && [[ -f "$REPO_ROOT/nix/packages/brave/release.json" ]]; then
  run_step "Brave release" bash "$REPO_ROOT/ops/update-brave.sh"; BRAVE_UPDATE_RC=$?
  record_written_hash brave_release_hash_written "$REPO_ROOT/nix/packages/brave/release.json"
  if [[ "$BRAVE_UPDATE_RC" == 0 ]]; then
    [[ "$MODE" == apply ]] && ui_ok "Brave release" "official stable release checked"
  else
    step_fail "Brave release" "could not verify the latest official release — nothing was applied"
  fi
fi

# flake check ---------------------------------------------------------------
if [[ "$STEP_FAILED" == 0 ]]; then
  CHECK_ARGS=("$REPO_ROOT/nix")
  [[ "$FULL_CHECK" == 1 ]] && CHECK_ARGS=(--all-systems "${CHECK_ARGS[@]}")
  if run_step "flake check" nix flake check "${CHECK_ARGS[@]}"; then
    ui_scan_warnings
    if [[ "$MODE" == "apply" ]]; then
      if [[ "$FULL_CHECK" == 1 ]]; then
        ui_ok "flake check" "all systems"
      else
        CHECK_SYSTEM="$(nix eval --impure --raw --expr builtins.currentSystem 2>/dev/null)"
        ui_ok "flake check" "${CHECK_SYSTEM:-this host} (use --full-check for every platform)"
      fi
    fi
  else
    step_fail "flake check" "the updated lock does not evaluate — nothing was applied"
  fi
fi

# Build the actual host closure before applying dotfiles or activating it.
# flake check alone does not validate arbitrary homeConfigurations outputs.
if [[ "$STEP_FAILED" == 0 ]]; then
  if [[ "$HOST_PROFILE" == macos ]]; then
    BUILD_TARGET="darwinConfigurations.macos.system"
  else
    BUILD_TARGET="homeConfigurations.$HOST_PROFILE.activationPackage"
  fi
  if run_step "host build" nix build --no-link "$REPO_ROOT/nix#$BUILD_TARGET"; then
    [[ "$MODE" == apply ]] && ui_ok "host build" "$HOST_PROFILE ready to activate"
  else
    step_fail "host build" "build failed — dotfiles and active generation were not changed"
  fi
fi

# A hand-installed `nix profile` package that ships a file Home Manager now
# also ships makes the switch fail after home-manager-path is already gone
# (git drops off PATH). Stop here instead, with the exact fix.
if [[ "$STEP_FAILED" == 0 && "$MODE" == apply ]]; then
  # Fail closed: a build that exits non-zero, prints nothing or names a path
  # that is not a directory cannot be checked for collisions, so it stops here.
  BUILD_OUT=""
  if _build_paths="$(nix build --no-link --print-out-paths "$REPO_ROOT/nix#$BUILD_TARGET" 2>/dev/null)"; then
    BUILD_OUT="$(printf '%s\n' "$_build_paths" | tail -n1)"
  fi
  if [[ -z "$BUILD_OUT" || ! -d "$BUILD_OUT" ]]; then
    step_fail "host build" "could not resolve the built closure (nix build --print-out-paths failed or printed no directory) — nothing was applied"
  elif [[ "$HOST_PROFILE" != macos ]]; then
    mapfile -t PROFILE_CONFLICTS < <(profile_hm_conflicts "$HOME/.nix-profile/manifest.json" "$BUILD_OUT/home-path")
    if ((${#PROFILE_CONFLICTS[@]})); then
      mapfile -t CONFLICT_PKGS < <(printf '%s\n' "${PROFILE_CONFLICTS[@]}" | cut -f1 | sort -u)
      step_fail "nix profile" "${#CONFLICT_PKGS[@]} hand-installed package(s) collide with Home Manager: ${PROFILE_CONFLICTS[*]//$'\t'/ ships }"
      printf '  Fix:       nix profile remove %s   (Home Manager now provides it), then sys-update\n' "${CONFLICT_PKGS[*]}"
    fi
  fi
fi

# ── 4b. ACTIVATE ────────────────────────────────────────────────────────────
# PREPARE changed nothing but flake.lock and the Brave release file; a step that
# failed up to here leaves nothing activated and the EXIT handler restores them.
if [[ "$STEP_FAILED" == 1 ]]; then update_failed; exit 1; fi
if [[ "$MODE" == "apply" ]]; then
  phase_status prepared
  # Recorded before anything is applied: rollback reads it to know the profile
  # may have moved. PHASE is still "prepare", so a failed write restores the lock.
  set_status activating || meta_failed status
  PHASE=activate
fi

# check_activated_target — the activation is only real if the profile now is
# the closure PREPARE built (a switch can exit 0 and leave the old generation).
check_activated_target() {
  local link want got
  if [[ "$HOST_PROFILE" == macos ]]; then link="${SYS_UPDATE_DARWIN_SYSTEM_LINK:-/run/current-system}"
  else link="$HM_PROFILE"; fi
  want="$(readlink -f -- "$BUILD_OUT" 2>/dev/null || true)"
  got="$(readlink -f -- "$link" 2>/dev/null || true)"
  if [[ -n "$want" && "$got" == "$want" ]]; then return 0; fi
  step_fail "activation" "$(tilde "$link") does not point at the built closure (expected ${want:-nothing}, found ${got:-nothing})"
  return 1
}

# chezmoi -------------------------------------------------------------------
if [[ "$STEP_FAILED" == 0 ]] && have chezmoi; then
  PENDING="$(chezmoi status 2>/dev/null | grep -c . || true)"
  CHEZMOI_ARGS=(apply --no-tty)
  [[ "$CHEZMOI_FORCE" == 1 ]] && CHEZMOI_ARGS+=(--force)
  # The diff is recorded before the apply so the log always shows what changed.
  [[ "$MODE" == "apply" ]] && { ui_log_only ""; ui_log_only "\$ chezmoi diff"; chezmoi diff >> "${UI_LOG:-/dev/null}" 2>&1 || true; }
  if run_step "chezmoi" chezmoi "${CHEZMOI_ARGS[@]}"; then
    [[ "$MODE" == "apply" ]] && ui_ok "chezmoi" "$( ((PENDING > 0)) && echo "$PENDING file(s) applied" || echo 'already in sync')"
  else
    # Without --force chezmoi stops at a target that was edited by hand; that
    # is a conflict worth surfacing, not something to steamroll.
    step_fail "chezmoi" "apply failed (local edits to a managed file? retry with --force)"
  fi
fi

# home-manager / darwin-rebuild ---------------------------------------------
if [[ "$STEP_FAILED" == 0 ]]; then
  if [[ "$HOST_PROFILE" == "macos" ]]; then
    if run_step "darwin-rebuild" darwin-rebuild switch --flake "$REPO_ROOT/nix#macos"; then
      ui_scan_warnings
      if [[ "$MODE" == "apply" ]] && check_activated_target; then ui_ok "darwin-rebuild" "switched"; fi
    else
      step_fail "darwin-rebuild" "switch failed"
    fi
  else
    # hm_switch_raw is the shared `home-manager switch -b hm-bak`
    # (ops/lib/hm-switch.sh); the conflict check already ran above.
    if run_step "home-manager" hm_switch_raw "$REPO_ROOT/nix" "$HOST_PROFILE"; then
      ui_scan_warnings
      if [[ "$MODE" == "apply" ]] && check_activated_target; then
        ui_ok "home-manager" "generation $(hm_generation || echo '?')"
      fi
    else
      # Say whether the failed switch got as far as moving the profile.
      _hm_now="$(profile_target "$HM_PROFILE")"
      if [[ -n "$_hm_now" && "$_hm_now" != "$HM_PATH_BEFORE" ]]; then
        step_fail "home-manager" "switch failed — the profile moved to $(tilde "$_hm_now"); roll back with: sys-update rollback"
      else
        step_fail "home-manager" "switch failed — the previous generation is still active"
      fi
    fi
  fi
fi

if [[ "$STEP_FAILED" == 1 ]]; then update_failed; exit 1; fi
if [[ "$MODE" == "apply" ]]; then
  phase_status activated
  PHASE=verify
fi
# ── 5. VERIFY (the gate) ────────────────────────────────────────────────────
# What must hold for the update to be committed. The profile target check
# above is part of it and cannot be skipped; --skip-verify skips what follows.

if [[ "$MODE" == "apply" ]]; then
  if [[ "$DO_VERIFY" == 1 ]]; then
    if [[ "$HOST_PROFILE" == linux-desktop ]]; then
      ui_section "Verification"
      BROWSER_DEFAULTS_OK=1
      for mime in x-scheme-handler/http x-scheme-handler/https text/html application/pdf; do
        [[ "$(xdg-mime query default "$mime" 2>/dev/null)" == brave-browser.desktop ]] || BROWSER_DEFAULTS_OK=0
      done
      if [[ "$BROWSER_DEFAULTS_OK" == 1 ]] && brave --version >/dev/null 2>&1; then
        ui_ok "default browser" "Brave (HTTP, HTTPS, HTML, PDF)"
      else
        ui_err "default browser" "Brave is unavailable or its default associations did not apply"
        printf '\nUpdate verification failed. Full log: %s\n' "$RUN_LOG"
        exit 1
      fi
    fi
    phase_status verified
  else
    phase_status verify-skipped
  fi
fi

# ── 6. COMMIT ───────────────────────────────────────────────────────────────
# The update proved the new lock builds, activates and verifies. Leaving it
# uncommitted would make the next run stop at the dirty-worktree gate on our
# own output; committing it earlier would leave a lock that never ran.

if [[ "$MODE" == "apply" ]]; then
  PHASE=commit
  COMMIT_STATE=commit-skipped
  if [[ "$GIT_STATE" != "no-repo" ]] \
    && ! git -C "$REPO_ROOT" diff --quiet HEAD -- "${UPDATE_FILES[@]}" 2>/dev/null; then
    if [[ "$LOCK_WAS_CLEAN" != 1 ]]; then
      ui_warn "flake.lock" "not committed (it had local edits before the update)"
      ui_note warn git "flake.lock not committed: it had local edits before the update"
    # --only commits the lock alone, whatever else is staged or modified.
    elif run_step "flake.lock" git -C "$REPO_ROOT" commit --only -m "chore(nix): update flake inputs" -- "${UPDATE_FILES[@]}"; then
      ui_ok "flake.lock" "committed ($(git -C "$REPO_ROOT" rev-parse --short HEAD))"
      COMMIT_STATE=committed
    else
      ui_warn "flake.lock" "commit failed; the new lock is left uncommitted (see the run log)"
      ui_note warn git "flake.lock not committed — commit it before the next sys-update"
      COMMIT_STATE=commit-failed
    fi
  fi
  phase_status "$COMMIT_STATE"
  PHASE=maintain
fi

# ── 7. MAINTAIN ─────────────────────────────────────────────────────────────
# Housekeeping after the update is committed: a failure here warns, it never
# undoes or blocks the update.
# homebrew ------------------------------------------------------------------
# nix-darwin no longer upgrades Homebrew (autoUpdate/upgrade = false), so this
# is the only place formulae and casks get upgraded. A failure warns rather
# than blocking the later steps.
if [[ "$STEP_FAILED" == 0 && "$HOST_PROFILE" == "macos" ]]; then
  if have brew; then
    if run_step "brew update" brew update && run_step "brew upgrade" brew upgrade --formula \
       && run_step "brew cask upgrade" brew upgrade --cask; then
      ui_scan_warnings
      [[ "$MODE" == "apply" ]] && ui_ok "homebrew" "formulae and casks upgraded"
    else
      ui_warn "homebrew" "upgrade returned non-zero (see the run log)"
    fi
  else
    ui_skip "homebrew" "brew not on PATH"
  fi
fi

# nix profile ---------------------------------------------------------------
# Only elements this profile genuinely owns: `home-manager-path` is installed
# by Home Manager and cannot be upgraded here, so asking is just noise.
if [[ "$STEP_FAILED" == 0 ]]; then
  PROFILE_ELEMENTS=()
  if have jq && [[ -f "$HOME/.nix-profile/manifest.json" ]]; then
    while IFS= read -r el; do [[ -n "$el" ]] && PROFILE_ELEMENTS+=("$el"); done < <(
      jq -r '.elements | if type == "object"
               then to_entries[] | select(.value.originalUrl != null) | .key
               else .[] | select(.originalUrl != null) | (.attrPath // empty) end' \
        "$HOME/.nix-profile/manifest.json" 2>/dev/null)
  fi
  if [[ "${#PROFILE_ELEMENTS[@]}" -eq 0 ]]; then
    ui_skip "nix profile" "no flake-installed entries to upgrade"
  elif run_step "nix profile" nix profile upgrade "${PROFILE_ELEMENTS[@]}"; then
    ui_scan_warnings
    [[ "$MODE" == "apply" ]] && ui_ok "nix profile" "${#PROFILE_ELEMENTS[@]} element(s) checked"
  else
    ui_warn "nix profile" "upgrade returned non-zero (see the run log)"
  fi
fi

# mise ----------------------------------------------------------------------
if [[ "$STEP_FAILED" == 0 ]]; then
  if have mise; then
    if run_step "mise" mise upgrade; then
      ui_scan_warnings
      [[ "$MODE" == "apply" ]] && ui_ok "mise" "tools upgraded"
    else
      ui_warn "mise" "upgrade returned non-zero (see the run log)"
      ui_note warn mise "mise upgrade did not complete cleanly"
    fi
  else
    ui_skip "mise" "not on PATH"
  fi
fi

# hooks ---------------------------------------------------------------------
if [[ "$STEP_FAILED" == 0 ]] && have lefthook && [[ -e "$REPO_ROOT/.git" ]]; then
  # The path travels as $1, never spliced into the command string.
  # shellcheck disable=SC2016
  if run_step "git hooks" sh -c 'cd "$1" && lefthook install' sh "$REPO_ROOT"; then
    [[ "$MODE" == "apply" ]] && ui_ok "git hooks" "synced"
  else
    ui_warn "git hooks" "lefthook install failed"
  fi
fi

# Syncthing ignores ---------------------------------------------------------
if [[ "$STEP_FAILED" == 0 && -x "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh" ]]; then
  if run_step "syncthing" bash "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh" --apply; then
    if [[ "$MODE" == "apply" ]]; then
      SYNC_CHANGED="$(grep -oE 'Updated [0-9]+ folder' "$UI_LAST_LOG" | grep -oE '[0-9]+' | head -1)"
      if [[ "${SYNC_CHANGED:-0}" -gt 0 ]]; then
        ui_ok "syncthing" "${SYNC_CHANGED} folder(s) updated — rescan in the Syncthing UI"
      else
        ui_ok "syncthing" ".stignore unchanged"
      fi
      # The helper only reports conflict files; it never deletes them.
      SYNC_CONFLICTS="$(grep -oE '[0-9]+ conflict file\(s\) left in place' "$UI_LAST_LOG" | tail -1 | grep -oE '^[0-9]+')"
      if [[ "${SYNC_CONFLICTS:-0}" -gt 0 ]]; then
        ui_warn "syncthing" "${SYNC_CONFLICTS} conflict file(s) kept — resolve by hand (bash ops/syncthing-obsidian-stignore.sh lists them)"
      fi
    fi
  else
    ui_warn "syncthing" ".stignore refresh returned non-zero"
  fi
fi

# ── 8. CHECKS (advisory) ────────────────────────────────────────────────────
# Reported, never a reason to fail: the update is already committed.

if [[ "$MODE" == "apply" && "$DO_VERIFY" == 1 ]]; then
  PHASE=checks
  ui_section "Checks"

  if [[ "$HOST_PROFILE" != "macos" ]]; then
    HM_GEN_AFTER="$(hm_generation || true)"
    if [[ -n "$HM_GEN_AFTER" && -d "$(profile_target "$HM_PROFILE")" ]]; then
      if [[ -n "$HM_GEN_BEFORE" && "$HM_GEN_AFTER" == "$HM_GEN_BEFORE" ]]; then
        ui_ok "home-manager" "generation $HM_GEN_AFTER (unchanged — nothing to rebuild)"
      else
        ui_ok "home-manager" "generation ${HM_GEN_BEFORE:-?} → $HM_GEN_AFTER"
      fi
    else
      ui_warn "home-manager" "no active generation found"
    fi
  fi

  if have chezmoi; then
    if chezmoi verify >/dev/null 2>&1; then ui_ok "managed files" "no drift"
    else ui_warn "managed files" "chezmoi reports drift (run: chezmoi diff)"
         ui_note warn chezmoi "managed files drifted after apply — run: chezmoi diff"; fi
  fi


  VERIFY_MISSING=()
  for t in nix git chezmoi mise fish rg fd jq; do have "$t" || VERIFY_MISSING+=("$t"); done
  if [[ "${#VERIFY_MISSING[@]}" -eq 0 ]]; then ui_ok "core commands" "all present"
  else ui_warn "core commands" "not on PATH: ${VERIFY_MISSING[*]} (open a new shell?)"; fi

  if have mise; then
    MISE_MISSING="$(mise ls --missing 2>/dev/null | grep -c . || true)"
    if [[ "${MISE_MISSING:-0}" -eq 0 ]]; then ui_ok "mise" "no missing tools"
    else ui_warn "mise" "$MISE_MISSING tool(s) not installed (run: mise install)"
         ui_note warn mise "$MISE_MISSING pinned tool(s) are not installed — run: mise install"; fi
  fi

  if have systemctl; then
    FAILED_UNITS="$(systemctl --user list-units --state=failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd' ' -)"
    if [[ -z "$FAILED_UNITS" ]]; then ui_ok "user services" "no failed units"
    else ui_warn "user services" "failed: $FAILED_UNITS"
         ui_note warn systemd "failed user units: $FAILED_UNITS (systemctl --user status <unit>)"; fi
  fi

  # How long until Claude Code / Codex need an interactive login again, so it
  # happens at home rather than failing while away (nix/modules/home/ai-cli-updates.nix).
  if have ai-auth-status; then
    if AI_AUTH="$(ai-auth-status --summary 2>/dev/null)"; then ui_ok "AI logins" "$AI_AUTH"
    else ui_warn "AI logins" "${AI_AUTH:-status unknown}"
         ui_note warn ai-auth "${AI_AUTH:-AI CLI login status unknown} — log in again before you travel (run: ai-auth-status)"; fi
  fi
fi

if [[ "$MODE" == "apply" ]]; then PHASE=cleanup; fi

# ── 6. CLEANUP ──────────────────────────────────────────────────────────────

if [[ "$DO_CLEANUP" == 1 && -x "$REPO_ROOT/ops/cleanup.sh" ]]; then
  ui_section "Cleanup"
  CLEAN_ARGS=(--apply --yes); [[ "$DO_GC" == 1 ]] && CLEAN_ARGS+=(--gc)
  if run_step "cleanup" bash "$REPO_ROOT/ops/cleanup.sh" "${CLEAN_ARGS[@]}"; then
    if [[ "$MODE" == "apply" ]]; then
      RECLAIMED="$(grep -oE 'freed [0-9.]+ [KMG]iB' "$UI_LAST_LOG" | tail -1)"
      ui_ok "cleanup" "${RECLAIMED:-caches pruned, store optimised}"
      [[ "$DO_GC" == 1 ]] || ui_info "generations" "kept (pass --gc to reclaim ones older than ${KEEP_DAYS:-14}d)"
    fi
  else
    ui_warn "cleanup" "returned non-zero (see the run log)"
  fi
elif [[ "$DO_CLEANUP" != 1 ]]; then
  ui_section "Cleanup"
  ui_skip "cleanup" "disabled (NO_CLEANUP / --no-cleanup)"
fi

# ── 7. SUMMARY ──────────────────────────────────────────────────────────────

if [[ "$MODE" == "apply" ]]; then
  ui_section "Changes"
  render_package_delta "Home Manager" "$HM_PKGS_BEFORE" "$(packages_in_profile "$HM_PROFILE")"
  printf '\n'
  render_package_delta "nix profile" "$PROFILE_PKGS_BEFORE" "$(packages_in_profile "$HOME/.nix-profile")"
  printf '\n'
  MISE_AFTER=""
  if [[ "$MISE_OK" == 1 ]]; then MISE_AFTER="$(mise_versions)" || MISE_OK=0; fi
  report_mise_changes "$MISE_BEFORE" "$MISE_AFTER" "$MISE_OK"

  ui_notes_report

  ui_section "Rollback"
  ui_info "generation" "${HM_GEN_BEFORE:-unknown}"
  [[ -n "$SNAPSHOT_DIR" ]] && ui_info "dotfiles" "$(tilde "$SNAPSHOT_DIR")"
  [[ -f "$LOCK_BACKUP" ]] && ui_info "flake.lock" "saved"
  ui_info "command" "sys-update rollback"

  printf '\n'
  if (( UI_COUNT_WARN > 0 || ${#UI_NOTES[@]} > 0 )); then
    ui_warn "updated" "with warnings · $(ui_counts_line)"
  else
    ui_ok "updated" "and verified · $(ui_counts_line)"
  fi
  printf '  %sfull log: %s%s\n' "$UI_C_DIM" "$(tilde "$RUN_LOG")" "$UI_C_OFF"
  meta_put status "done" || ui_warn "metadata" "could not record status=done"
else
  ui_notes_report
  printf '\n  %sReport only — nothing was changed. Re-run with --apply.%s\n' "$UI_C_DIM" "$UI_C_OFF"
fi

exit 0
