#!/usr/bin/env bats
# ops/audit.sh: strict arguments, PASS/WARN/FAIL lines, exit 1 on any FAIL,
# and never a write into the repository. Everything runs against a copy of the
# repository (a throwaway git checkout) with a PATH that holds only symlinks to
# the generic tools plus recording stubs for res, chezmoi, systemctl, nix and
# codebase-memory-mcp, so the result never depends on this machine.

load ../lib/contract

TOOLS=(bash env git jq awk sed grep head tail cut sort uniq wc tr paste mktemp rm date stat
    uname dirname basename find cat diff mkdir touch sleep ls readlink cp mv tee xargs)

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset TMUX SYS_UPDATE_STATE_DIR HM_PROFILE_MANIFEST
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    FIX="$BATS_TEST_TMPDIR/fix"; mkdir -p "$FIX"
    CALLS="$BATS_TEST_TMPDIR/calls"; : >"$CALLS"
    COPY="$BATS_TEST_TMPDIR/repo"
    repo_copy "$COPY"
    # ci.sh is the real gate (nix flake check, the whole bats suite): stub it.
    printf '#!/usr/bin/env bash\necho "ci.sh $*" >>"%s"\nexit "${STUB_CI_RC:-0}"\n' "$CALLS" >"$COPY/ops/ci.sh"
    git -C "$COPY" init -q
    git -C "$COPY" add -A
    git -C "$COPY" -c user.email=t@t -c user.name=t commit -q -m init
    make_path
    default_fixtures
}

make_path() {
    BIN="$BATS_TEST_TMPDIR/bin"; mkdir -p "$BIN"
    local t
    for t in "${TOOLS[@]}"; do ln -sf "$(command -v "$t")" "$BIN/$t"; done
    cat >"$BIN/res" <<EOF
#!/usr/bin/env bash
echo "res \$* [AI_LOG_DIR=\${AI_LOG_DIR:-}]" >>"$CALLS"
[[ -n "\${STUB_RES_WRITE:-}" ]] && { mkdir -p .ai-logs; : >.ai-logs/run; }
case "\$1 \$2" in
  "arch check") echo "Gate    stub"; exit "\${STUB_ARCH_RC:-0}" ;;
  "refactor scan") cat "$FIX/scan.json" ;;
  "refactor-scan dupes") cat "$FIX/dupes.json" ;;
  "verify shell") cat "$FIX/shell.json"; exit 1 ;;
  "git history")
    case "\$3" in
      missing-companions) cat "$FIX/mc.json" ;;
      rework) cat "$FIX/rw.json" ;;
      hotspots) cat "$FIX/hs.json" ;;
    esac ;;
esac
EOF
    cat >"$BIN/chezmoi" <<EOF
#!/usr/bin/env bash
echo "chezmoi \$*" >>"$CALLS"
case "\$1" in
  status) cat "$FIX/chezmoi-status" ;;
  target-path) echo "$HOME" ;;
  source-path) cat "$FIX/chezmoi-source" 2>/dev/null || echo "/src/home/dot_x" ;;
esac
EOF
    cat >"$BIN/systemctl" <<EOF
#!/usr/bin/env bash
echo "systemctl \$*" >>"$CALLS"
[[ -f "$FIX/systemctl-fail" ]] && { echo "Failed to connect to bus"; exit 1; }
cat "$FIX/failed-units" 2>/dev/null; exit 0
EOF
    cat >"$BIN/nix" <<EOF
#!/usr/bin/env bash
echo "nix \$*" >>"$CALLS"
[[ "\$1" == eval ]] && cat "$FIX/nix-out" 2>/dev/null
exit 0
EOF
    cat >"$BIN/codebase-memory-mcp" <<EOF
#!/usr/bin/env bash
echo "codebase-memory-mcp \$*" >>"$CALLS"
cat "$FIX/cbm.json"
EOF
    chmod +x "$BIN"/res "$BIN"/chezmoi "$BIN"/systemctl "$BIN"/nix "$BIN"/codebase-memory-mcp
}

