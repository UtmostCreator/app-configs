#!/usr/bin/env bash
# readiness.sh — one command to answer "am I all set?".
#
# Read-only. Verifies the whole stack is installed and usable, and tells you
# exactly what (if anything) is left — including whether a system
# `nixos-rebuild switch` is still needed.
#
# Usage:
#   bash scripts/readiness.sh         # full report, exit 0 if ready
#   AI_OUTPUT=plain bash scripts/readiness.sh
#
# Exit 0 = user environment ready. Exit 2 = ready but optional system rebuild
# pending. Exit 1 = something required is missing.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0 warn=0 err=0
ok()   { printf '  [OK]   %s\n' "$*"; pass=$((pass+1)); }
note() { printf '  [TODO] %s\n' "$*"; warn=$((warn+1)); }
bad()  { printf '  [MISS] %s\n' "$*"; err=$((err+1)); }
hdr()  { printf '\n== %s ==\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
is_nixos() { [[ -f /etc/NIXOS ]] || grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; }

hdr "Core tooling"
for t in nix home-manager chezmoi mise lefthook git; do
  if have "$t"; then ok "$t present"; else bad "$t missing (run: sys-install)"; fi
done

hdr "Applications & CLI (sample of the declared set)"
for t in fish nvim rg fd bat eza fzf zoxide starship atuin tmux lazygit delta \
         gh jq yq node npm php docker stripe firefox code ghostty bruno flameshot; do
  if have "$t"; then ok "$t"; else note "$t not on PATH (run: sys-update)"; fi
done

hdr "Dotfiles (chezmoi)"
if have chezmoi; then
  if chezmoi verify >/dev/null 2>&1; then ok "all managed dotfiles match"
  else note "chezmoi has pending changes (run: chezmoi apply  or  sys-update)"; fi
fi

hdr "Maintenance commands usable"
for c in sys-update sys-cleanup sys-install; do
  if have "$c" || [[ -x "$HOME/.local/bin/$c" ]]; then ok "$c available"
  else note "$c not found (open a new shell; ~/.local/bin)"; fi
done

hdr "Git aliases"
n=$(git config --global --get-regexp '^alias\.' 2>/dev/null | wc -l)
if [[ "$n" -gt 0 ]]; then ok "$n git aliases active"; else note "no git aliases (run: chezmoi apply)"; fi

hdr "Health checks"
if bash "$REPO_ROOT/scripts/doctor.sh" >/dev/null 2>&1; then ok "doctor passes"; else bad "doctor failed (run: bash scripts/doctor.sh)"; fi
if bash "$REPO_ROOT/scripts/validate-config.sh" >/dev/null 2>&1; then ok "validate-config passes"; else bad "validate-config failed"; fi

rebuild_needed=0
if is_nixos; then
  hdr "NixOS system layer (live state)"
  # Check the LIVE, activated system — authoritative regardless of which file
  # the settings live in (configuration.nix vs an imported module like
  # /etc/nixos/app-configs-extra.nix written by sys-setup).
  cur_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$cur_shell" == *fish* ]]; then ok "login shell is fish ($cur_shell)"
  else note "login shell is $cur_shell, not fish — run: sudo sys-setup --apply"; rebuild_needed=1; fi

  if nix show-config 2>/dev/null | grep -qE "trusted-users\s*=.*\b${USER}\b"; then
    ok "user in nix trusted-users"
  else note "user not in nix trusted-users — run: sudo sys-setup --apply"; rebuild_needed=1; fi

  if systemctl is-active nix-gc.timer >/dev/null 2>&1 \
     || systemctl is-active nix-optimise.timer >/dev/null 2>&1; then
    ok "system GC/optimise timer active"
  else note "no active system GC timer — run: sudo sys-setup --apply"; rebuild_needed=1; fi
fi

hdr "Summary"
printf '  OK: %d   TODO: %d   MISSING: %d\n' "$pass" "$warn" "$err"
if [[ "$err" -gt 0 ]]; then
  echo "  -> NOT READY. Fix [MISS] items above (start: sys-install)."
  exit 1
elif [[ "$rebuild_needed" == 1 ]]; then
  echo "  -> User environment READY. Optional system rebuild pending:"
  echo "     run 'sys-setup' (or see docs/nixos-rebuild.md), then open a new terminal."
  exit 2
else
  echo "  -> ALL SET. Everything installed and usable."
  exit 0
fi
