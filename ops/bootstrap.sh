#!/usr/bin/env bash
# Cold-start bootstrap for macOS / Linux desktop / Linux CLI / WSL2.
#
# Defaults to --dry-run (no mutations). Pass --yes or --apply to actually
# install and apply. CI=true allows non-interactive apply.
#
# Tools handled (in order):
#   1. nix          (Determinate Systems installer)
#   2. chezmoi, mise, home-manager, lefthook   (nix profile install)
#   3. nix flake check ./nix
#   4. chezmoi init + diff + apply             (snapshot first)
#   5. home-manager switch  OR darwin-rebuild switch (per host)
#   6. mise install
#   7. VS Code extensions (if code CLI is present)
#   8. lefthook install
#   9. ops/unix/ssh-agent-setup.sh         (skipped on WSL)
#  10. ops/doctor.sh                       (must pass)
#
# Usage:
#   bash ops/bootstrap.sh                  # dry-run, default
#   bash ops/bootstrap.sh --dry-run
#   bash ops/bootstrap.sh --yes            # actually mutate
#   HOST_PROFILE=wsl bash ops/bootstrap.sh --dry-run
#   HOST_PROFILE_DEFAULT=linux-cli bash ops/bootstrap.sh
#   CI=true bash ops/bootstrap.sh --yes    # non-interactive
#
# Exits non-zero on any required step failure.

set -euo pipefail

MODE="${MODE:-dry-run}"
for arg in "$@"; do
  case "$arg" in
    --dry-run)        MODE="dry-run" ;;
    --yes|--apply)    MODE="apply" ;;
    -h|--help)
      sed -n '2,29p' "$0"
      exit 0
      ;;
    *)
      printf '[bootstrap] unknown arg: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

log()  { printf '[bootstrap:%s] %s\n' "$MODE" "$*"; }
fail() { printf '[bootstrap:error] %s\n' "$*" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_PROFILE="${HOST_PROFILE:-$(bash "$REPO_ROOT/ops/detect-host.sh")}"

log "Repo: $REPO_ROOT"
log "Host: $HOST_PROFILE"

case "$HOST_PROFILE" in
  macos|linux-desktop|linux-cli|wsl) ;;
  unsupported) fail "Unsupported OS" ;;
  *) fail "Unsupported HOST_PROFILE: $HOST_PROFILE" ;;
esac

for cmd in git bash curl; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
done

interactive_confirm() {
  local question="$1"
  local ci_flag="${CI:-}"
  # Auto-confirm when CI is set OR stdin is not a TTY. Both branches must
  # use the :-default form: `set -u` would otherwise abort on a plain
  # `$CI` reference whenever the caller is non-interactive without CI=
  # exported (e.g. local automation, cron, an opencode session).
  if [[ -n "$ci_flag" ]] || [[ ! -t 0 ]]; then
    log "Non-interactive (CI=${ci_flag:-<unset>} or no tty); auto-confirming: $question"
    return 0
  fi
  printf '%s [y/N] ' "$question"
  local ans
  read -r ans
  [[ "$ans" = "y" || "$ans" = "Y" ]]
}

# ─── 1. Nix ──────────────────────────────────────────────────────────────────
if ! command -v nix >/dev/null 2>&1; then
  if [[ "$MODE" == "dry-run" ]]; then
    log "would: install Nix (Determinate Systems installer)"
  else
    log "Installing Nix (Determinate Systems installer)…"
    curl --proto '=https' --tlsv1.2 -sSf -L \
      https://install.determinate.systems/nix \
      | sh -s -- install --no-confirm
  fi
else
  log "nix: $(nix --version 2>/dev/null | head -n1)"
fi

# Refresh PATH for the current process so the rest of the bootstrap can
# see freshly installed nix-profile tools.
for source_file in \
  /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
  "$HOME/.nix-profile/etc/profile.d/nix.sh" \
  /etc/profile.d/nix.sh; do
  # shellcheck disable=SC1090
  [[ -r "$source_file" ]] && . "$source_file" || true
done
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

have_nix=false
command -v nix >/dev/null 2>&1 && have_nix=true

# ─── 2. Base tools via nix profile ──────────────────────────────────────────
if [[ "$MODE" == "dry-run" ]]; then
  if $have_nix; then
    log "would: nix profile install nixpkgs#{chezmoi,mise,home-manager,lefthook}"
  else
    log "missing nix; in --yes mode would install Nix first, then base tools"
  fi
else
  $have_nix || fail "nix install completed but 'nix' is still not on PATH (open a new shell and re-run)"
  log "Installing base tools via nix profile…"
  nix profile install \
    nixpkgs#chezmoi \
    nixpkgs#mise \
    nixpkgs#home-manager \
    nixpkgs#lefthook
  for cmd in chezmoi mise home-manager lefthook; do
    command -v "$cmd" >/dev/null 2>&1 \
      || fail "expected '$cmd' on PATH after nix profile install"
  done
fi