default_fixtures() {
    echo '{"ranking":[{"path":"ops/a.sh","priority":50,"severity":"warning"},{"path":"ops/b.sh","priority":40,"severity":"warning"}]}' >"$FIX/scan.json"
    echo '{"content":{"dupes":{"rate":1.2}}}' >"$FIX/dupes.json"
    shell_json passed
    echo '{"result":{"companions":[]}}' >"$FIX/mc.json"
    echo '{"result":{"files":[]}}' >"$FIX/rw.json"
    echo '{"result":{"files":[]}}' >"$FIX/hs.json"
    : >"$FIX/chezmoi-status"
    echo '{"content":[{"type":"text","text":"projects: 1  (cols: name root_path branch)\n  Good / main"}]}' >"$FIX/cbm.json"
    export HOST_PROFILE=linux-desktop
    export SYS_UPDATE_STATE_DIR="$BATS_TEST_TMPDIR/sysupdate"
    mkdir -p "$SYS_UPDATE_STATE_DIR/runs"
    sysupdate_run done 0
}

# shell_json passed | shell_json PATH 'SC1234 (error)' | shell_json syntax PATH
shell_json() {
    if [ "$1" = passed ]; then
        echo '{"files":[{"path":"ops/a.sh","checks":[{"check":"syntax","status":"passed"},{"check":"shellcheck","status":"passed"}]}]}' >"$FIX/shell.json"
    elif [ "$1" = syntax ]; then
        jq -n --arg p "$2" '{files:[{path:$p,checks:[{check:"syntax",status:"failed"},{check:"shellcheck",status:"passed"}]}]}' >"$FIX/shell.json"
    else
        jq -n --arg p "$1" --arg o "In $1 line 1:\n^-- $2: msg" '{files:[{path:$p,checks:[{check:"syntax",status:"passed"},{check:"shellcheck",status:"failed",output:$o}]}]}' >"$FIX/shell.json"
    fi
}

sysupdate_run() { # status exit_code
    local m="$SYS_UPDATE_STATE_DIR/runs/20261114T000000Z-1.meta"
    printf 'run_id=x\nlog=/l/x.log\nstatus=started\nstatus=%s\n' "$1" >"$m"
    [ -z "${2:-}" ] || printf 'exit_code=%s\n' "$2" >>"$m"
    printf '%s\n' "$m" >"$SYS_UPDATE_STATE_DIR/last-run"
}

audit() { run env -i PATH="$BIN" HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" TERM=dumb \
    HOST_PROFILE="${HOST_PROFILE:-}" SYS_UPDATE_STATE_DIR="$SYS_UPDATE_STATE_DIR" \
    ${HM_PROFILE_MANIFEST:+HM_PROFILE_MANIFEST="$HM_PROFILE_MANIFEST"} \
    ${STUB_CI_RC:+STUB_CI_RC="$STUB_CI_RC"} ${STUB_ARCH_RC:+STUB_ARCH_RC="$STUB_ARCH_RC"} \
    ${STUB_RES_WRITE:+STUB_RES_WRITE="$STUB_RES_WRITE"} \
    bash "$COPY/ops/audit.sh" "$@"; }

# -- arguments -----------------------------------------------------------------

@test "--help and -h print usage, exit 0 and run nothing" {
    local a
    for a in --help -h; do
        audit "$a"
        [ "$status" -eq 0 ]
        [[ "$output" == *"Usage: bash ops/audit.sh"* ]]
        [ ! -s "$CALLS" ] || { cat "$CALLS"; return 1; }
    done
}

@test "an unknown argument exits 2 and runs nothing" {
    audit --deep --bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown argument: --bogus"* ]]
    [ ! -s "$CALLS" ]
}

# -- --ci ----------------------------------------------------------------------

@test "--ci runs ops/ci.sh: PASS on success, FAIL and exit 1 on failure" {
    audit --ci
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS  ci: ops/ci.sh passed"* ]]
    grep -q '^ci.sh' "$CALLS"
    if grep -q '^res ' "$CALLS"; then return 1; fi
    STUB_CI_RC=1 audit --ci
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  ci: ops/ci.sh failed"* ]]
    [[ "$output" == *"FAIL 1"* ]]
}

# -- --deep --------------------------------------------------------------------

@test "--deep with clean findings: PASS lines, exit 0, restsift output outside the repo" {
    audit --deep
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"PASS  arch:"* ]]
    [[ "$output" == *"PASS  refactor: no target at priority >= 90"* ]]
    [[ "$output" == *"PASS  dupes: duplicate rate 1.2%"* ]]
    [[ "$output" == *"PASS  shell: 1 scripts"* ]] || [[ "$output" == *"PASS  shell:"* ]]
    [[ "$output" == *"PASS  worktree: unchanged"* ]]
    [[ "$output" == *"FAIL 0"* ]]
    # AI_LOG_DIR points at a temp dir, never into the checkout.
    local dir; dir="$(sed -nE 's/.*\[AI_LOG_DIR=([^]]*)\]/\1/p' "$CALLS" | head -n1)"
    [ -n "$dir" ]
    [[ "$dir" != "$COPY"* ]]
    # The history range is origin/main..HEAD or, without origin, HEAD~20 (absent here: skipped).
    [[ "$output" == *"history:"* ]]
}

