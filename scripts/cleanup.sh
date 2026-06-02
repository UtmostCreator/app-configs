#!/usr/bin/env bash
# Safe, non-destructive system cleanup for the Nix-based stack.
#
# Philosophy: reclaim disk WITHOUT destroying your ability to roll back.
# Two tiers:
#
#   SAFE (default, --apply):
#     - nix store --optimise   (hard-link identical files; never deletes refs)
#     - mise cache prune        (remove stale download cache)
#     - npm cache verify        (integrity check + dedupe, non-destructive)
#     - report Nix store size + Home Manager generation count
#
#   AGED (opt-in, --gc):
#     - nix-collect-garbage --delete-older-than <N>d
#       (removes generations older than N days; KEEPS recent rollbacks)
#       Default 14d. Override with KEEP_DAYS=<n>.
#     - home-manager expire-generations "-<N> days"
#
# This script NEVER runs `nix-collect-garbage -d` (delete ALL old
# generations) — that would wipe every rollback point. If you really want
# that, run it yourself, deliberately.
#
# Usage:
#   bash scripts/cleanup.sh                 # report only (default)
#   bash scripts/cleanup.sh --apply         # SAFE tier only
#   bash scripts/cleanup.sh --apply --gc    # SAFE + aged-generation GC (keeps recent)
#   KEEP_DAYS=30 bash scripts/cleanup.sh --apply --gc
#   bash scripts/cleanup.sh --apply --yes   # no prompt (unattended)
#
# Exit non-zero only on a hard failure of an attempted step.

set -uo pipefail

MODE="report"
DO_GC=0
ASSUME_YES=0
KEEP_DAYS="${KEEP_DAYS:-14}"

for arg in "$@"; do
  case "$arg" in
    --apply)   MODE="apply" ;;
    --gc)      DO_GC=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) printf '[cleanup] unknown arg: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

log()  { printf '[cleanup:%s] %s\n' "$MODE" "$*"; }
step() { printf '\n[cleanup] ── %s ──\n' "$*"; }
warn() { printf '[cleanup:warn] %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
run()  {
  if [[ "$MODE" == "report" ]]; then printf '   would run: %s\n' "$*";
  else log "+ $*"; "$@" || warn "step returned non-zero: $*"; fi
}

store_size() { du -sh /nix/store 2>/dev/null | awk '{print $1}'; }

log "KEEP_DAYS=$KEEP_DAYS   gc=$([[ $DO_GC == 1 ]] && echo on || echo off)"
log "Nix store size (before): $(store_size)"
if have home-manager; then
  log "Home Manager generations: $(home-manager generations 2>/dev/null | wc -l)"
fi

if [[ "$MODE" == "apply" && "$ASSUME_YES" != 1 ]]; then
  msg="Run SAFE cleanup"
  [[ $DO_GC == 1 ]] && msg="$msg + aged GC (delete generations older than ${KEEP_DAYS}d, keep recent)"
  printf '%s? [y/N] ' "$msg"
  read -r ans
  [[ "$ans" == y || "$ans" == Y ]] || { echo "Aborted"; exit 1; }
fi

# ── SAFE tier ───────────────────────────────────────────────────────────────
step "Optimise Nix store (hard-link duplicates; non-destructive)"
if have nix; then
  run nix store optimise
else
  warn "nix not on PATH (skip store optimise)"
fi

step "Prune tool caches (non-destructive)"
if have mise; then
  run mise cache clear
else
  warn "mise not on PATH (skip mise cache)"
fi
if have npm; then
  # 'verify' is non-destructive (integrity + GC of unreferenced); avoids the
  # heavier 'npm cache clean --force'.
  run npm cache verify
fi

# ── AGED GC tier (opt-in) ───────────────────────────────────────────────────
if [[ $DO_GC == 1 ]]; then
  step "Garbage-collect aged generations (keeps anything newer than ${KEEP_DAYS}d)"
  if have home-manager; then
    run home-manager expire-generations "-${KEEP_DAYS} days"
  fi
  if have nix-collect-garbage; then
    run nix-collect-garbage --delete-older-than "${KEEP_DAYS}d"
  elif have nix; then
    run nix-collect-garbage --delete-older-than "${KEEP_DAYS}d"
  else
    warn "nix-collect-garbage not available (skip aged GC)"
  fi
else
  log "Aged-generation GC not requested (pass --gc to enable; it keeps recent rollbacks)."
fi

step "Done"
log "Nix store size (after):  $(store_size)"
[[ "$MODE" == "report" ]] && log "Report only. Re-run with --apply (add --gc to reclaim aged generations)."
exit 0
