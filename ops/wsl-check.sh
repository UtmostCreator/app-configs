#!/usr/bin/env bash
# wsl-check.sh: WSL2-specific readiness checks, called by ops/readiness.sh on
# the wsl host profile. Read-only. Prints one "OK <msg>" or "TODO <msg>" line
# per check and always exits 0; readiness.sh does the counting.
#
# Test overrides: WSL_CHECK_PROC1_COMM, WSL_CHECK_REPO_ROOT,
# WSL_CHECK_WINDOWS_PREFIX.
set -uo pipefail

proc1_comm="${WSL_CHECK_PROC1_COMM:-/proc/1/comm}"
repo_root="${WSL_CHECK_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
win_prefix="${WSL_CHECK_WINDOWS_PREFIX:-/mnt/}"

# systemd runs the Home Manager user timers (AI CLI and MCP updates).
if [[ "$(head -n1 "$proc1_comm" 2>/dev/null)" == systemd ]]; then
  echo "OK systemd is PID 1 (user services and timers run)"
else
  echo "TODO systemd is off: add '[boot] systemd=true' to /etc/wsl.conf, then run 'wsl --shutdown' from Windows"
fi

# Git, Nix and package managers are many times slower across the 9P bridge.
if [[ "$repo_root" == "$win_prefix"* ]]; then
  echo "TODO repo is on a Windows drive ($repo_root); clone it under ~ for fast git and nix"
else
  echo "OK repo is on the Linux filesystem"
fi

# Windows Node installs put extensionless npm/npx shell scripts on the
# appended Windows PATH. If no Linux copy comes first, they run Windows Node.
for t in node npm npx pnpm yarn corepack; do
  p="$(command -v "$t" 2>/dev/null || true)"
  if [[ -n "$p" && "$p" == "$win_prefix"* ]]; then
    echo "TODO $t resolves to the Windows copy ($p); run sys-update so the Nix one comes first, or uninstall Windows Node"
  fi
done

# clipcopy (tmux copy mode) uses clip.exe, which needs Windows interop.
if command -v clip.exe >/dev/null 2>&1; then
  echo "OK clip.exe reachable (clipboard copy works)"
else
  echo "TODO clip.exe not on PATH: enable [interop] in /etc/wsl.conf (appendWindowsPath=true) for clipboard copy"
fi
exit 0