@test "--deep advisory findings are WARN and do not fail the audit" {
    echo '{"content":{"dupes":{"rate":5.5}}}' >"$FIX/dupes.json"
    echo '{"result":{"companions":[{"path":"tests/bash/x.bats","status":"live","associations":[{"changed_file":"ops/x.sh"}]},{"path":"old.md","status":"deleted","associations":[{"changed_file":"ops/x.sh"}]}]}}' >"$FIX/mc.json"
    echo '{"result":{"files":[{"path":"ops/hot.sh","status":"live","adjusted":{"touches":9,"windows":{"7d":{"rework_rate":0.8}}}}]}}' >"$FIX/rw.json"
    echo '{"result":{"files":[{"path":"ops/fixy.sh","status":"live","adjusted":{"touches":9,"fix_touch_ratio":0.77}},{"path":"ops/calm.sh","status":"live","adjusted":{"touches":9,"fix_touch_ratio":0.1}},{"path":"ops/few.sh","status":"live","adjusted":{"touches":2,"fix_touch_ratio":1}},{"path":"gone.sh","status":"deleted","adjusted":{"touches":9,"fix_touch_ratio":0.9}}]}}' >"$FIX/hs.json"
    git -C "$COPY" update-ref refs/remotes/origin/main HEAD~0
    printf '\n' >>"$COPY/README.md"; git -C "$COPY" -c user.email=t@t -c user.name=t commit -qam two
    audit --deep
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"WARN  dupes: duplicate rate 5.5% is above 3%"* ]]
    [[ "$output" == *"WARN  history:"* ]]
    [[ "$output" == *"tests/bash/x.bats  (usually changes with ops/x.sh)"* ]]
    [[ "$output" != *"old.md"* ]]
    [[ "$output" == *"WARN  rework:"*"ops/hot.sh  9 touches, 80% reworked within 7 days"* ]]
    [[ "$output" == *"WARN  hotspots:"*"ops/fixy.sh  77% of 9 touches were fixes"* ]]
    [[ "$output" != *"ops/calm.sh"* && "$output" != *"ops/few.sh"* && "$output" != *"gone.sh"* ]]
    [[ "$output" == *"FAIL 0"* ]]
}

@test "--deep FAILs on a CRITICAL refactor target and prints the top 5" {
    echo '{"ranking":[{"path":"a1","priority":95,"severity":"critical"},{"path":"a2","priority":80,"severity":"error"},{"path":"a3","priority":70,"severity":"error"},{"path":"a4","priority":60,"severity":"warning"},{"path":"a5","priority":50,"severity":"warning"},{"path":"a6","priority":40,"severity":"warning"}]}' >"$FIX/scan.json"
    audit --deep
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  refactor: 1 target(s) at priority >= 90"* ]]
    [[ "$output" == *"95  critical"*"a1"* ]]
    [[ "$output" == *"a5"* ]]
    [[ "$output" != *"a6"* ]]
}

@test "--deep FAILs when the arch gate fails" {
    STUB_ARCH_RC=1 audit --deep
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  arch:"* ]]
}

@test "--deep shell: SC2148 under nix/modules/home/scripts is expected, anywhere else is a FAIL" {
    shell_json nix/modules/home/scripts/x.sh 'SC2148 (error)'
    audit --deep
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"PASS  shell:"* ]]
    shell_json ops/x.sh 'SC2148 (error)'
    audit --deep
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  shell:"*"ops/x.sh: ShellCheck error SC2148"* ]]
    shell_json ops/y.sh 'SC2086 (error)'
    audit --deep
    [ "$status" -eq 1 ]
    [[ "$output" == *"ops/y.sh: ShellCheck error SC2086"* ]]
    shell_json nix/modules/home/scripts/x.sh 'SC2086 (error)'
    audit --deep
    [ "$status" -eq 1 ]
    shell_json ops/z.sh 'SC2034 (warning)'
    audit --deep
    [ "$status" -eq 0 ]
    shell_json syntax ops/broken.sh
    audit --deep
    [ "$status" -eq 1 ]
    [[ "$output" == *"ops/broken.sh: syntax error"* ]]
}

