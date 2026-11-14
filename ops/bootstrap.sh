#!/usr/bin/env bash
# Cold-start bootstrap for macOS / Linux desktop / Linux CLI / WSL2.
#
# Defaults to --dry-run: a strictly read-only plan. Dry-run only inspects
# (host detection, `doctor.sh --preflight`, which tools are on PATH) and prints
# the commands it would run. It never installs, sources, previews, initialises
# chezmoi or runs `nix flake check`. When Nix is already installed it does run
# two read-only Nix queries for the login-user check (ops/lib/preflight.sh):
# `nix show-config` and `nix eval --raw -f nix/vars/default.nix username`; if
# this Nix lacks nix-command or flakes they are enabled for that process only
# (NIX_CONFIG), never written to nix.conf. Without Nix the check falls back to
# a sed match of nix/vars/default.nix and stops on a mismatch.
#
# Only the command line enables apply; the MODE environment variable and CI
# are ignored. Apply needs explicit approval:
#   --yes    approved up front, no bootstrap prompt (the only way to apply
#            without a TTY)
#   --apply  asks on a TTY (once up front, again after `chezmoi diff` before
#            `chezmoi apply`); without a TTY it fails and asks for --yes
# macOS apply also needs sudo (nix-darwin switch). It is validated up front:
# `sudo -v` on a TTY, `sudo -n true` without one, so --yes without a TTY needs
# passwordless sudo.
#
# Steps (in order):
#   0. doctor.sh --preflight                (prerequisites; must pass)
#   1. nix          (Determinate Systems installer)
#   2. chezmoi, mise, home-manager, lefthook   (nix profile install)
#   3. nix flake check ./nix
#   4. chezmoi init + diff + apply          (snapshot first)
#   5. home-manager switch  OR darwin-rebuild switch (per host; previewed first)
#   6. mise install                         (inside the repo)
#   7. VS Code extensions (if code CLI is present)
#   8. lefthook install
#   9. ops/unix/ssh-agent-setup.sh          (skipped on WSL; failure = degraded)
#  10. ops/doctor.sh                        (must pass)
#
# Usage:
#   bash ops/bootstrap.sh                  # dry-run, default
#   bash ops/bootstrap.sh --dry-run
#   bash ops/bootstrap.sh --apply          # ask on a TTY, then mutate
#   bash ops/bootstrap.sh --yes            # mutate, no prompt (also non-TTY)
#   HOST_PROFILE=wsl bash ops/bootstrap.sh --dry-run
#   HOST_PROFILE_DEFAULT=linux-cli bash ops/bootstrap.sh
#
# Unknown arguments, or --dry-run combined with --apply/--yes, exit 1.
# Exits non-zero on any required step failure; a failed optional step is listed
# as degraded in the final summary instead of "bootstrap complete".

set -euo pipefail

MODE="dry-run"
APPROVED=false
mode_flag=""
for arg in "$@"; do
  case "$arg" in
    --dry-run|--apply|--yes)
      if [[ -n "$mode_flag" ]] \
         && [[ "$mode_flag" != "$arg" ]] \
         && { [[ "$mode_flag" == "--dry-run" ]] || [[ "$arg" == "--dry-run" ]]; }; then
        printf '[bootstrap] conflicting mode flags: %s and %s\n' "$mode_flag" "$arg" >&2
        exit 1
      fi
      mode_flag="$arg"
      [[ "$arg" == "--dry-run" ]] || MODE="apply"
      [[ "$arg" == "--yes" ]] && APPROVED=true
      ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
      exit 0
      ;;
    *)
      printf '[bootstrap] unknown arg: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

log()  { printf '[bootstrap:%s] %s\n' "$MODE" "$*"; }
warn() { printf '[bootstrap:warn] %s\n' "$*" >&2; }
fail() { printf '[bootstrap:error] %s\n' "$*" >&2; exit 1; }
# Dry-run aware command wrapper for the shared preflight (it prints instead of
# running when MODE=dry-run).
run() {
  if [[ "$MODE" == "dry-run" ]]; then log "would run: $*"; else log "+ $*"; "$@"; fi
}


REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ops/lib/hm-switch.sh
source "$REPO_ROOT/ops/lib/hm-switch.sh"
# shellcheck source=ops/lib/preflight.sh
source "$REPO_ROOT/ops/lib/preflight.sh"

