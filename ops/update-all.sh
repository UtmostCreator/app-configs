#!/usr/bin/env bash
# Update everything this repo manages — the Linux/NixOS equivalent of the
# macOS `brewup` shell function, with the safety a config repo deserves.
#
# Lifecycle. Nothing is mutated until PRECHECK has passed in full:
#
#   PRECHECK  canonical repo path, git state, upstream, tools, disk
#   PLAN      what would run (this is all report mode does)
#   SNAPSHOT  dotfiles, flake.lock, Home Manager generation, tool versions
#   APPLY     git pull · flake update/check · chezmoi · home-manager ·
#             nix profile · mise · hooks · Syncthing ignores
#   VERIFY    generation, managed files, required commands, user services
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
#   --skip-verify     skip the post-update verification phase
#   --verbose, -v     mirror command output to the terminal
#
# Exit 0 on success (warnings allowed), 1 on a failed precondition or step.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=ops/lib/update-facts.sh
source "$REPO_ROOT/ops/lib/update-facts.sh"
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
    -h|--help)     sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'sys-update: unknown argument: %s (try --help)\n' "$arg" >&2; exit 2 ;;
  esac
done

HOST_PROFILE="${HOST_PROFILE:-$(bash "$REPO_ROOT/ops/detect-host.sh" 2>/dev/null || echo linux-desktop)}"
STATE_DIR="${SYS_UPDATE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sys-update}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$STATE_DIR/runs"
RUN_LOG="$RUN_DIR/$RUN_ID.log"
RUN_META="$RUN_DIR/$RUN_ID.meta"
LOCK_BACKUP="$RUN_DIR/$RUN_ID.flake.lock"
HM_PROFILE="$HOME/.local/state/nix/profiles/home-manager"

have() { command -v "$1" >/dev/null 2>&1; }
# Paths read better as ~/… and the home prefix is never the interesting part.
# The backslash matters: an unescaped ~ in the replacement is tilde-expanded
# back to the real home directory before it is ever substituted.
tilde() { printf '%s\n' "${1/#$HOME/\~}"; }
hm_generation() {
  local link; link="$(readlink "$HM_PROFILE" 2>/dev/null)" || return 1
  [[ "$link" =~ -([0-9]+)-link$ ]] && printf '%s\n' "${BASH_REMATCH[1]}"
}
meta_put() { [[ -n "${RUN_META:-}" ]] && printf '%s=%s\n' "$1" "$2" >> "$RUN_META"; return 0; }
meta_get() { sed -n "s/^$2=//p" "$1" | tail -1; }

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
  if [[ -n "$hm_path" && -x "$hm_path/activate" ]]; then
    if ui_run "home-manager" "$hm_path/activate"; then
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

if [[ "$GIT_STATE" == "no-repo" ]]; then
  ui_info "git" "not a git repository; repo self-update disabled"
  DO_PULL=0
else
  if [[ -n "$GIT_UPSTREAM" ]]; then
    ui_ok "branch" "$GIT_BRANCH → $GIT_UPSTREAM"
  else
    ui_info "branch" "$GIT_BRANCH (no upstream; repo self-update disabled)"
    DO_PULL=0
  fi
  case "$GIT_STATE" in
    clean)
      ui_ok "worktree" "clean" ;;
    dirty)
      # Fail closed. Updating on top of local changes mixes three unrelated
      # sources of conflict (your edits, upstream commits, a new lock), which
      # is exactly what you do not want to untangle later.
      if [[ "$ALLOW_DIRTY" == 1 ]]; then
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
    printf '  Resolve:   git -C %s status\n' "$REPO_ROOT"
    printf '             git -C %s commit -am "chore(config): local changes"\n' "$REPO_ROOT"
    printf '             git -C %s stash push -u -m "before sys-update"\n' "$REPO_ROOT"
    printf '  Override:  sys-update --allow-dirty\n\n'
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
HM_GEN_BEFORE=""; SNAPSHOT_DIR=""

