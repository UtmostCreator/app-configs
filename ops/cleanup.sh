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
#     - report reclaimed space + Home Manager generation count
#
#   AGED (opt-in, --gc):
#     - nix-collect-garbage --delete-older-than <N>d
#       (removes generations older than N days; KEEPS recent rollbacks)
#       Default 14d. Override with KEEP_DAYS=<n>.
#     - home-manager expire-generations "-<N> days"
#     - Protected Home Manager generations (--protect-hm-generation <N>,
#       repeatable, and/or env PROTECT_HM_GENERATIONS="<N> <N> ...") are
#       never removed. When any are set, the blanket age-based steps cannot
#       honour that, so instead: aged, unprotected generations (never the
#       newest) are removed by id with `home-manager remove-generations`,
#       `nix profile wipe-history --older-than <N>d` handles the default
#       profile, and a plain `nix-collect-garbage` (no age flag) frees
#       unreachable paths only. This narrower path leaves aged generations of
#       other profiles (system, others) alone, and needs home-manager on PATH
#       to age HM generations at all (a warning says so when it is absent).
#
# A scheduled Home Manager nix.gc timer also exists; it is owned by
# nix/modules/common/nix-settings.nix, not by this script.
#
# This script NEVER runs `nix-collect-garbage -d` (delete ALL old
# generations) — that would wipe every rollback point. If you really want
# that, run it yourself, deliberately.
#
# Usage:
#   bash ops/cleanup.sh                 # report only (default)
#   bash ops/cleanup.sh --apply         # SAFE tier only
#   bash ops/cleanup.sh --apply --gc    # SAFE + aged-generation GC (keeps recent)
#   KEEP_DAYS=30 bash ops/cleanup.sh --apply --gc
#   bash ops/cleanup.sh --apply --gc --protect-hm-generation 42
#     (value must be digits; env PROTECT_HM_GENERATIONS="42 41" also works and
#      is an error if set but containing no id)
#   bash ops/cleanup.sh --apply --yes   # no prompt (unattended)
#
# Exit status: every attempted step runs even if an earlier one failed; the
# script then prints a summary of failed steps and exits 1 if there were any.

set -uo pipefail

MODE="report"
DO_GC=0
ASSUME_YES=0
KEEP_DAYS="${KEEP_DAYS:-14}"
FAILED=()
PROTECTION_OK=1
# Normalised (base-10) protected Home Manager generation numbers.
PROTECT_IDS=()

add_protected() {
  if [[ ! "$1" =~ ^[0-9]+$ ]]; then
    printf '[cleanup] protected generation must be digits only: "%s"\n' "$1" >&2; exit 1
  fi
  PROTECT_IDS+=("$((10#$1))")
}

if [[ ! "$KEEP_DAYS" =~ ^[0-9]+$ ]]; then
  printf '[cleanup] KEEP_DAYS must be a whole number of days: "%s"\n' "$KEEP_DAYS" >&2; exit 1
