#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[WARN] %s\n" "$1"; }
check_bin() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    ok "binary '$name' found"
  else
    warn "binary '$name' missing"
  fi
}
check_file() {
  local rel="$1"
  if [[ -f "$ROOT_DIR/$rel" ]]; then
    ok "file '$rel' present"
  else
    warn "file '$rel' missing"
  fi
}

echo "== app-configs doctor =="

echo "-- Required binaries --"
for b in git rg fd fzf starship nvim tmux just php; do
  check_bin "$b"
done

echo "-- Core files --"
check_file "README.md"
check_file "shell/starship.toml"
check_file "shell/zshrc.shared"
check_file "vscode/user/settings.json"
check_file "tools/nvim/init.lua"
check_file "tools/karabiner/karabiner.json"
check_file "justfile"

echo "-- Hooks --"
check_file ".lefthook.yml"
check_file ".husky/pre-commit"
check_file ".husky/commit-msg"
check_file "scripts/hooks/pre-commit.sh"
check_file "scripts/hooks/commit-msg.sh"

if command -v gitleaks >/dev/null 2>&1; then
  ok "gitleaks found (preferred local pre-commit scanner)"
elif command -v trufflehog >/dev/null 2>&1; then
  ok "trufflehog found (fallback scanner)"
else
  warn "no secret scanner found (install gitleaks or trufflehog)"
fi

echo "-- AI quick checks --"
if rg -n 'github\.copilot\.enable|chat\.' "$ROOT_DIR/vscode/user/settings.json" >/dev/null 2>&1; then
  ok "VS Code AI settings present"
else
  warn "VS Code AI settings not found in vscode/user/settings.json"
fi

if [[ -f "$ROOT_DIR/tools/nvim/lua/plugins/copilot.lua" ]]; then
  ok "Neovim Copilot plugin config present"
else
  warn "Neovim Copilot plugin config missing"
fi

echo "== doctor finished =="