# ─── 3. Validate flake ──────────────────────────────────────────────────────
if $have_nix; then
  log "Validating nix flake (./nix)…"
  nix flake check "$REPO_ROOT/nix"
else
  log "skipping flake validation: nix not yet installed (in --yes mode it will be)"
fi

# ─── 4. chezmoi ─────────────────────────────────────────────────────────────
if command -v chezmoi >/dev/null 2>&1; then
  log "chezmoi init --source=$REPO_ROOT"
  chezmoi init --source="$REPO_ROOT"
  log "Preview pending chezmoi changes:"
  chezmoi diff || true
else
  if [[ "$MODE" == "dry-run" ]]; then
    log "would: chezmoi init + diff (chezmoi not yet installed)"
  else
    fail "chezmoi missing after base-tool install"
  fi
fi

if [[ "$MODE" == "dry-run" ]]; then
  log "would: snapshot home + chezmoi apply"
else
  command -v chezmoi >/dev/null 2>&1 || fail "chezmoi unavailable for apply"
  interactive_confirm "Apply chezmoi changes?" || fail "chezmoi apply aborted by user"
  if [[ -x "$REPO_ROOT/ops/snapshot-home.sh" ]]; then
    bash "$REPO_ROOT/ops/snapshot-home.sh"
  else
    fail "ops/snapshot-home.sh missing or not executable"
  fi
  chezmoi apply
fi

# ─── 5. Home Manager / nix-darwin ───────────────────────────────────────────
if [[ "$HOST_PROFILE" == "macos" ]]; then
  SWITCH_CMD=(darwin-rebuild switch --flake "$REPO_ROOT/nix#macos")
  DRY_CMD=(darwin-rebuild check --flake "$REPO_ROOT/nix#macos")
  switch_bin=darwin-rebuild
else
  SWITCH_CMD=(home-manager switch --flake "$REPO_ROOT/nix#$HOST_PROFILE")
  DRY_CMD=(home-manager switch --flake "$REPO_ROOT/nix#$HOST_PROFILE" --dry-run)
  switch_bin=home-manager
fi

if [[ "$MODE" == "dry-run" ]]; then
  log "would: ${SWITCH_CMD[*]}"
  if command -v "$switch_bin" >/dev/null 2>&1; then
    "${DRY_CMD[@]}" || log "(dry-run check returned non-zero; investigate before --yes)"
  else
    log "missing $switch_bin; would install via nix profile first"
  fi
else
  command -v "$switch_bin" >/dev/null 2>&1 \
    || fail "$switch_bin not on PATH; complete prior steps before --yes"
  log "Running: ${SWITCH_CMD[*]}"
  "${SWITCH_CMD[@]}"
fi

# ─── 6. mise install ────────────────────────────────────────────────────────
if [[ "$MODE" == "dry-run" ]]; then
  if command -v mise >/dev/null 2>&1; then
    log "would: mise trust $REPO_ROOT && mise install"
  else
    log "missing mise; would install via nix profile first"
  fi
else
  command -v mise >/dev/null 2>&1 || fail "mise not on PATH"
  mise trust "$REPO_ROOT"
  mise install
fi

# ─── 7. VS Code extensions ──────────────────────────────────────────────────
if [[ -x "$REPO_ROOT/ops/vscode-extensions.sh" ]]; then
  if [[ "$MODE" == "dry-run" ]]; then
    bash "$REPO_ROOT/ops/vscode-extensions.sh" --dry-run
  else
    bash "$REPO_ROOT/ops/vscode-extensions.sh"
  fi
fi

# ─── 8. lefthook install ────────────────────────────────────────────────────
if [[ -d "$REPO_ROOT/.git" ]]; then
  if [[ "$MODE" == "dry-run" ]]; then
    if command -v lefthook >/dev/null 2>&1; then
      log "would: lefthook install"
    else
      log "missing lefthook; would install via nix profile first"
    fi
  else
    command -v lefthook >/dev/null 2>&1 || fail "lefthook not on PATH"
    ( cd "$REPO_ROOT" && lefthook install )
  fi
fi

# ─── 9. ssh-agent helper (Unix non-WSL) ─────────────────────────────────────
if [[ "$HOST_PROFILE" != "wsl" ]] \
   && [[ -x "$REPO_ROOT/ops/unix/ssh-agent-setup.sh" ]]; then
  if [[ "$MODE" == "dry-run" ]]; then
    log "would: bash ops/unix/ssh-agent-setup.sh"
  else
    bash "$REPO_ROOT/ops/unix/ssh-agent-setup.sh" || log "(ssh-agent-setup returned non-zero; review)"
  fi
fi

# ─── 10. doctor (must pass) ─────────────────────────────────────────────────
if [[ -f "$REPO_ROOT/ops/doctor.sh" ]]; then
  log "Running doctor…"
  bash "$REPO_ROOT/ops/doctor.sh"
else
  log "doctor: ops/doctor.sh missing (skip)"
fi

log "done. mode: $MODE"
if [[ "$MODE" == "dry-run" ]]; then
  log "re-run with --yes to apply"
fi
