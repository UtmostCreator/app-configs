#!/usr/bin/env bats
# The weekly `ops/audit.sh --live` user timer (nix/modules/home/audit.nix and
# nix/modules/home/scripts/repo-audit.sh):
#   - the unit and the timer exist on every Linux Home Manager host and run
#     the audit through the chezmoi source path, like the cbm updater;
#   - a clean or WARN-only audit stays quiet, a FAIL sends one notification,
#     and the audit output always lands on stderr/stdout (the journal);
#   - the unit itself never fails because the audit found something, or the
#     next audit would report the unit as a failed user unit.
# Everything runs against a scratch repo and PATH stubs.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/nix/modules/home/scripts/repo-audit.sh"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    FAKE="$BATS_TEST_TMPDIR/dotfiles"; mkdir -p "$FAKE/home" "$FAKE/ops"
    CALLS="$BATS_TEST_TMPDIR/calls"; : >"$CALLS"
    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    printf '#!/bin/sh\necho "$FAKE/home"\n' >"$STUBS/chezmoi"
    printf '#!/bin/sh\necho "notify-send $*" >>"%s"\n[ -z "$NOTIFY_FAIL" ]\n' "$CALLS" >"$STUBS/notify-send"
    cat >"$FAKE/ops/audit.sh" <<'EOF'
#!/usr/bin/env bash
echo "args: $*" >>"$CALLS"
printf '%b' "$AUDIT_OUT"
exit "${AUDIT_RC:-0}"
EOF
    chmod +x "$STUBS"/*
    export FAKE CALLS
}

run_unit() { run env PATH="$STUBS:$PATH" FAKE="$FAKE" CALLS="$CALLS" "$@" bash "$SCRIPT"; }

@test "runs ops/audit.sh --live from the chezmoi source dir's parent" {
    run_unit AUDIT_OUT='PASS  chezmoi: ok\n'
    [ "$status" -eq 0 ]
    grep -qx 'args: --live' "$CALLS"
    [[ "$output" == *"PASS  chezmoi: ok"* ]]
}

@test "a clean audit sends no notification" {
    run_unit AUDIT_OUT='PASS  a\nWARN  b\n' AUDIT_RC=0
    [ "$status" -eq 0 ]
    if grep -q '^notify-send' "$CALLS"; then return 1; fi
}

@test "a FAIL sends one notification naming the failing lines, and the unit still succeeds" {
    run_unit AUDIT_OUT='PASS  a\nFAIL  systemd: failed user unit(s): foo.service\nFAIL  chezmoi: 1 managed file(s) edited by hand\n' AUDIT_RC=1
    [ "$status" -eq 0 ]
    [ "$(grep -c '^notify-send' "$CALLS")" -eq 1 ]
    grep -q 'notify-send .*Repo audit.*2 FAIL' "$CALLS"
    grep -q 'foo.service' "$CALLS"
    [[ "$output" == *"FAIL  systemd: failed user unit(s): foo.service"* ]]
}

@test "when notify-send fails and there is no Windows host, the unit still succeeds" {
    run_unit AUDIT_OUT='FAIL  x\n' AUDIT_RC=1 NOTIFY_FAIL=1 WINDOWS_POWERSHELL=/nonexistent
    [ "$status" -eq 0 ]
}

@test "a missing audit script is an error, not silence" {
    rm "$FAKE/ops/audit.sh"
    run_unit
    [ "$status" -ne 0 ]
    [[ "$output" == *"audit.sh"* ]]
}

@test "the toast follows the ai-auth-status approach (same Windows toast AppId)" {
    local id='{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}'
    grep -qF "$id" "$REPO_ROOT/nix/modules/home/scripts/ai-auth-status.sh"
    grep -qF "$id" "$SCRIPT"
}

# ── Home Manager unit and timer (nix eval, once per file) ────────────────────

setup_file() {
    export HM_JSON="$BATS_FILE_TMPDIR/hm.json"
    REPO_NIX="$(cd "$BATS_TEST_DIRNAME/../../nix" && pwd)" nix eval --json --impure --expr '
      let
        flake = builtins.getFlake "path:${builtins.getEnv "REPO_NIX"}";
        facts = host:
          let u = flake.homeConfigurations.${host}.config.systemd.user; in {
            timer = u.timers.repo-audit.Timer;
            wanted = u.timers.repo-audit.Install.WantedBy;
            service = {
              type = u.services.repo-audit.Service.Type;
              execStart = u.services.repo-audit.Service.ExecStart;
              env = u.services.repo-audit.Service.Environment;
            };
          };
      in builtins.listToAttrs (map (h: { name = h; value = facts h; }) [ "linux-desktop" "linux-cli" "wsl" ])' \
        >"$HM_JSON" 2>"$BATS_FILE_TMPDIR/hm.err" || true
}

hm_value() { # <jq filter>
    [ -s "$HM_JSON" ] || { cat "$BATS_FILE_TMPDIR/hm.err" >&2; return 1; }
    jq -c "$1" "$HM_JSON"
}

@test "units: repo-audit timer is a weekly persistent calendar timer on every Linux host" {
    run hm_value '[.[] | .timer]'
    [ "$status" -eq 0 ]
    jq -e 'length == 3 and all(.[]; (.OnCalendar | test("^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) ")) and .Persistent == true)' <<<"$output"
    run hm_value '[.[] | .wanted]'
    jq -e 'all(.[]; . == ["timers.target"])' <<<"$output"
}

@test "units: repo-audit service is a oneshot that can reach chezmoi, nix, systemctl and notify-send" {
    run hm_value '[.[] | .service]'
    [ "$status" -eq 0 ]
    jq -e 'all(.[]; .type == "oneshot" and (.execStart | tostring | test("/nix/store/")))' <<<"$output"
    jq -e 'all(.[]; (.env | tostring) | test("systemd") and test("libnotify") and test("/bin"))' <<<"$output"
}
