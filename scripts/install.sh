#!/usr/bin/env bash
# Fully-automated, unattended, idempotent installer for the chezmoi + mise +
# Nix/Home-Manager + Lefthook stack. Run it once and walk away.
#
# Unlike scripts/bootstrap.sh (which defaults to a dry-run and prompts before
# chezmoi apply), this script is non-interactive by design: it auto-confirms,
# is NixOS-aware (it will NOT run the Determinate Systems Nix installer when
# Nix is already system-owned), and snapshots $HOME before any chezmoi apply.
#
# It is idempotent: re-running installs only what is missing and re-applies the
# declared state. Every step is logged. Any required step that fails aborts
# with a non-zero exit and a clear [install:error] line.
#
# Tools handled, in order:
#   1. preflight: required commands present
#   2. nix          (skipped on NixOS; Determinate installer only on non-NixOS)
#   3. base tools   (chezmoi, mise, home-manager, lefthook via nix profile)
#   4. nix flake check ./nix
#   5. chezmoi init + snapshot $HOME + chezmoi apply --force
#   6. home-manager switch  OR  darwin-rebuild switch  (per host)
#   7. mise trust + mise install   (runtimes come from Nix on NixOS; near no-op)
#   8. lefthook install
#   9. ssh-agent-setup.sh (non-WSL)
#  10. doctor.sh (must pass)
#
# Usage:
#   bash scripts/install.sh                 # full unattended install
#   DRY_RUN=1 bash scripts/install.sh       # show what would happen, mutate nothing
#   HOST_PROFILE=linux-cli bash scripts/install.sh
#
# Exit codes: 0 on success; non-zero on the first required-step failure.

set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log()  { printf '[install] %s\n' "$*"; }
step() { printf '\n[install] ── %s ──\n' "$*"; }
warn() { printf '[install:warn] %s\n' "$*" >&2; }
fail() { printf '[install:error] %s\n' "$*" >&2; exit 1; }
run()  {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[install:dry-run] would run: %s\n' "$*"
  else
    log "+ $*"
    "$@"
  fi
}

is_nixos() { [[ -f /etc/NIXOS ]] || grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; }
have()     { command -v "$1" >/dev/null 2>&1; }

# ── 1. preflight ────────────────────────────────────────────────────────────
step "Preflight"
for cmd in git bash; do
  have "$cmd" || fail "missing required command: $cmd"
done
HOST_PROFILE="${HOST_PROFILE:-$(bash "$REPO_ROOT/scripts/detect-host.sh")}"
case "$HOST_PROFILE" in
  macos|linux-desktop|linux-cli|wsl) ;;
  *) fail "unsupported HOST_PROFILE: $HOST_PROFILE" ;;
esac
log "Repo:  $REPO_ROOT"
log "Host:  $HOST_PROFILE"
log "NixOS: $(is_nixos && echo yes || echo no)"
log "Mode:  $([[ "$DRY_RUN" == 1 ]] && echo dry-run || echo APPLY)"

# Identity file must exist (chezmoi + flake need it). Create from example if
# missing so the install can proceed unattended with placeholder values; the
# user can refine later.
if [[ ! -f "$REPO_ROOT/home/.chezmoidata/personal.yaml" ]]; then
  if [[ -f "$REPO_ROOT/home/personal.yaml.example" ]]; then
    warn "home/.chezmoidata/personal.yaml missing; seeding from example (edit later)."
    run mkdir -p "$REPO_ROOT/home/.chezmoidata"
    [[ "$DRY_RUN" == 1 ]] || cp "$REPO_ROOT/home/personal.yaml.example" \
      "$REPO_ROOT/home/.chezmoidata/personal.yaml"
  else
    fail "no personal.yaml and no example to seed from"
  fi
fi

# ── 2. Nix ──────────────────────────────────────────────────────────────────
step "Nix"
if have nix; then
  log "nix present: $(nix --version 2>/dev/null | head -n1)"
elif is_nixos; then
  fail "NixOS but 'nix' not on PATH — open a login shell and re-run"