if [[ "$MODE" == "apply" ]]; then
  ui_section "Snapshot"
  meta_put run_id "$RUN_ID"; meta_put repo "$REPO_ROOT"; meta_put host "$HOST_PROFILE"
  meta_put log "$RUN_LOG"

  HM_GEN_BEFORE="$(hm_generation || true)"
  HM_PATH_BEFORE="$(profile_target "$HM_PROFILE")"
  [[ -n "$HM_GEN_BEFORE" ]] && meta_put hm_gen_before "$HM_GEN_BEFORE"
  [[ -n "$HM_PATH_BEFORE" ]] && meta_put hm_path_before "$HM_PATH_BEFORE"
  HM_PKGS_BEFORE="$(packages_in_profile "$HM_PROFILE")"
  PROFILE_PKGS_BEFORE="$(packages_in_profile "$HOME/.nix-profile")"
  if MISE_BEFORE="$(mise_versions)"; then MISE_OK=1; fi
  ui_ok "package state" "$(printf '%s\n' "$HM_PKGS_BEFORE" | grep -c . ) Home Manager packages recorded"

  if [[ -f "$REPO_ROOT/nix/flake.lock" ]]; then
    if cp "$REPO_ROOT/nix/flake.lock" "$LOCK_BACKUP" 2>/dev/null; then
      meta_put flake_lock_backup "$LOCK_BACKUP"
      ui_ok "flake.lock" "backed up"
    else
      ui_warn "flake.lock" "backup failed"
    fi
  fi

  if [[ -x "$REPO_ROOT/ops/snapshot-home.sh" ]]; then
    if ui_run "dotfiles" bash "$REPO_ROOT/ops/snapshot-home.sh"; then
      SNAPSHOT_DIR="$(grep -oE '/[^ ]*dotfiles-snapshots/[0-9TZ]+' "$UI_LAST_LOG" | head -1)"
      [[ -n "$SNAPSHOT_DIR" ]] && meta_put snapshot_dir "$SNAPSHOT_DIR"
      ui_ok "dotfiles" "$(grep -oE '[0-9]+ copied' "$UI_LAST_LOG" | head -1) → $(tilde "${SNAPSHOT_DIR:-snapshot dir}")"
    else
      ui_err "dotfiles" "snapshot failed — refusing to apply without a way back"
      exit 1
    fi
  fi

  printf '%s\n' "$RUN_META" > "$STATE_DIR/last-run" 2>/dev/null || true

  # Keep the last N runs. Logs are cheap, but not unbounded; the rollback
  # handle for the current run is written above and always survives.
  KEEP_RUNS="${SYS_UPDATE_KEEP_RUNS:-20}"
  mapfile -t OLD_RUNS < <(find "$RUN_DIR" -maxdepth 1 -name '*.meta' -type f 2>/dev/null \
    | LC_ALL=C sort -r | tail -n "+$((KEEP_RUNS + 1))")
  for old_meta in ${OLD_RUNS[@]+"${OLD_RUNS[@]}"}; do
    rm -f "${old_meta%.meta}".{log,meta,flake.lock}
  done
fi

# ── 4. APPLY ────────────────────────────────────────────────────────────────

ui_section "$([[ "$MODE" == apply ]] && echo Updating || echo Plan)"
STEP_FAILED=0
step_fail() { ui_err "$1" "$2"; STEP_FAILED=1; }

# git pull ------------------------------------------------------------------
if [[ "$DO_PULL" == 1 ]]; then
  HEAD_BEFORE="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
  if ui_run "git pull" git -C "$REPO_ROOT" pull --ff-only; then
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
if ui_run "flake inputs" nix flake update --flake "$REPO_ROOT/nix"; then
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

# flake check ---------------------------------------------------------------
if [[ "$STEP_FAILED" == 0 ]]; then
  CHECK_ARGS=("$REPO_ROOT/nix")
  [[ "$FULL_CHECK" == 1 ]] && CHECK_ARGS=(--all-systems "${CHECK_ARGS[@]}")
  if ui_run "flake check" nix flake check "${CHECK_ARGS[@]}"; then
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

