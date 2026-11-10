#!/usr/bin/env bats
# Tests for nix/modules/home/scripts/ai-auth-status.sh: how long until Claude
# Code / Codex need an interactive login again, so it happens at home rather
# than failing while travelling.
#
# Claude Code stores a hard deadline (claudeAiOauth.refreshTokenExpiresAt, ms).
# Codex stores last_refresh and a JWT access token that it renews on use; its
# refresh token is opaque, so only "signed in" and the refresh age are known.
#
# Fixtures contain fake tokens only. NOW pins the clock.
#
# Run:  bats tests/bash/ai-auth-status.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/nix/modules/home/scripts/ai-auth-status.sh"
    export NOW=1794225600 # 2026-11-09T12:00:00Z
    export CLAUDE_CREDENTIALS="$BATS_TEST_TMPDIR/claude.json"
    export CODEX_AUTH="$BATS_TEST_TMPDIR/codex.json"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat >"$BATS_TEST_TMPDIR/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
echo "notify-send $*" >>"$CALLS"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/notify-send"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    claude_expires_in_days 24
    codex_signed_in
}

claude_expires_in_days() {
    jq -n --argjson ms "$(((NOW + $1 * 86400 + 3600) * 1000))" \
        '{claudeAiOauth: {accessToken: "sk-ant-oat-FAKE", refreshToken: "sk-ant-ort-FAKE",
                          expiresAt: 0, refreshTokenExpiresAt: $ms}}' >"$CLAUDE_CREDENTIALS"
}

b64url() { printf '%s' "$1" | base64 -w0 | tr '+/' '-_' | tr -d '='; }

codex_signed_in() {
    local payload
    payload="$(b64url "{\"exp\":$((NOW + 5 * 86400)),\"iat\":$((NOW - 4 * 86400))}")"
    jq -n --arg at "eyJhbGciOiJSUzI1NiJ9.$payload.FAKESIG" \
        '{auth_mode: "chatgpt", last_refresh: "2026-11-05T12:00:00Z",
          tokens: {access_token: $at, refresh_token: "rt.FAKE.FAKE", id_token: "x.y.z"}}' >"$CODEX_AUTH"
}

@test "reports the Claude deadline and Codex refresh state" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Claude Code"*"login required by 2026-12-03"*"24 days left"* ]]
    [[ "$output" == *"Codex"*"signed in (chatgpt)"*"refreshed 4 days ago"*"renews on use"* ]]
}

@test "never prints token material" {
    run bash "$SCRIPT"
    [[ "$output" != *FAKE* ]]
    [[ "$output" != *eyJ* ]]
}

@test "warns inside the window and exits non-zero" {
    claude_expires_in_days 5
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"5 days left"* ]]
    [[ "$output" == *"claude auth login"* ]]
}

@test "the warning window is configurable" {
    claude_expires_in_days 10
    AI_AUTH_WARN_DAYS=14 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
}

@test "an expired Claude login says so" {
    claude_expires_in_days -2
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"login expired"* ]]
}

@test "missing or signed-out Codex is a warning" {
    rm "$CODEX_AUTH"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Codex"*"not signed in"*"codex login"* ]]
}

@test "Codex with an API key has no expiry to track" {
    jq -n '{auth_mode: "apikey", OPENAI_API_KEY: "sk-FAKE"}' >"$CODEX_AUTH"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"API key"* ]]
    [[ "$output" != *FAKE* ]]
}

@test "missing Claude credentials are a warning" {
    rm "$CLAUDE_CREDENTIALS"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Claude Code"*"not signed in"* ]]
}

@test "--summary prints one line for sys-update" {
    run bash "$SCRIPT" --summary
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "$output" == "Claude 24d left · Codex signed in" ]]
}

@test "--notify sends a desktop notification only when action is needed" {
    run bash "$SCRIPT" --notify
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
    claude_expires_in_days 3
    run bash "$SCRIPT" --notify
    [ "$status" -eq 0 ]
    grep -q 'notify-send .*Claude 3d left' "$CALLS"
}

# ── Home Manager wiring ─────────────────────────────────────────────────────

hm_eval() {
    nix eval --json --impure --expr "
      let hm = (builtins.getFlake \"path:${HM_FLAKE_ROOT:-$REPO_ROOT}/nix\").homeConfigurations.linux-desktop.config;
      in $1"
}

@test "units: ai-auth-status is installed and checked every morning" {
    run hm_eval '{
      cmd = builtins.any (p: (p.name or "") == "ai-auth-status") hm.home.packages;
      timer = hm.systemd.user.timers.ai-auth-check.Timer;
      exec = hm.systemd.user.services.ai-auth-check.Service.ExecStart; }'
    [ "$status" -eq 0 ]
    jq -e '.cmd and .timer.OnCalendar == "*-*-* 09:00:00" and .timer.Persistent
           and ([.exec] | flatten | .[0] | endswith("/bin/ai-auth-status --notify"))' <<<"$output"
}