# Test guard (ops/lib/preflight.sh): an apply run under bats must stay inside
# the test's scratch HOME and repo copy.
[[ "$MODE" == "apply" ]] && preflight_bats_guard bootstrap "to apply" "$REPO_ROOT"
# detect-host validates HOST_PROFILE, rejects WSL1/ambiguity and explains why
# on stderr; a failure here must stop the run.
HOST_PROFILE="$(bash "$REPO_ROOT/ops/detect-host.sh")" \
  || fail "host detection failed (see message above)"

log "Repo: $REPO_ROOT"
log "Host: $HOST_PROFILE"

case "$HOST_PROFILE" in
  macos|linux-desktop|linux-cli|wsl) ;;
  *) fail "Unsupported HOST_PROFILE: $HOST_PROFILE" ;;
esac

for cmd in git bash curl; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
done

# ─── 0. Preflight (read-only) ───────────────────────────────────────────────
[[ -f "$REPO_ROOT/ops/doctor.sh" ]] || fail "ops/doctor.sh missing"
log "Preflight: doctor.sh --preflight"
bash "$REPO_ROOT/ops/doctor.sh" --preflight || fail "preflight failed; fix the errors above first"

# Same guards as ops/install.sh: WSL1 refusal, login user vs nix username,
# and personal.yaml seeding (a missing one fails the flake and chezmoi later).
preflight_host_checks "$REPO_ROOT" "$HOST_PROFILE"
preflight_personal_yaml "$REPO_ROOT" "$HOST_PROFILE" run

