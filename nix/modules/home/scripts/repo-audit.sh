# Entry point for the repo-audit user unit (audit.nix): the weekly, read-only
# `ops/audit.sh --live`. Finds the repo through chezmoi's source dir (or the
# sys-update wrapper's DOTFILES_DIR on NixOS-WSL), like the
# codebase-memory-mcp-update unit, so it works for any
# clone location.
#
# The audit output goes to the journal. A FAIL also raises one notification
# (desktop, else a Windows toast on WSL2: the same approach as
# ai-auth-status.sh). The unit itself exits 0 whenever the audit ran: a failing
# unit would show up as a failed user unit in the next audit and keep the
# audit failing on its own account.
set -uo pipefail

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

root="$(repo_root ops/audit.sh)" || { echo "repo-audit: cannot locate the repo (chezmoi source-path and the sys-update wrapper's DOTFILES_DIR both lack ops/audit.sh)" >&2; exit 1; }
audit="$root/ops/audit.sh"

# PowerShell single-quoted literal; typographic quotes also end a literal.
ps_quote() {
  local s="${1//\'/\'\'}" q
  for q in $'\xe2\x80\x98' $'\xe2\x80\x99' $'\xe2\x80\x9a' $'\xe2\x80\x9b'; do s="${s//"$q"/$q$q}"; done
  printf "'%s'" "$s"
}

# Desktop notification, else a Windows toast (WSL2 usually has no
# notification daemon, so notify-send fails there).
notify() {
  local title="$1" body="$2" ps
  notify-send --urgency=critical --app-name="Repo audit" "$title" "$body" 2>/dev/null && return 0
  # systemd user units do not inherit the Windows PATH that WSL appends.
  ps="$(command -v powershell.exe 2>/dev/null)" || ps="${WINDOWS_POWERSHELL:-/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe}"
  [[ -x "$ps" ]] || return 0
  timeout 10 "$ps" -NoProfile -NonInteractive -Command "\$t = $(ps_quote "$title"); \$m = $(ps_quote "$body");
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null;
    \$x = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02);
    \$n = \$x.GetElementsByTagName('text');
    \$n.Item(0).AppendChild(\$x.CreateTextNode(\$t)) > \$null;
    \$n.Item(1).AppendChild(\$x.CreateTextNode(\$m)) > \$null;
    \$app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe';
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$app).Show([Windows.UI.Notifications.ToastNotification]::new(\$x))" \
    >/dev/null 2>&1 || echo "repo-audit: Windows toast failed" >&2
  return 0
}

out="$(bash "$audit" --live 2>&1)"
rc=$?
printf '%s\n' "$out"

if ((rc != 0)); then
  fails="$(grep -c '^FAIL' <<<"$out" || true)"
  notify "Repo audit: ${fails:-?} FAIL" "$(grep '^FAIL' <<<"$out" | head -n 3 | cut -c1-160)"
fi
exit 0
