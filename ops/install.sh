#!/usr/bin/env bash
# Fully-automated, unattended, idempotent installer for the chezmoi + mise +
# Nix/Home-Manager + Lefthook stack. Run it once and walk away.
#
# Unlike ops/bootstrap.sh (which defaults to a dry-run and prompts before
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
#   8. VS Code extensions (if code CLI is present)
#   9. lefthook install
#  10. ssh-agent-setup.sh (non-WSL)
#  11. doctor.sh (must pass)
#
# Usage:
#   bash ops/install.sh                 # full unattended install
#   bash ops/install.sh --dry-run       # show what would happen, mutate nothing
#   DRY_RUN=1 bash ops/install.sh       # same as --dry-run
#   HOST_PROFILE=linux-cli bash ops/install.sh
#
# Exit codes: 0 on success; non-zero on the first required-step failure.

set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Arguments. sys-install passes "$@" through; before this parser existed,
# `sys-install --dry-run` silently ran the full install.
while (($#)); do
  case "$1" in
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      sed -n '2,/^# Exit codes/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf '[install:error] unknown argument: %s (try --help)\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

# DRY_RUN is a switch, not a truthy string: DRY_RUN=true used to mean "apply".
case "$DRY_RUN" in
  0 | 1) ;;
  *)
    printf '[install:error] DRY_RUN must be 0 or 1 (got: %s)\n' "$DRY_RUN" >&2
    exit 2
    ;;
esac

# shellcheck source=ops/lib/preflight.sh
source "$REPO_ROOT/ops/lib/preflight.sh"

# Test guard (ops/lib/preflight.sh): under bats, never mutate the real home or
# the real repository.
[[ "$DRY_RUN" == 1 ]] || preflight_bats_guard install "a real install" "$REPO_ROOT"

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

# shellcheck source=ops/lib/hm-switch.sh
source "$REPO_ROOT/ops/lib/hm-switch.sh"

is_nixos() { [[ -f /etc/NIXOS ]] || grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; }
have()     { command -v "$1" >/dev/null 2>&1; }

# ── 1. preflight ────────────────────────────────────────────────────────────
step "Preflight"
for cmd in git bash; do
  have "$cmd" || fail "missing required command: $cmd"
done
HOST_PROFILE="${HOST_PROFILE:-$(bash "$REPO_ROOT/ops/detect-host.sh")}"
case "$HOST_PROFILE" in
  macos|linux-desktop|linux-cli|wsl) ;;
  *) fail "unsupported HOST_PROFILE: $HOST_PROFILE" ;;
esac
preflight_host_checks "$REPO_ROOT" "$HOST_PROFILE"
log "Repo:  $REPO_ROOT"
log "Host:  $HOST_PROFILE"
log "NixOS: $(is_nixos && echo yes || echo no)"
log "Mode:  $([[ "$DRY_RUN" == 1 ]] && echo dry-run || echo APPLY)"

preflight_personal_yaml "$REPO_ROOT" "$HOST_PROFILE" run

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

preflight_refresh_nix_path
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
  [[ -x "$REPO_ROOT/ops/snapshot-home.sh" ]] \
    || fail "ops/snapshot-home.sh missing or not executable"
  run bash "$REPO_ROOT/ops/snapshot-home.sh"
  # --force: unattended. The snapshot above is the rollback safety net.
  run chezmoi apply --force
fi

# ── 6. Home Manager / nix-darwin ────────────────────────────────────────────
step "Home Manager / nix-darwin switch"
if [[ "$HOST_PROFILE" == "macos" ]]; then
  run darwin-rebuild switch --flake "$REPO_ROOT/nix#macos"
else
  if [[ "$DRY_RUN" == 1 ]]; then
    run "$(hm_switch_describe "$REPO_ROOT/nix" "$HOST_PROFILE")"
  else
    # Conflict check, then `home-manager switch -b hm-bak` (ops/lib/hm-switch.sh).
    log "+ $(hm_switch_describe "$REPO_ROOT/nix" "$HOST_PROFILE")"
    hm_switch "$REPO_ROOT/nix" "$HOST_PROFILE" || fail "home-manager switch failed"
  fi
fi

# ── 7. mise ─────────────────────────────────────────────────────────────────
step "mise (trust + install)"
run mise trust "$REPO_ROOT"
# On NixOS runtimes come from Nix; this is typically "all tools are installed".
run mise install

# ── 8. VS Code extensions ───────────────────────────────────────────────────
step "VS Code extensions"
if [[ -x "$REPO_ROOT/ops/vscode-extensions.sh" ]]; then
  if [[ "$DRY_RUN" == 1 ]]; then
    run bash "$REPO_ROOT/ops/vscode-extensions.sh" --dry-run
  else
    # Optional step: one failed extension must not abort lefthook and doctor.
    run bash "$REPO_ROOT/ops/vscode-extensions.sh" \
      || warn "VS Code extensions: ops/vscode-extensions.sh failed; re-run it after install"
  fi
else
  warn "ops/vscode-extensions.sh missing or not executable; skipping"
