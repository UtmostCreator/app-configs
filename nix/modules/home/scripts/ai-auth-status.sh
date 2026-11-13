# Usage: ai-auth-status [--summary | --notify]
#
# How long until Claude Code and Codex need an interactive login again, so it
# can be done at home instead of failing while away. Tested by
# tests/bash/ai-auth-status.bats; run daily by ai-auth-check.timer and by
# sys-update's verification (nix/modules/home/ai-cli-updates.nix).
#
#   Claude Code  ~/.claude/.credentials.json  claudeAiOauth.refreshTokenExpiresAt
#                is a hard deadline (epoch ms). Background token refreshes do
#                not move it; only `claude auth login` does.
#   Codex        ~/.codex/auth.json  last_refresh + JWT access-token expiry.
#                Codex renews the access token on use; the refresh token is
#                opaque, so there is no readable deadline beyond "signed in".
#
# Exit 1 when a login is missing, expired, or due within AI_AUTH_WARN_DAYS
# (default 7). --notify always exits 0 and, only when something needs
# attention, sends a desktop notification (a Windows toast on WSL2 when
# notify-send fails) and logs the warning to stderr. Token values are never
# printed.
set -uo pipefail

mode="${1:-}"
case "$mode" in '' | --summary | --notify) ;; *)
  echo "usage: ai-auth-status [--summary | --notify]" >&2
  exit 2
  ;;
esac

warn_days="${AI_AUTH_WARN_DAYS:-7}"
now="${NOW:-$(date +%s)}"
claude_file="${CLAUDE_CREDENTIALS:-$HOME/.claude/.credentials.json}"
codex_file="${CODEX_AUTH:-$HOME/.codex/auth.json}"
attention=0

day() { date -u -d "@$1" +%Y-%m-%d; }

# ── Claude Code ─────────────────────────────────────────────────────────────
claude_ms="$(jq -er '.claudeAiOauth.refreshTokenExpiresAt // empty | numbers' "$claude_file" 2>/dev/null)"
claude_has_login="$(jq -er '.claudeAiOauth.refreshToken // empty | strings | length > 0' "$claude_file" 2>/dev/null)"
if [[ -n "$claude_ms" ]]; then
  claude_exp=$((claude_ms / 1000))
  claude_days=$(((claude_exp - now) / 86400))
  if ((claude_exp <= now)); then
    attention=1
    claude_line="login expired on $(day "$claude_exp") — run: claude auth login"
    claude_short="Claude login expired"
  elif ((claude_days < warn_days)); then
    attention=1
    claude_line="login required by $(day "$claude_exp") ($claude_days days left) — run: claude auth login"
    claude_short="Claude ${claude_days}d left"
  else
    claude_line="login required by $(day "$claude_exp") ($claude_days days left)"
    claude_short="Claude ${claude_days}d left"
  fi
elif [[ "$claude_has_login" == true ]]; then
  claude_line="signed in; this version stores no login deadline"
  claude_short="Claude signed in"
else
  attention=1
  claude_line="not signed in — run: claude auth login"
  claude_short="Claude not signed in"
fi

# ── Codex ───────────────────────────────────────────────────────────────────
jwt_exp() {
  local seg="${1#*.}"
  seg="${seg%%.*}"
  seg="$(tr '_-' '/+' <<<"$seg")"
  while ((${#seg} % 4)); do seg+="="; done
  base64 -d <<<"$seg" 2>/dev/null | jq -er '.exp | numbers' 2>/dev/null
}

codex_mode="$(jq -er '.auth_mode // empty | strings' "$codex_file" 2>/dev/null)"
codex_token="$(jq -er '.tokens.access_token // empty | strings' "$codex_file" 2>/dev/null)"
codex_refresh="$(jq -er '.tokens.refresh_token // empty | strings | length > 0' "$codex_file" 2>/dev/null)"
if [[ "$codex_mode" == apikey ]] && jq -e '.OPENAI_API_KEY | strings | length > 0' "$codex_file" >/dev/null 2>&1; then
  codex_line="signed in with an API key (no expiry to track)"
  codex_short="Codex API key"
elif [[ -n "$codex_token" && "$codex_refresh" == true ]]; then
  codex_line="signed in (${codex_mode:-chatgpt})"
  last="$(jq -er '.last_refresh // empty | strings' "$codex_file" 2>/dev/null)"
  if [[ -n "$last" ]] && last_s="$(date -d "$last" +%s 2>/dev/null)"; then
    codex_line+="; refreshed $(((now - last_s) / 86400)) days ago"
  fi
  if exp="$(jwt_exp "$codex_token")"; then
    codex_line+="; access token valid until $(day "$exp"), renews on use"
  fi
  codex_short="Codex signed in"
else
  attention=1
  codex_line="not signed in — run: codex login"
  codex_short="Codex not signed in"
fi

# ── Notification ────────────────────────────────────────────────────────────
# PowerShell single-quoted literal: nothing inside is interpolated or run.
# PowerShell also ends such strings at the Unicode single quotes, so every
# quote character is doubled, which is its escape inside '...'.
ps_quote() {
  local s="${1//\'/\'\'}" q
  for q in $'\xe2\x80\x98' $'\xe2\x80\x99' $'\xe2\x80\x9a' $'\xe2\x80\x9b'; do s="${s//"$q"/$q$q}"; done
  printf "'%s'" "$s"
}

# Desktop notification, else a Windows toast (WSL2 usually has no
# notification daemon, so notify-send fails there). The warning always goes to
# stderr as well, so the timer's run lands in the journal.
notify() {
  local title="$1" body="$2" ps
  echo "AI logins: $title: $body" >&2
  notify-send --urgency=critical --app-name="AI logins" "$title" "$body" 2>/dev/null && return 0
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
    >/dev/null 2>&1 || echo "AI logins: Windows toast failed" >&2
  return 0
}

summary="$claude_short · $codex_short"
case "$mode" in
  --summary)
    echo "$summary"
    exit "$attention"
    ;;
  --notify)
    if ((attention)); then
      notify "Log in again before you travel" "$summary"
    fi
    echo "$summary"
    exit 0
    ;;
esac
printf '%-12s %s\n' "Claude Code" "$claude_line" "Codex" "$codex_line"
exit "$attention"