fi
KEEP_DAYS=$((10#$KEEP_DAYS))  # decimal: "031" is 31, never octal

while (( $# )); do
  case "$1" in
    --apply)   MODE="apply" ;;
    --gc)      DO_GC=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    --protect-hm-generation)
      if [[ $# -lt 2 ]]; then
        printf '[cleanup] --protect-hm-generation needs a generation number\n' >&2; exit 1
      fi
      add_protected "$2"; shift ;;
    -h|--help) awk 'NR > 1 { if (/^#/) print; else exit }' "$0"; exit 0 ;;
    *) printf '[cleanup] unknown arg: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

# Env: any whitespace (space, tab, newline) separates ids. Set but empty of ids
# is an error, never a silent "no protection".
if [[ -n "${PROTECT_HM_GENERATIONS+x}" ]]; then
  env_count=0
  for g in $PROTECT_HM_GENERATIONS; do add_protected "$g"; env_count=$((env_count + 1)); done
  if (( env_count == 0 )); then
    printf '[cleanup] PROTECT_HM_GENERATIONS is set but contains no generation number\n' >&2; exit 1
  fi
fi

is_protected() {
  local want="$1" p
  for p in "${PROTECT_IDS[@]}"; do [[ "$p" == "$want" ]] && return 0; done
  return 1
}

log()  { printf '[cleanup:%s] %s\n' "$MODE" "$*"; }
step() { printf '\n[cleanup] ── %s ──\n' "$*"; }
warn() { printf '[cleanup:warn] %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
run()  {
  if [[ "$MODE" == "report" ]]; then printf '   would run: %s\n' "$*";
  else
    log "+ $*"
    "$@" || { warn "step failed: $*"; FAILED+=("$*"); }
  fi
}

# Home Manager generation ids older than KEEP_DAYS, newest generation and every
# protected id excluded. Input is `home-manager generations`
# ("YYYY-MM-DD HH:MM : id N -> /nix/store/..."), newest first, local time.
# Return 1: listing failed. Return 2: cutoff date could not be formatted.
# The cutoff is formatted once (GNU `date -d @x`, else BSD `date -r x`) and
# compared as text with the listing's own date; no listing date is parsed.
aged_unprotected_hm_ids() {
  local cutoff_epoch cutoff first=1 date_part time_part id gens
  gens="$(home-manager generations 2>/dev/null)" || return 1
  cutoff_epoch=$(( $(date +%s) - KEEP_DAYS * 86400 ))
  cutoff="$(date -d "@$cutoff_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null \
    || date -r "$cutoff_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null)" || return 2
  [[ -n "$cutoff" ]] || return 2
  while read -r date_part time_part _ _ id _; do
    [[ "$id" =~ ^[0-9]+$ ]] || continue
    if (( first )); then first=0; continue; fi
    [[ "$date_part $time_part" < "$cutoff" ]] || continue
    is_protected "$((10#$id))" && continue
    printf '%s\n' "$id"
  done <<< "$gens"
}

# Free space on the filesystem holding the store, in KiB. `df` answers
# instantly; `du -sh /nix/store` walks tens of gigabytes to tell us the same
# thing twice per run, and its answer is unchanged by hard-linking anyway.
store_free_kb() { df -Pk /nix 2>/dev/null | awk 'NR==2 {print $4}'; }
human_kb() {
  awk -v kb="${1:-0}" 'BEGIN {
    if (kb < 0) kb = -kb
    split("KiB MiB GiB TiB", u, " "); i = 1
    while (kb >= 1024 && i < 4) { kb /= 1024; i++ }
    printf "%.1f %s", kb, u[i]
  }'
}

FREE_BEFORE="$(store_free_kb)"
log "KEEP_DAYS=$KEEP_DAYS   gc=$([[ $DO_GC == 1 ]] && echo on || echo off)"
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
  run mise cache prune
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
  if (( ${#PROTECT_IDS[@]} )); then
    log "protecting Home Manager generation(s): ${PROTECT_IDS[*]}"
    if have home-manager; then
      AGED_OUT="$(aged_unprotected_hm_ids)"; rc=$?
      mapfile -t AGED_IDS <<< "$AGED_OUT"
      [[ -n "${AGED_IDS[0]:-}" ]] || AGED_IDS=()
      if (( rc != 0 )); then
        # Cannot tell which generations to keep: run no GC at all.
        PROTECTION_OK=0
        if (( rc == 2 )); then reason="cutoff date could not be computed"; else reason="listing failed"; fi
        warn "Home Manager generations: $reason; protection not established, skipping GC"
        FAILED+=("protect Home Manager generations ($reason; GC skipped)")
      elif (( ${#AGED_IDS[@]} )); then
        run home-manager remove-generations "${AGED_IDS[@]}"
      else
        log "no aged, unprotected Home Manager generations to remove"
      fi
    else
      warn "home-manager not on PATH (Home Manager generations were not aged)"
    fi
    if (( PROTECTION_OK )); then
      have nix && run nix profile wipe-history --older-than "${KEEP_DAYS}d"
      if have nix-collect-garbage; then
        run nix-collect-garbage
      else
        warn "nix-collect-garbage not available (skip GC)"
      fi
    fi
  else
    if have home-manager; then
      run home-manager expire-generations "-${KEEP_DAYS} days"
    else
      warn "home-manager not on PATH (Home Manager generations were not aged)"
    fi
    if have nix-collect-garbage; then
      run nix-collect-garbage --delete-older-than "${KEEP_DAYS}d"
    elif have nix; then
      run nix-collect-garbage --delete-older-than "${KEEP_DAYS}d"
    else
      warn "nix-collect-garbage not available (skip aged GC)"
    fi
  fi
else
  log "Aged-generation GC not requested (pass --gc to enable; it keeps recent rollbacks)."
fi

step "Done"
FREE_AFTER="$(store_free_kb)"
if [[ -n "${FREE_BEFORE:-}" && -n "${FREE_AFTER:-}" ]]; then
  RECLAIMED_KB=$((FREE_AFTER - FREE_BEFORE))
  # Only mention disk when it actually moved; "63G => 63G" is not news.
  if (( RECLAIMED_KB > 1024 )); then
    log "freed $(human_kb "$RECLAIMED_KB") on /nix"
  else
    log "no measurable space reclaimed ($(human_kb "$FREE_AFTER") free on /nix)"
  fi
fi
[[ "$MODE" == "report" ]] && log "Report only. Re-run with --apply (add --gc to reclaim aged generations)."
if (( ${#FAILED[@]} )); then
  printf '\n[cleanup:error] %d step(s) failed:\n' "${#FAILED[@]}" >&2
  for f in "${FAILED[@]}"; do printf '  - %s\n' "$f" >&2; done
  exit 1
fi
exit 0
