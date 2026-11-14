#!/usr/bin/env bats
# Hourly self-updates for the natively installed AI CLIs (Claude Code, Codex).
#
# Scripts: nix/modules/home/scripts/{claude,codex}-auto-update.sh
# Units:   nix/modules/home/ai-cli-updates.nix
#
# Regression: the timers used to be hand-made monotonic timers
# (OnBootSec + OnUnitActiveSec) outside the repo. After a reload they sat in
# "active (elapsed)" with no next run for six weeks while supervised Claude
# sessions kept running old binaries. They are now calendar timers owned by
# Home Manager, and the scripts are tested here with stubbed binaries.
#
# Run:  bats tests/bash/ai-cli-auto-update.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CLAUDE_SCRIPT="$REPO_ROOT/nix/modules/home/scripts/claude-auto-update.sh"
    CODEX_SCRIPT="$REPO_ROOT/nix/modules/home/scripts/codex-auto-update.sh"

    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    export VERSION_FILE="$BATS_TEST_TMPDIR/version"
    export NEXT_VERSION_FILE="$BATS_TEST_TMPDIR/next-version"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    : >"$CALLS"

    # Fake CLI: `--version` prints the installed version, `update` installs
    # NEXT_VERSION_FILE (if present) or fails when FAIL_UPDATE=1.
    for cli in claude codex; do
        cat >"$STUBS/$cli" <<EOF
#!/usr/bin/env bash
case "\$1" in
  --version)
    v="\$(cat "\$VERSION_FILE")"
    if [ "$cli" = claude ]; then echo "\$v (Claude Code)"; else echo "codex-cli \$v"; fi ;;
  update)
    echo "$cli update" >>"\$CALLS"
    [ "\${FAIL_UPDATE:-0}" = 1 ] && exit 1
    [ -f "\$NEXT_VERSION_FILE" ] && cp "\$NEXT_VERSION_FILE" "\$VERSION_FILE"
    exit 0 ;;
esac
EOF
    done
    # Fake systemctl: `show -p LoadState` reports BACKGROUND_LOAD_STATE
    # (default loaded); like the real one, try-restart on a unit that is not
    # installed exits 5.
    cat >"$STUBS/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >>"$CALLS"
if [[ " $* " == *" show "* ]]; then
  echo "${BACKGROUND_LOAD_STATE:-loaded}"
  exit 0
fi
if [[ " $* " == *" try-restart "* && " $* " == *" claude-background-sessions.service "* \
      && "${BACKGROUND_LOAD_STATE:-loaded}" == not-found ]]; then
  exit 5
