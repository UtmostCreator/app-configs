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
# (default 7). --notify always exits 0 and sends a desktop notification only
# when something needs attention. Token values are never printed.
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

summary="$claude_short · $codex_short"
case "$mode" in
  --summary)
    echo "$summary"
    exit "$attention"
    ;;
  --notify)
    if ((attention)); then
      notify-send --urgency=critical --app-name="AI logins" \
        "Log in again before you travel" "$summary" 2>/dev/null || true
    fi
    echo "$summary"
    exit 0
    ;;
esac
printf '%-12s %s\n' "Claude Code" "$claude_line" "Codex" "$codex_line"
exit "$attention"
