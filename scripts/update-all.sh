#!/usr/bin/env bash
# Update everything this repo manages — the Linux/NixOS equivalent of the
# macOS `brewup` shell function (brew update && brew upgrade && cleanup).
#
# What it updates, in order:
#   1. git pull --ff-only        (repo itself; optional, skipped if dirty)
#   2. nix flake update ./nix    (refresh pinned inputs -> flake.lock)
#   3. nix flake check ./nix     (fail fast if the new lock is broken)
#   4. chezmoi apply --force     (re-render dotfiles from the updated source)
#   5. home-manager switch / darwin-rebuild switch  (rebuild from new inputs)
#   6. nix profile upgrade       (refresh nix-profile base tools)
#   7. mise upgrade              (bump non-Nix tool versions, if any)
#   8. lefthook install          (re-sync hooks)
#   9. light cleanup             (delegates to scripts/cleanup.sh, safe mode)
#
# Default is REPORT-ONLY (prints the plan, mutates nothing). Pass --apply to
# run it. Pass --yes to skip the single confirmation prompt (cron / unattended).
#
# Usage:
#   bash scripts/update-all.sh              # report only
#   bash scripts/update-all.sh --apply      # update, with one confirmation
#   bash scripts/update-all.sh --apply --yes   # fully unattended
#   NO_CLEANUP=1 bash scripts/update-all.sh --apply   # skip step 9
#
# Exit non-zero on the first required-step failure.

set -uo pipefail

MODE="report"
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --apply)   MODE="apply" ;;
    --yes|-y)  ASSUME_YES=1 ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    *) printf '[update-all] unknown arg: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log()  { printf '[update-all:%s] %s\n' "$MODE" "$*"; }
step() { printf '\n[update-all] ── %s ──\n' "$*"; }
warn() { printf '[update-all:warn] %s\n' "$*" >&2; }
fail() { printf '[update-all:error] %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
run()  {
  if [[ "$MODE" == "report" ]]; then printf '   would run: %s\n' "$*";
  else log "+ $*"; "$@" || fail "step failed: $*"; fi
}

HOST_PROFILE="${HOST_PROFILE:-$(bash "$REPO_ROOT/scripts/detect-host.sh" 2>/dev/null || echo linux-desktop)}"
log "Repo: $REPO_ROOT   Host: $HOST_PROFILE"

if [[ "$MODE" == "apply" && "$ASSUME_YES" != 1 ]]; then
  printf 'Update everything (flake inputs, HM, chezmoi, mise) on host=%s? [y/N] ' "$HOST_PROFILE"
  read -r ans
  [[ "$ans" == y || "$ans" == Y ]] || { echo "Aborted"; exit 1; }
fi

# 1. repo self-update (only if clean AND an upstream is configured).
# A missing upstream or offline remote must NOT abort the local-config update,
# so this step is best-effort (warn, never fail).
step "git pull --ff-only (if clean + upstream set)"
if [[ -d "$REPO_ROOT/.git" ]]; then
  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    warn "worktree dirty; skipping git pull (commit/stash first to update the repo)"
  elif ! git -C "$REPO_ROOT" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    warn "no upstream tracking branch; skipping git pull (set one with: git branch --set-upstream-to=origin/main)"
  elif [[ "$MODE" == "report" ]]; then
    printf '   would run: git -C %s pull --ff-only\n' "$REPO_ROOT"
  else
    log "+ git pull --ff-only"
    git -C "$REPO_ROOT" pull --ff-only || warn "git pull failed (offline or diverged); continuing with local config"
  fi
fi

# 2 + 3. refresh + validate flake inputs
step "nix flake update + check"
have nix || fail "nix not on PATH"
run nix flake update "$REPO_ROOT/nix"
run nix flake check "$REPO_ROOT/nix"

# 4. dotfiles
step "chezmoi apply"
have chezmoi || fail "chezmoi not on PATH"
if [[ "$MODE" == "apply" && -x "$REPO_ROOT/scripts/snapshot-home.sh" ]]; then
  run bash "$REPO_ROOT/scripts/snapshot-home.sh"
fi
run chezmoi apply --force

# 5. system/user generation
step "home-manager / darwin-rebuild switch"
if [[ "$HOST_PROFILE" == "macos" ]]; then
  have darwin-rebuild || fail "darwin-rebuild not on PATH"
  run darwin-rebuild switch --flake "$REPO_ROOT/nix#macos"
else
  have home-manager || fail "home-manager not on PATH"
  run home-manager switch --flake "$REPO_ROOT/nix#$HOST_PROFILE"
fi

# 6. nix-profile base tools
step "nix profile upgrade"
run nix profile upgrade --all

# 7. mise tool versions (no-op when runtimes come from Nix)
step "mise upgrade"
if have mise; then run mise upgrade; else warn "mise not on PATH (skip)"; fi

# 8. hooks
step "lefthook install"
if have lefthook && [[ -d "$REPO_ROOT/.git" ]]; then
  run sh -c "cd '$REPO_ROOT' && lefthook install"
fi

# 9. cleanup (safe mode), unless disabled
step "cleanup (safe)"
if [[ "${NO_CLEANUP:-0}" == 1 ]]; then
  log "NO_CLEANUP=1 set; skipping cleanup"
elif [[ -x "$REPO_ROOT/scripts/cleanup.sh" ]]; then
  if [[ "$MODE" == "apply" ]]; then
    bash "$REPO_ROOT/scripts/cleanup.sh" --apply --yes || warn "cleanup returned non-zero"
  else
    log "would run: bash scripts/cleanup.sh --apply --yes"
  fi
else
  warn "scripts/cleanup.sh not found (skip)"
fi

step "Done"
log "All updates complete."
[[ "$MODE" == "report" ]] && log "Re-run with --apply to actually update."
exit 0