fi
exit "${FAIL_RESTART:-0}"
EOF
    chmod +x "$STUBS"/*
    export CLAUDE_BIN="$STUBS/claude" CODEX_BIN="$STUBS/codex"
    export PATH="$STUBS:$PATH"
}

claude_state() { cat "$XDG_STATE_HOME/claude-auto-update/applied-version"; }
codex_state() { cat "$XDG_STATE_HOME/codex-auto-update/installed-version"; }

# ── Claude Code ─────────────────────────────────────────────────────────────

@test "claude: current version already applied leaves sessions alone" {
    echo 2.1.319 >"$VERSION_FILE"
    mkdir -p "$XDG_STATE_HOME/claude-auto-update"
    echo 2.1.319 >"$XDG_STATE_HOME/claude-auto-update/applied-version"
    run bash "$CLAUDE_SCRIPT"
    [ "$status" -eq 0 ]
    grep -qx 'claude update' "$CALLS"
    ! grep -q systemctl "$CALLS"
    [[ "$output" == *"already active"* ]]
}

@test "claude: a new release restarts every running supervised session" {
    echo 2.1.319 >"$VERSION_FILE"
    echo 2.1.320 >"$NEXT_VERSION_FILE"
    mkdir -p "$XDG_STATE_HOME/claude-auto-update"
    echo 2.1.319 >"$XDG_STATE_HOME/claude-auto-update/applied-version"
    run bash "$CLAUDE_SCRIPT"
    [ "$status" -eq 0 ]
    # try-restart touches only running units, and the glob picks up every
    # project instance instead of a hard-coded list.
    grep -qF "systemctl --user try-restart claude-background-sessions.service claude-remote-control@*.service" "$CALLS"
    [ "$(claude_state)" = 2.1.320 ]
}

@test "claude: sessions still on an older build are restarted on first run" {
    echo 2.1.319 >"$VERSION_FILE"
    run bash "$CLAUDE_SCRIPT"
    [ "$status" -eq 0 ]
    grep -q 'try-restart' "$CALLS"
    [ "$(claude_state)" = 2.1.319 ]
}

@test "claude: a failed update restarts nothing and keeps the state" {
    echo 2.1.319 >"$VERSION_FILE"
    mkdir -p "$XDG_STATE_HOME/claude-auto-update"
    echo 2.1.300 >"$XDG_STATE_HOME/claude-auto-update/applied-version"
    export FAIL_UPDATE=1
    run bash "$CLAUDE_SCRIPT"
    [ "$status" -ne 0 ]
    ! grep -q systemctl "$CALLS"
    [ "$(claude_state)" = 2.1.300 ]
}

@test "claude: a host without the background-sessions unit still applies the update" {
    # Regression: try-restart on a unit that is not installed exits 5, so
    # under set -e the run failed after every successful update, never
    # recorded the version, and the unit showed as failed every hour.
    echo 2.1.319 >"$VERSION_FILE"
    echo 2.1.320 >"$NEXT_VERSION_FILE"
    export BACKGROUND_LOAD_STATE=not-found
    run bash "$CLAUDE_SCRIPT"
    [ "$status" -eq 0 ]
    ! grep -q 'try-restart.*claude-background-sessions.service' "$CALLS"
    grep -qF "systemctl --user try-restart claude-remote-control@*.service" "$CALLS"
    [ "$(claude_state)" = 2.1.320 ]
}

@test "claude: a failed restart is retried on the next run" {
    echo 2.1.320 >"$VERSION_FILE"
    export FAIL_RESTART=1
    run bash "$CLAUDE_SCRIPT"
    [ "$status" -ne 0 ]
    [ ! -e "$XDG_STATE_HOME/claude-auto-update/applied-version" ]
}

# ── Codex ───────────────────────────────────────────────────────────────────

@test "codex: unchanged release reports current and records the version" {
    echo 0.167.0 >"$VERSION_FILE"
    run bash "$CODEX_SCRIPT"
    [ "$status" -eq 0 ]
    grep -qx 'codex update' "$CALLS"
    [[ "$output" == *"already current"* ]]
    [ "$(codex_state)" = 0.167.0 ]
}

@test "codex: a new release is reported and recorded" {
    echo 0.167.0 >"$VERSION_FILE"
    echo 0.168.0 >"$NEXT_VERSION_FILE"
    run bash "$CODEX_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"from 0.167.0 to 0.168.0"* ]]
    [ "$(codex_state)" = 0.168.0 ]
}

@test "codex: a failed update keeps the recorded version" {
    echo 0.167.0 >"$VERSION_FILE"
    mkdir -p "$XDG_STATE_HOME/codex-auto-update"
    echo 0.160.0 >"$XDG_STATE_HOME/codex-auto-update/installed-version"
    export FAIL_UPDATE=1
    run bash "$CODEX_SCRIPT"
    [ "$status" -ne 0 ]
    [ "$(codex_state)" = 0.160.0 ]
}

# ── Home Manager units ──────────────────────────────────────────────────────

# Evaluate the unit facts once per file: every `nix eval` of path:nix copies
# the flake into the store and re-evaluates it. A failure is recorded, not
# raised, so the script tests above still run.
setup_file() {
    export HM_JSON="$BATS_FILE_TMPDIR/hm.json"
    REPO_NIX="$(cd "$BATS_TEST_DIRNAME/../../nix" && pwd)" nix eval --json --impure --expr '
      let hm = (builtins.getFlake "path:${builtins.getEnv "REPO_NIX"}").homeConfigurations.linux-desktop.config;
      in {
        timers = [ hm.systemd.user.timers.claude-auto-update.Timer hm.systemd.user.timers.codex-auto-update.Timer ];
        force = builtins.map (n: hm.xdg.configFile."systemd/user/${n}".force) [
          "claude-auto-update.service" "claude-auto-update.timer"
          "codex-auto-update.service" "codex-auto-update.timer"
          "timers.target.wants/claude-auto-update.timer"
          "timers.target.wants/codex-auto-update.timer" ];
      }' >"$HM_JSON" 2>"$BATS_FILE_TMPDIR/hm.err" || true
}

# hm_value <key>: one fact from the evaluation above.
hm_value() {
    [ -s "$HM_JSON" ] || { cat "$BATS_FILE_TMPDIR/hm.err" >&2; return 1; }
    jq -c --arg k "$1" '.[$k]' "$HM_JSON"
}

@test "units: both timers are hourly calendar timers that catch up missed runs" {
    run hm_value timers
    [ "$status" -eq 0 ]
    jq -e 'length == 2 and all(.[]; .OnCalendar == "hourly" and .Persistent == true
                    and (has("OnUnitActiveSec") | not))' <<<"$output"
}

@test "units: Home Manager may replace the old hand-made unit files" {
    run hm_value force
    [ "$status" -eq 0 ]
    jq -e 'length == 6 and all(. == true)' <<<"$output"
}