@test "--deep without restsift: FAIL with an install hint; --allow-missing-restsift makes it a WARN" {
    rm "$BIN/res"
    audit --deep
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  deep: restsift (res) not found. Install:"* ]]
    audit --deep --allow-missing-restsift
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  deep: restsift (res) not found"* ]]
}

@test "--deep FAILs when a restsift check writes into the repository" {
    STUB_RES_WRITE=1 audit --deep
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  worktree: the restsift checks changed the repository"* ]]
}

# -- --live --------------------------------------------------------------------

@test "--live on a healthy machine: PASS lines, exit 0" {
    audit --live
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"PASS  chezmoi: managed files in sync"* ]]
    [[ "$output" == *"PASS  systemd: no failed user units"* ]]
    [[ "$output" == *"PASS  sys-update: last run succeeded"* ]]
    [[ "$output" == *"PASS  checkout:"* ]]
    [[ "$output" == *"PASS  cbm: every indexed project root exists"* ]]
    [[ "$output" == *"PASS  worktree: unchanged by the live checks"* ]]
    # Read-only: the stubs saw no mutating subcommand.
    if grep -qE '^(chezmoi (apply|add|forget|update)|systemctl .*(start|enable|restart|stop)|nix (build|profile)|codebase-memory-mcp cli .*delete_project)' "$CALLS"; then return 1; fi
}

@test "--live chezmoi: pending is WARN, a hand-edited managed file is FAIL, a modify_ target is not" {
    printf ' M .config/x\n' >"$FIX/chezmoi-status"
    audit --live
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  chezmoi: 1 pending change(s)"* ]]
    printf 'MM .bashrc\n' >"$FIX/chezmoi-status"
    echo /src/home/dot_bashrc.tmpl >"$FIX/chezmoi-source"
    audit --live
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  chezmoi: 1 managed file(s) edited by hand"*".bashrc"* ]]
    echo /src/home/dot_claude/modify_settings.json.tmpl >"$FIX/chezmoi-source"
    printf 'MM .claude/settings.json\n' >"$FIX/chezmoi-status"
    audit --live
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  chezmoi: 1 pending"* ]]
}

@test "--live systemd: a failed user unit is a FAIL, an unreachable manager a WARN" {
    printf 'foo.service loaded failed failed Foo\nbar.service loaded failed failed Bar\n' >"$FIX/failed-units"
    audit --live
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  systemd: failed user unit(s): foo.service bar.service"* ]]
    : >"$FIX/systemctl-fail"
    audit --live
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  systemd: cannot query the user manager"* ]]
}

@test "--live nix-profile: a colliding hand-installed package is a FAIL, an unbuilt package a WARN" {
    export HM_PROFILE_MANIFEST="$BATS_TEST_TMPDIR/manifest.json"
    local out="$BATS_TEST_TMPDIR/hm-out" pkg="$BATS_TEST_TMPDIR/pkg"
    mkdir -p "$out/home-path/bin" "$pkg/bin"
    : >"$out/home-path/bin/foo"; : >"$pkg/bin/foo"
    printf '%s' "$out" >"$FIX/nix-out"
    jq -n --arg p "$pkg" '{version:3,elements:{foo:{storePaths:[$p]}}}' >"$HM_PROFILE_MANIFEST"
    audit --live
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  nix-profile: hand-installed package(s) collide with Home Manager: foo ships bin/foo"* ]]
    [[ "$output" == *"nix profile remove foo"* ]]
    # no overlap
    rm "$pkg/bin/foo"; : >"$pkg/bin/other"
    audit --live
    [[ "$output" == *"PASS  nix-profile: no collision"* ]]
    # package not built: WARN and skip, never a build
    printf '%s' "$BATS_TEST_TMPDIR/not-built" >"$FIX/nix-out"
    audit --live
    [[ "$output" == *"WARN  nix-profile: the linux-desktop activation package is not built yet"* ]]
    if grep -q '^nix build' "$CALLS"; then return 1; fi
}