# chezmoi -------------------------------------------------------------------
if [[ "$STEP_FAILED" == 0 ]] && have chezmoi; then
  PENDING="$(chezmoi status 2>/dev/null | grep -c . || true)"
  CHEZMOI_ARGS=(apply)
  [[ "$CHEZMOI_FORCE" == 1 ]] && CHEZMOI_ARGS+=(--force)
  # The diff is recorded before the apply so the log always shows what changed.
  [[ "$MODE" == "apply" ]] && { ui_log_only ""; ui_log_only "\$ chezmoi diff"; chezmoi diff >> "${UI_LOG:-/dev/null}" 2>&1 || true; }
  if ui_run "chezmoi" chezmoi "${CHEZMOI_ARGS[@]}"; then
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
    if ui_run "darwin-rebuild" darwin-rebuild switch --flake "$REPO_ROOT/nix#macos"; then
      ui_scan_warnings; [[ "$MODE" == "apply" ]] && ui_ok "darwin-rebuild" "switched"
    else
      step_fail "darwin-rebuild" "switch failed"
    fi
  else
    if ui_run "home-manager" home-manager switch --flake "$REPO_ROOT/nix#$HOST_PROFILE"; then
      ui_scan_warnings
      [[ "$MODE" == "apply" ]] && ui_ok "home-manager" "generation $(hm_generation || echo '?')"
    else
      step_fail "home-manager" "switch failed — the previous generation is still active"
    fi
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
  elif ui_run "nix profile" nix profile upgrade "${PROFILE_ELEMENTS[@]}"; then
    ui_scan_warnings
    [[ "$MODE" == "apply" ]] && ui_ok "nix profile" "${#PROFILE_ELEMENTS[@]} element(s) checked"
  else
    ui_warn "nix profile" "upgrade returned non-zero (see the run log)"
  fi
fi

# mise ----------------------------------------------------------------------
if [[ "$STEP_FAILED" == 0 ]]; then
  if have mise; then
    if ui_run "mise" mise upgrade; then
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
if [[ "$STEP_FAILED" == 0 ]] && have lefthook && [[ -d "$REPO_ROOT/.git" ]]; then
  if ui_run "git hooks" sh -c "cd '$REPO_ROOT' && lefthook install"; then
    [[ "$MODE" == "apply" ]] && ui_ok "git hooks" "synced"
  else
    ui_warn "git hooks" "lefthook install failed"
  fi
fi

# Syncthing ignores ---------------------------------------------------------
if [[ "$STEP_FAILED" == 0 && -x "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh" ]]; then
  if ui_run "syncthing" bash "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh" --apply; then
    if [[ "$MODE" == "apply" ]]; then
      SYNC_CHANGED="$(grep -oE 'Updated [0-9]+ folder' "$UI_LAST_LOG" | grep -oE '[0-9]+' | head -1)"
      if [[ "${SYNC_CHANGED:-0}" -gt 0 ]]; then
        ui_ok "syncthing" "${SYNC_CHANGED} folder(s) updated — rescan in the Syncthing UI"
      else
        ui_ok "syncthing" ".stignore unchanged"
      fi
    fi
  else
    ui_warn "syncthing" ".stignore refresh returned non-zero"
  fi
fi

if [[ "$STEP_FAILED" == 1 ]]; then
  printf '\n%sUpdate failed.%s Full log: %s\n' "$UI_C_ERR" "$UI_C_OFF" "${RUN_LOG:-n/a}"
  [[ -n "$HM_GEN_BEFORE" ]] && printf '  Roll back with: sys-update rollback   (Home Manager generation %s)\n' "$HM_GEN_BEFORE"
  exit 1
fi

# ── 5. VERIFY ───────────────────────────────────────────────────────────────

if [[ "$MODE" == "apply" && "$DO_VERIFY" == 1 ]]; then
  ui_section "Verification"

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
fi

# ── 6. CLEANUP ──────────────────────────────────────────────────────────────

if [[ "$DO_CLEANUP" == 1 && -x "$REPO_ROOT/ops/cleanup.sh" ]]; then
  ui_section "Cleanup"
  CLEAN_ARGS=(--apply --yes); [[ "$DO_GC" == 1 ]] && CLEAN_ARGS+=(--gc)
  if ui_run "cleanup" bash "$REPO_ROOT/ops/cleanup.sh" "${CLEAN_ARGS[@]}"; then
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
else
  ui_notes_report
  printf '\n  %sReport only — nothing was changed. Re-run with --apply.%s\n' "$UI_C_DIM" "$UI_C_OFF"
fi

exit 0
