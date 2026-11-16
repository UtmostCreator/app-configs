# Entry point for the codebase-memory-mcp-update user unit (dev.nix).
# Finds the repo through chezmoi's source dir, like the sys-* helpers (or, on
# NixOS-WSL where chezmoi has no sourceDir, the sys-update wrapper's
# DOTFILES_DIR), so it works for any clone location (README: ~/app-configs).
set -euo pipefail
# Repo root. chezmoi's source dir is <repo>/home. On NixOS-WSL chezmoi has no
# persisted sourceDir (`chezmoi init --source=<repo>` does not store it), so
# `chezmoi source-path` prints the default ~/.local/share/chezmoi with rc 0
# although it does not exist. A candidate counts only if it holds the script
# the unit runs (pure bash: the unit PATHs carry no sed/head). Then fall back to the DOTFILES_DIR that chezmoi
# baked into the ~/.local/bin/sys-update wrapper when it rendered it (the repo
# path of the apply that installed it, any clone location).
repo_root() {
  local need="$1" src dir line
  src="$(chezmoi source-path 2>/dev/null)" || src=""
  if [[ -n "$src" && -f "$src/../$need" ]]; then
    printf '%s\n' "$src/.."
    return 0
  fi
  dir=""
  if [[ -r "$HOME/.local/bin/sys-update" ]]; then
    while IFS= read -r line; do
      if [[ -z "$dir" && "$line" =~ ^DOTFILES_DIR=\"(.*)\"$ ]]; then dir="${BASH_REMATCH[1]}"; fi
    done <"$HOME/.local/bin/sys-update"
  fi
  if [[ -n "$dir" && -f "$dir/$need" ]]; then
    printf '%s\n' "$dir"
    return 0
  fi
  return 1
}

root="$(repo_root ops/update-codebase-memory-mcp.sh)" || { echo "codebase-memory-mcp-update: cannot locate the repo (chezmoi source-path and the sys-update wrapper's DOTFILES_DIR both lack ops/update-codebase-memory-mcp.sh)" >&2; exit 1; }
exec bash "$root/ops/update-codebase-memory-mcp.sh" --apply