@test "--live sys-update: a failed or unfinished run is a FAIL, none or an old one a WARN" {
    sysupdate_run failed 1
    audit --live
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  sys-update: last run failed with exit code 1"* ]]
    sysupdate_run started ""
    audit --live
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  sys-update: last run never finished"* ]]
    sysupdate_run done 0
    touch -d '30 days ago' "$SYS_UPDATE_STATE_DIR/runs/20261114T000000Z-1.meta"
    audit --live
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  sys-update: last run succeeded 30 days ago"* ]]
    rm -rf "$SYS_UPDATE_STATE_DIR"
    audit --live
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  sys-update: no run recorded"* ]]
}

@test "--live main checkout: uncommitted changes are a WARN that lists the files" {
    printf 'x\n' >"$COPY/stray.txt"
    printf 'y\n' >>"$COPY/README.md"
    audit --live
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  checkout:"*"2 uncommitted change(s)"* ]]
    [[ "$output" == *"?? stray.txt"* ]]
    [[ "$output" == *" M README.md"* ]]
}

@test "--live codebase-memory: projects under /tmp or with a missing root are a WARN with the delete command" {
    local text='projects: 3  (cols: name root_path branch)\n  Good / main\n  tmp-x-repo /tmp/x/repo -\n  gone-one '"$BATS_TEST_TMPDIR"'/does-not-exist main'
    printf '{"content":[{"type":"text","text":"%s"}]}\n' "$text" >"$FIX/cbm.json"
    audit --live
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  cbm: 2 indexed project(s) live under /tmp or no longer exist"* ]]
    [[ "$output" == *"codebase-memory-mcp cli delete_project --project tmp-x-repo"* ]]
    [[ "$output" == *"codebase-memory-mcp cli delete_project --project gone-one"* ]]
    [[ "$output" != *"--project Good"* ]]
    rm "$BIN/codebase-memory-mcp"
    audit --live
    [[ "$output" == *"WARN  cbm: codebase-memory-mcp not installed"* ]]
}

@test "--live without its tools degrades to WARN, never FAIL" {
    rm "$BIN/chezmoi" "$BIN/systemctl" "$BIN/nix" "$BIN/codebase-memory-mcp"
    audit --live
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"WARN  chezmoi: not installed"* ]]
    [[ "$output" == *"WARN  systemd: systemctl not found"* ]]
    [[ "$output" == *"WARN  cbm: codebase-memory-mcp not installed"* ]]
}

# -- default mode and the read-only guarantee ----------------------------------

@test "no flag runs ci, deep and live; missing restsift only warns" {
    rm "$BIN/res"
    audit
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"== ci =="* && "$output" == *"== deep (restsift) =="* && "$output" == *"== live"* ]]
    [[ "$output" == *"WARN  deep: restsift (res) not found"* ]]
    [[ "$output" == *"PASS  ci:"* ]]
}

@test "the whole audit never writes into the repository" {
    git -C "$COPY" status --porcelain --ignored >"$BATS_TEST_TMPDIR/before"
    audit
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    git -C "$COPY" status --porcelain --ignored >"$BATS_TEST_TMPDIR/after"
    diff "$BATS_TEST_TMPDIR/before" "$BATS_TEST_TMPDIR/after"
    [ ! -e "$COPY/.ai-logs" ]
}

# -- wiring --------------------------------------------------------------------

@test "mise exposes audit, audit:ci, audit:deep and audit:live" {
    local t
    for t in audit audit:ci audit:deep audit:live; do
        grep -qE "^\[tasks\.\"?$t\"?\]" "$REPO_ROOT/mise.toml" || { echo "no task $t"; return 1; }
    done
    grep -q 'bash ops/audit.sh --deep' "$REPO_ROOT/mise.toml"
    grep -q 'bash ops/audit.sh --live' "$REPO_ROOT/mise.toml"
    grep -q 'bash ops/audit.sh --ci' "$REPO_ROOT/mise.toml"
}

@test "the arch gate in audit.sh is the one in the arch:check mise task (twin guard)" {
    local cmd='arch check --grade source --loc --fragmentation --subdirs-warn-at 12 --depth-warn-at 6'
    grep -qF "$cmd --fail-on-findings --fail-grade error" "$REPO_ROOT/mise.toml"
    grep -qF "res $cmd" "$REPO_ROOT/ops/audit.sh"
}

@test "the hand-edited-managed-file test is the one ops/update-all.sh uses (twin guard)" {
    local rule='substr($0,1,1)=="M" && substr($0,2,1)!=" " {print substr($0,4)}'
    grep -qF "$rule" "$REPO_ROOT/ops/update-all.sh"
    grep -qF "$rule" "$REPO_ROOT/ops/audit.sh"
}