else
  warn "Nix not found; installing via Determinate Systems installer (non-NixOS)."
  run sh -c "curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm"
fi

# Refresh PATH so freshly installed nix-profile tools are visible.
for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
         "$HOME/.nix-profile/etc/profile.d/nix.sh" /etc/profile.d/nix.sh; do
  # shellcheck disable=SC1090
  [[ -r "$f" ]] && . "$f" || true
done
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
have nix || { [[ "$DRY_RUN" == 1 ]] || fail "nix still not on PATH after install"; }

# ── 3. base tools ───────────────────────────────────────────────────────────
step "Base tools (chezmoi, mise, home-manager, lefthook)"
missing_base=()
for t in chezmoi mise home-manager lefthook; do have "$t" || missing_base+=("$t"); done
if (( ${#missing_base[@]} )); then
  run nix profile install \
    nixpkgs#chezmoi nixpkgs#mise nixpkgs#home-manager nixpkgs#lefthook
else
  log "base tools already present"
fi

# ── 4. flake check ──────────────────────────────────────────────────────────
step "Validate flake"
run nix flake check "$REPO_ROOT/nix"

# ── 5. chezmoi ──────────────────────────────────────────────────────────────
step "chezmoi (init + snapshot + apply)"
run chezmoi init --source="$REPO_ROOT"
if [[ "$DRY_RUN" == 1 ]]; then
  run sh -c "chezmoi diff || true"
  log "would: snapshot \$HOME then chezmoi apply --force"
else
  [[ -x "$REPO_ROOT/scripts/snapshot-home.sh" ]] \
    || fail "scripts/snapshot-home.sh missing or not executable"
  run bash "$REPO_ROOT/scripts/snapshot-home.sh"
  # --force: unattended. The snapshot above is the rollback safety net.
  run chezmoi apply --force
fi

# ── 6. Home Manager / nix-darwin ────────────────────────────────────────────
step "Home Manager / nix-darwin switch"
if [[ "$HOST_PROFILE" == "macos" ]]; then
  run darwin-rebuild switch --flake "$REPO_ROOT/nix#macos"
else
  run home-manager switch --flake "$REPO_ROOT/nix#$HOST_PROFILE"
fi

# ── 7. mise ─────────────────────────────────────────────────────────────────
step "mise (trust + install)"
run mise trust "$REPO_ROOT"
# On NixOS runtimes come from Nix; this is typically "all tools are installed".
run mise install

# ── 8. lefthook ─────────────────────────────────────────────────────────────
step "lefthook (git hooks)"
if [[ -d "$REPO_ROOT/.git" ]]; then
  run sh -c "cd '$REPO_ROOT' && lefthook install"
else
  warn "no .git dir; skipping lefthook install"
fi

# ── 9. ssh-agent helper (non-WSL) ───────────────────────────────────────────
step "ssh-agent helper"
if [[ "$HOST_PROFILE" != "wsl" ]] && [[ -x "$REPO_ROOT/scripts/unix/ssh-agent-setup.sh" ]]; then
  if [[ "$DRY_RUN" == 1 ]]; then
    log "would: bash scripts/unix/ssh-agent-setup.sh"
  else
    bash "$REPO_ROOT/scripts/unix/ssh-agent-setup.sh" || warn "ssh-agent-setup returned non-zero (review)"
  fi
else
  log "skipped (WSL or helper absent)"
fi

# ── 10. doctor ──────────────────────────────────────────────────────────────
step "doctor (health check)"
if [[ "$DRY_RUN" == 1 ]]; then
  log "would: bash scripts/doctor.sh"
else
  run bash "$REPO_ROOT/scripts/doctor.sh"
fi

step "Done"
log "Install complete (host=$HOST_PROFILE, mode=$([[ "$DRY_RUN" == 1 ]] && echo dry-run || echo apply))."
if is_nixos; then
  log "NixOS note: to make fish your login shell, see docs/install-nixos.md"
  log "Keep things tidy with: bash scripts/update-all.sh   and   bash scripts/cleanup.sh"
fi
