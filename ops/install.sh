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
#   DRY_RUN=1 bash ops/install.sh       # same as --dry-run (DRY_RUN must be 0 or 1)
#   HOST_PROFILE=linux-cli bash ops/install.sh
#
# Exit codes:
#   0  success, or finished with degraded steps (listed instead of
#      "Install complete": VS Code, Syncthing, ssh-agent, a pending NixOS
#      system rebuild)
#   1  a required-step failure ([install:error]); an external command that
#      fails exits with its own code
#   2  bad argument, or DRY_RUN is not 0 or 1
#   3  refused: a bats test tried a real install against the real HOME
#
# macOS apply needs sudo (nix-darwin switch); it is checked before anything
# changes. On Linux and WSL install.sh itself runs no sudo, but the Nix
# installer may ask for it on a fresh non-NixOS host.

set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Arguments. sys-install passes "$@" through; before this parser existed,
# `sys-install --dry-run` silently ran the full install.
while (($#)); do
  case "$1" in
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      sed -n '2,/^$/{/^$/!p;}' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
    local rc=0
    "$@" || rc=$?
    # An external failure must end in the same [install:error] line as our own.
    ((rc == 0)) || { printf '[install:error] command failed (exit %s): %s\n' "$rc" "$*" >&2; exit "$rc"; }
  fi
}

# shellcheck source=ops/lib/hm-switch.sh
source "$REPO_ROOT/ops/lib/hm-switch.sh"

# INSTALL_NIXOS_MARKER / INSTALL_OS_RELEASE are test seams (same idea as the
# DETECT_HOST_* overrides in ops/detect-host.sh).
is_nixos() {
  [[ -f "${INSTALL_NIXOS_MARKER:-/etc/NIXOS}" ]] \
    || grep -qi '^ID=nixos' "${INSTALL_OS_RELEASE:-/etc/os-release}" 2>/dev/null
}
have()     { command -v "$1" >/dev/null 2>&1; }

# Optional steps may fail without aborting; each failure is recorded here and
# listed in the final summary, so a partial install never ends in "Install
# complete" (same idea as DEGRADED in ops/bootstrap.sh).
DEGRADED=()
degrade() { DEGRADED+=("$1"); warn "$2"; }

# Temp files and dirs created below, removed on exit.
CLEANUP=()
cleanup() { ((${#CLEANUP[@]} == 0)) || rm -rf -- "${CLEANUP[@]}"; }
trap cleanup EXIT

# ── 1. preflight ────────────────────────────────────────────────────────────
step "Preflight"
for cmd in git bash; do
  have "$cmd" || fail "missing required command: $cmd"
done
if [[ -z "${HOST_PROFILE:-}" ]]; then
  HOST_PROFILE="$(bash "$REPO_ROOT/ops/detect-host.sh")" \
    || fail "ops/detect-host.sh failed; set HOST_PROFILE explicitly"
fi
case "$HOST_PROFILE" in
  macos|linux-desktop|linux-cli|wsl) ;;
  *) fail "unsupported HOST_PROFILE: $HOST_PROFILE" ;;
esac
# macOS switches via sudo: fail now, before any mutation, not halfway through
# (same check as ops/bootstrap.sh). A dry run never asks.
if [[ "$DRY_RUN" != 1 && "$HOST_PROFILE" == macos ]]; then
  if [[ -t 0 ]]; then
    sudo -v || fail "macOS switch needs sudo; authentication failed"
  else
    sudo -n true || fail "macOS switch needs sudo; run on a TTY or configure sudo"
  fi
fi
# WSL1 refusal and the login-user check live in ops/lib/preflight.sh (shared
# with bootstrap). Nix may not be installed yet (fresh machine): the
# authoritative user check then runs right after the Nix step, once Nix exists.
# Until then a best-effort sed match only warns, before anything is written.
USER_CHECKED=0
if have nix; then
  preflight_ensure_nix_features
  USER_CHECKED=1
fi
preflight_host_checks "$REPO_ROOT" "$HOST_PROFILE" warn
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
  # Download to a file, then run it. In `curl | sh` a failed download is hidden
  # by the pipe (sh just reads an empty script and exits 0).
  if [[ "$DRY_RUN" == 1 ]]; then
    nix_installer="${TMPDIR:-/tmp}/nix-installer.XXXXXX"
  else
    nix_installer="$(mktemp)" || fail "cannot create a temp file for the Nix installer"
    CLEANUP+=("$nix_installer")
  fi
  run curl --proto '=https' --tlsv1.2 -sSfL -o "$nix_installer" https://install.determinate.systems/nix
  run sh "$nix_installer" install --no-confirm
fi

# Test seams INSTALL_NIX_DEFAULT_PROFILE / INSTALL_ETC_PROFILE_D / NIX_PATH_REFRESH=0
# are honoured inside preflight_refresh_nix_path (ops/lib/preflight.sh).
preflight_refresh_nix_path
have nix || { [[ "$DRY_RUN" == 1 ]] || fail "nix still not on PATH after install"; }
if ((USER_CHECKED == 0)); then
  if have nix; then
    preflight_ensure_nix_features
    preflight_check_login_user "$REPO_ROOT"
  else
    warn "nix is not installed (dry-run); the login-user check will run after a real install"
  fi
fi

preflight_ensure_nix_features   # no-op when the preflight already did it

# ── 3. base tools ───────────────────────────────────────────────────────────
step "Base tools (chezmoi, mise, home-manager, lefthook)"
# Install only what is missing: re-installing a tool that is already in the
# profile (or provided another way) makes `nix profile install` conflict.
missing_base=()
for t in chezmoi mise home-manager lefthook; do have "$t" || missing_base+=("nixpkgs#$t"); done
if (( ${#missing_base[@]} )); then
  run nix profile install "${missing_base[@]}"
else
  log "base tools already present"
fi

# ── 4. flake check ──────────────────────────────────────────────────────────
step "Validate flake"
run nix flake check "$REPO_ROOT/nix"

# ── 5. chezmoi ──────────────────────────────────────────────────────────────
step "chezmoi (init + snapshot + apply)"
# `chezmoi init --source` does not persist the source directory, so every later
# chezmoi call must carry --source too; otherwise diff/managed/apply read
# ~/.local/share/chezmoi instead of this checkout.
run chezmoi init --source="$REPO_ROOT"
if [[ "$DRY_RUN" == 1 ]]; then
  run sh -c 'chezmoi --source="$1" diff || true' sh "$REPO_ROOT"
  log "would: snapshot \$HOME then chezmoi apply --force"
else
  [[ -x "$REPO_ROOT/ops/snapshot-home.sh" ]] \
    || fail "ops/snapshot-home.sh missing or not executable"
  # snapshot-home.sh runs `chezmoi managed` itself, so give it a chezmoi that
  # always carries --source. The shim text is constant; the paths travel in
  # the environment, never inside the script.
  chezmoi_shim="$(mktemp -d)" || fail "cannot create a temp dir"
  CLEANUP+=("$chezmoi_shim")
  # shellcheck disable=SC2016  # the shim must expand these when it runs
  printf '%s\n' '#!/bin/sh' 'exec "$INSTALL_REAL_CHEZMOI" --source="$INSTALL_REPO_ROOT" "$@"' >"$chezmoi_shim/chezmoi"
  chmod +x "$chezmoi_shim/chezmoi"
  INSTALL_REAL_CHEZMOI="$(command -v chezmoi)" INSTALL_REPO_ROOT="$REPO_ROOT" PATH="$chezmoi_shim:$PATH" \
    run bash "$REPO_ROOT/ops/snapshot-home.sh"
  # --force: unattended. The snapshot above is the rollback safety net.
  run chezmoi --source="$REPO_ROOT" apply --force
fi

# ── 6. Home Manager / nix-darwin ────────────────────────────────────────────
step "Home Manager / nix-darwin switch"
if [[ "$HOST_PROFILE" == "macos" ]]; then
  # Same approach as ops/bootstrap.sh: the switch needs root, and darwin-rebuild
  # does not exist on a first run, so use the pinned flake output instead.
  # sudo resets the environment, so NIX_CONFIG (the features enabled earlier)
  # does not reach it: pass the features on the command line. darwin-rebuild
  # adds them itself (flakeFlags in nix-darwin's darwin-rebuild.sh).
  if have darwin-rebuild; then
    run sudo darwin-rebuild switch --flake "$REPO_ROOT/nix#macos"
  else
    run sudo nix --extra-experimental-features 'nix-command flakes' run "$REPO_ROOT/nix#darwin-rebuild" -- switch --flake "$REPO_ROOT/nix#macos"
  fi
else
  if [[ "$DRY_RUN" == 1 ]]; then
    run "$(hm_switch_describe "$REPO_ROOT/nix" "$HOST_PROFILE")"
  else
    # Conflict check, then `home-manager switch -b hm-bak` (ops/lib/hm-switch.sh).
    log "+ $(hm_switch_describe "$REPO_ROOT/nix" "$HOST_PROFILE")"
    # The switch's own exit code is kept, like run() does for the other steps.
    hm_rc=0
    hm_switch "$REPO_ROOT/nix" "$HOST_PROFILE" || hm_rc=$?
    ((hm_rc == 0)) || {
      printf '[install:error] command failed (exit %s): %s\n' "$hm_rc" "$(hm_switch_describe "$REPO_ROOT/nix" "$HOST_PROFILE")" >&2
      exit "$hm_rc"
    }
  fi
fi

# ── 7. mise ─────────────────────────────────────────────────────────────────
step "mise (trust + install)"
run mise trust "$REPO_ROOT"
# On NixOS runtimes come from Nix; this is typically "all tools are installed".
run sh -c 'cd "$1" && mise install' sh "$REPO_ROOT"

# ── 8. VS Code extensions ───────────────────────────────────────────────────
step "VS Code extensions"
if [[ -x "$REPO_ROOT/ops/vscode-extensions.sh" ]]; then
  if [[ "$DRY_RUN" == 1 ]]; then
    run bash "$REPO_ROOT/ops/vscode-extensions.sh" --dry-run
  else
    # Optional step: one failed extension must not abort lefthook and doctor.
    # Not run(): run() exits on failure and this step is only a warning.
    log "+ bash $REPO_ROOT/ops/vscode-extensions.sh"
    bash "$REPO_ROOT/ops/vscode-extensions.sh" \
      || degrade "VS Code extensions (re-run: bash ops/vscode-extensions.sh)" \
           "VS Code extensions: ops/vscode-extensions.sh failed; re-run it after install"
  fi
else
  warn "ops/vscode-extensions.sh missing or not executable; skipping"
fi

# ── 8b. Syncthing Obsidian .stignore (Linux personal profile) ───────────────
# Stops Syncthing from syncing .obsidian folders by installing the repo-tracked
# managed .stignore block into configured Syncthing folders. The helper is a
# safe no-op when Syncthing folders do not exist yet, so this step never blocks
# the install. Folder config stays user-owned in the Web UI. Linux only: the
# helper writes Linux Syncthing paths, so macOS skips it.
step "Syncthing Obsidian global .stignore"
if [[ "$HOST_PROFILE" == macos ]]; then
  log "skipped (Linux-only helper; host is macOS)"
elif [[ -x "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh" ]]; then
  if [[ "$DRY_RUN" == 1 ]]; then
    run bash "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh"
  else
    bash "$REPO_ROOT/ops/syncthing-obsidian-stignore.sh" --apply \
      || degrade "Syncthing .stignore (re-run: bash ops/syncthing-obsidian-stignore.sh --apply)" \
           "syncthing-obsidian-stignore returned non-zero (review)"
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
    bash "$REPO_ROOT/ops/unix/ssh-agent-setup.sh" \
      || degrade "ssh-agent-setup (re-run: bash ops/unix/ssh-agent-setup.sh)" \
           "ssh-agent-setup returned non-zero (review)"
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

# ── NixOS system-rebuild advisory (NOT run automatically — needs sudo) ───────
# The user environment is fully installed above. System-level settings (fish
# login shell, GC timer, time zone) live in /etc/nixos and require an
# explicit, privileged `nixos-rebuild`. On NixOS we never run sudo unattended; instead we
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
  # install.sh itself neither checks nor recommends trusted-users: a trusted
  # user can act as root through the Nix daemon. The remaining risk is outside
  # this file: the sys-setup helper recommended below (ops/system-setup.sh)
  # still manages that setting, and that is a separate decision.
  # nix-optimise.timer only dedups the store; it does not collect garbage.
  systemctl is-active nix-gc.timer >/dev/null 2>&1 \
    || { warn "system nix-gc.timer is not active (nix-optimise.timer alone does not collect garbage)"; need_rebuild=1; }
  cur_timezone="$(bash "$REPO_ROOT/ops/detect-timezone.sh" 2>/dev/null || true)"
  [[ "$cur_timezone" == "Europe/London" ]] \
    || { warn "system time zone is ${cur_timezone:-unknown}, not Europe/London"; need_rebuild=1; }

  if [[ "$need_rebuild" == 1 ]]; then
    DEGRADED+=("system layer (run: sudo bash $REPO_ROOT/ops/system-setup.sh --apply)")
    log "To finish system setup, run the automated helper:"
    log "    sudo bash $REPO_ROOT/ops/system-setup.sh --apply   (alias: sudo sys-setup --apply)"
    log "It writes /etc/nixos/app-configs-extra.nix, wires it in, and runs nixos-rebuild."
    log "Then open a NEW terminal (reboot only if a kernel/driver changed)."
    log "Confirm:  sys-readiness   (or: nixos-rebuild list-generations | head ; systemctl --failed)"
  else
    log "System layer already active (fish login shell + GC timer + time zone). Nothing to do."
  fi

  step "Maintenance"
  log "Update everything (brewup):  mise run update:apply"
  log "Safe cleanup (keep rollbacks): mise run cleanup:apply"
  log "See docs/getting-started/install.md and docs/platforms/nixos/rebuild.md."
fi

# ── Summary ─────────────────────────────────────────────────────────────────
# Printed last, after every step and the NixOS advisory, so "complete" is only
# claimed when nothing was degraded.
step "Done"
if [[ "$DRY_RUN" == 1 ]]; then
  log "Dry run finished; nothing was changed. Re-run without --dry-run to apply."
elif ((${#DEGRADED[@]} > 0)); then
  log "finished with degraded steps (not a clean success):"
  for degraded_step in "${DEGRADED[@]}"; do
    log "  degraded: $degraded_step"
  done
else
  log "Install complete (host=$HOST_PROFILE, mode=apply)."
fi