# ─── Approval (apply only) ──────────────────────────────────────────────────
# Only --yes approves non-interactively. CI and a missing TTY never approve.
# Prompts go to stderr so redirected stdout cannot hide them.
confirm() {
  local ans
  printf '%s [y/N] ' "$1" >&2
  read -r ans || fail "no answer; aborted"
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

if [[ "$MODE" == "apply" ]] && ! $APPROVED; then
  [[ -t 0 ]] || fail "--apply needs a TTY to ask for approval; pass --yes to approve non-interactively"
  confirm "Apply bootstrap to this machine (installs tools, then asks again before applying dotfiles)?" \
    || fail "aborted by user"
fi

# macOS switches via sudo: fail now, before any mutation, not halfway through.
if [[ "$MODE" == "apply" && "$HOST_PROFILE" == "macos" ]]; then
  if [[ -t 0 ]]; then
    sudo -v || fail "macOS switch needs sudo; authentication failed"
  else
    sudo -n true || fail "macOS switch needs sudo; run on a TTY or configure sudo"
  fi
fi

DEGRADED=()

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

# Apply only: make freshly installed nix-profile tools visible to this process.
# Dry-run must not source anything. ~/.nix-profile/bin is prepended because
# `nix profile install` puts the bootstrap tools there and they must win over
# older copies; the system nix profile dir is only appended.
if [[ "$MODE" == "apply" ]]; then
  if ! command -v nix >/dev/null 2>&1; then
    for source_file in \
      /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
      "$HOME/.nix-profile/etc/profile.d/nix.sh" \
      /etc/profile.d/nix.sh; do
      # shellcheck disable=SC1090
      [[ -r "$source_file" ]] && . "$source_file" || true
    done
  fi
  export PATH="$HOME/.nix-profile/bin:$PATH:/nix/var/nix/profiles/default/bin"
fi

have_nix=false
command -v nix >/dev/null 2>&1 && have_nix=true

# ─── 2. Base tools via nix profile ──────────────────────────────────────────
# TODO(T-0008 follow-up): these are unpinned nixpkgs#... (current channel
# registry); pin them via repo flake outputs.
if [[ "$MODE" == "dry-run" ]]; then
  if $have_nix; then
    log "would: nix profile install nixpkgs#{chezmoi,mise,home-manager,lefthook}"
  else
    log "missing nix; with --yes would install Nix first, then base tools"
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
if [[ "$MODE" == "dry-run" ]]; then
  log "would: nix flake check $REPO_ROOT/nix"
else
  log "Validating nix flake (./nix)…"
  nix flake check "$REPO_ROOT/nix"
fi

# ─── 4. chezmoi ─────────────────────────────────────────────────────────────
if [[ "$MODE" == "dry-run" ]]; then
  log "would: chezmoi init --source=$REPO_ROOT"
  log "would: chezmoi diff"
  log "would: ops/snapshot-home.sh, then chezmoi apply"
else
  command -v chezmoi >/dev/null 2>&1 || fail "chezmoi missing after base-tool install"
  log "chezmoi init --source=$REPO_ROOT"
  chezmoi init --source="$REPO_ROOT"
  log "Preview pending chezmoi changes:"
  chezmoi diff
  if ! $APPROVED && ! confirm "Apply these chezmoi changes?"; then
    fail "aborted before chezmoi apply: nothing was applied; Nix and the bootstrap tools stay installed."
  fi
  if [[ -x "$REPO_ROOT/ops/snapshot-home.sh" ]]; then
    bash "$REPO_ROOT/ops/snapshot-home.sh"
  else
    fail "ops/snapshot-home.sh missing or not executable"
  fi
  chezmoi apply
fi

# ─── 5. Home Manager / nix-darwin ───────────────────────────────────────────
if [[ "$HOST_PROFILE" == "macos" ]]; then
  # darwin-rebuild is not installed on a first run: use the pinned flake output.
  # sudo resets the environment (no NIX_CONFIG), so the features go on the
  # command line; darwin-rebuild adds them itself.
  if command -v darwin-rebuild >/dev/null 2>&1; then
    SWITCH_CMD=(sudo darwin-rebuild switch --flake "$REPO_ROOT/nix#macos")
  else
    SWITCH_CMD=(sudo nix --extra-experimental-features "nix-command flakes" run "$REPO_ROOT/nix#darwin-rebuild" -- switch --flake "$REPO_ROOT/nix#macos")
  fi
  DRY_CMD=(nix build --no-link "$REPO_ROOT/nix#darwinConfigurations.macos.system")
  switch_bin=nix
else
  SWITCH_CMD=(home-manager switch -b hm-bak --flake "$REPO_ROOT/nix#$HOST_PROFILE")
  DRY_CMD=("${SWITCH_CMD[@]}" --dry-run)
  switch_bin=home-manager
fi

if [[ "$MODE" == "dry-run" ]]; then
  log "would: ${DRY_CMD[*]}   (preview; a failure aborts)"
  log "would: ${SWITCH_CMD[*]}"
else
  command -v "$switch_bin" >/dev/null 2>&1 \
    || fail "$switch_bin not on PATH; complete prior steps first"
  log "Previewing: ${DRY_CMD[*]}"
  "${DRY_CMD[@]}" || fail "preview failed; not switching (fix the error above)"
  log "Running: ${SWITCH_CMD[*]}"
  if [[ "$HOST_PROFILE" == "macos" ]]; then
    "${SWITCH_CMD[@]}"
  else
    # Conflict check, then `home-manager switch -b hm-bak` (ops/lib/hm-switch.sh).
    hm_switch "$REPO_ROOT/nix" "$HOST_PROFILE" || fail "home-manager switch failed"
  fi
fi

# ─── 6. mise install ────────────────────────────────────────────────────────
if [[ "$MODE" == "dry-run" ]]; then
  log "would: (cd $REPO_ROOT && mise trust ./mise.toml && mise install)"
else
  command -v mise >/dev/null 2>&1 || fail "mise not on PATH"
  ( cd "$REPO_ROOT" && mise trust ./mise.toml && mise install )
fi

# ─── 7. VS Code extensions ──────────────────────────────────────────────────
if [[ -x "$REPO_ROOT/ops/vscode-extensions.sh" ]]; then
  if [[ "$MODE" == "dry-run" ]]; then
    log "would: bash ops/vscode-extensions.sh"
  else
    bash "$REPO_ROOT/ops/vscode-extensions.sh"
  fi
fi

# ─── 8. lefthook install ────────────────────────────────────────────────────
if [[ -e "$REPO_ROOT/.git" ]]; then
  if [[ "$MODE" == "dry-run" ]]; then
    log "would: lefthook install"
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
  elif ! bash "$REPO_ROOT/ops/unix/ssh-agent-setup.sh"; then
    DEGRADED+=("ssh-agent-setup (re-run: bash ops/unix/ssh-agent-setup.sh)")
    printf '[bootstrap:warn] ssh-agent-setup failed; continuing in degraded state\n' >&2
  fi
fi

# ─── 10. doctor (must pass) ─────────────────────────────────────────────────
if [[ "$MODE" == "dry-run" ]]; then
  log "would: bash ops/doctor.sh"
else
  log "Running doctor…"
  bash "$REPO_ROOT/ops/doctor.sh" || fail "doctor reported errors"
fi

# ─── Summary ────────────────────────────────────────────────────────────────
if [[ "$MODE" == "dry-run" ]]; then
  log "dry-run only; nothing was changed. Re-run with --yes to apply."
elif ((${#DEGRADED[@]} > 0)); then
  log "finished with degraded steps (not a clean success):"
  for step in "${DEGRADED[@]}"; do
    log "  degraded: $step"
  done
else
  log "bootstrap complete"
fi