fi

# ── 8b. Syncthing Obsidian .stignore (Linux personal profile) ───────────────
# Stops Syncthing from syncing .obsidian folders by installing the repo-tracked
# managed .stignore block into configured Syncthing folders. The helper is a
# safe no-op when Syncthing folders do not exist yet, so this step never blocks
# the install. Folder config stays user-owned in the Web UI.
step "Syncthing Obsidian global .stignore"
if [[ -x "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh" ]]; then
  if [[ "$DRY_RUN" == 1 ]]; then
    run bash "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh"
  else
    bash "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh" --apply \
      || warn "syncthing-obsidian-stignore returned non-zero (review)"
  fi
else
  warn "ops/syncthing-obsidian-stignore.sh missing or not executable; skipping"
fi

# ── 9. lefthook ─────────────────────────────────────────────────────────────
step "lefthook (git hooks)"
if [[ -e "$REPO_ROOT/.git" ]]; then
  # The path is an argument ($1), never part of the script text, so quotes or
  # shell syntax in it cannot break or inject (same form as update-all.sh).
  run sh -c 'cd "$1" && lefthook install' sh "$REPO_ROOT"
else
  warn "not a git checkout; skipping lefthook install"
fi

# ── 10. ssh-agent helper (non-WSL) ──────────────────────────────────────────
step "ssh-agent helper"
if [[ "$HOST_PROFILE" != "wsl" ]] && [[ -x "$REPO_ROOT/ops/unix/ssh-agent-setup.sh" ]]; then
  if [[ "$DRY_RUN" == 1 ]]; then
    log "would: bash ops/unix/ssh-agent-setup.sh"
  else
    bash "$REPO_ROOT/ops/unix/ssh-agent-setup.sh" || warn "ssh-agent-setup returned non-zero (review)"
  fi
else
  log "skipped (WSL or helper absent)"
fi

# ── 11. doctor ──────────────────────────────────────────────────────────────
step "doctor (health check)"
if [[ "$DRY_RUN" == 1 ]]; then
  log "would: bash ops/doctor.sh"
else
  run bash "$REPO_ROOT/ops/doctor.sh"
fi

step "Done"
log "Install complete (host=$HOST_PROFILE, mode=$([[ "$DRY_RUN" == 1 ]] && echo dry-run || echo apply))."

# ── NixOS system-rebuild advisory (NOT run automatically — needs sudo) ───────
# The user environment is fully installed above. System-level settings (fish
# login shell, trusted-users, GC timer) live in /etc/nixos and require an
# explicit, privileged `nixos-rebuild`. We never run sudo unattended; instead we
# detect what is missing and print exact next steps. See docs/platforms/nixos/rebuild.md.
if is_nixos; then
  step "NixOS system layer (live-state check)"
  # Check the LIVE activated system, not a specific config file — settings may
  # live in /etc/nixos/app-configs-extra.nix (written by sys-setup) rather than
  # configuration.nix.
  need_rebuild=0
  # getent is not on every PATH (minimal envs); fall back to $SHELL rather
  # than dying under set -e after the install already finished.
  cur_shell="$({ getent passwd "$(id -un)" 2>/dev/null || true; } | cut -d: -f7)"
  cur_shell="${cur_shell:-${SHELL:-unknown}}"
  [[ "$cur_shell" == *fish* ]] || { warn "fish is not yet the system login shell (now: $cur_shell)"; need_rebuild=1; }
  nix show-config 2>/dev/null | grep -qE "trusted-users\s*=.*\b$(id -un)\b" \
    || { warn "your user is not in nix trusted-users (auto-optimise warning)"; need_rebuild=1; }
  { systemctl is-active nix-gc.timer >/dev/null 2>&1 || systemctl is-active nix-optimise.timer >/dev/null 2>&1; } \
    || { warn "no active system-level nix.gc/optimise timer"; need_rebuild=1; }
  cur_timezone="$(bash "$REPO_ROOT/ops/detect-timezone.sh")"
  [[ "$cur_timezone" == "Europe/London" ]] \
    || { warn "system time zone is ${cur_timezone:-unknown}, not Europe/London"; need_rebuild=1; }

  if [[ "$need_rebuild" == 1 ]]; then
    log "To finish system setup, run the automated helper:"
    log "    sudo bash $REPO_ROOT/ops/system-setup.sh --apply   (alias: sudo sys-setup --apply)"
    log "It writes /etc/nixos/app-configs-extra.nix, wires it in, and runs nixos-rebuild."
    log "Then open a NEW terminal (reboot only if a kernel/driver changed)."
    log "Confirm:  sys-readiness   (or: nixos-rebuild list-generations | head ; systemctl --failed)"
  else
    log "System layer already active (fish login shell + trusted-users + GC timer). Nothing to do."
  fi

  step "Maintenance"
  log "Update everything (brewup):  mise run update:apply"
  log "Safe cleanup (keep rollbacks): mise run cleanup:apply"
  log "See docs/getting-started/install.md and docs/platforms/nixos/rebuild.md."
fi
