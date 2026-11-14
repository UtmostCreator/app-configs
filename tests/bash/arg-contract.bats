#!/usr/bin/env bats
# Argument contract for every script a user can reach from an entry point
# (mise tasks, ~/.local/bin helpers, fish functions, zsh aliases):
#
#   --help                   exits 0, prints usage, calls no mutating tool
#   --definitely-not-a-flag  exits non-zero (not a timeout, not "command not
#                            found") and calls no mutating tool
#
# Bug type 2 ("arguments silently ignored"): a script without a parser ran its
# full job for `--help` or a typo, and `--dry-run` once ran a real install.
#
# Each script runs in a sandbox: a copy of the repository under
# $BATS_TEST_TMPDIR, a scratch HOME and XDG dirs, an empty environment, and a
# PATH whose first entries are recording stubs for every mutating tool. Any
# stub call is a violation. See tests/lib/contract.bash for how entry points
# are discovered.

load ../lib/contract

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    MUTATORS=(home-manager nixos-rebuild darwin-rebuild nix chezmoi systemctl
        tailscale brew tmux docker colima code sudo)
}

# -- Allowlist ---------------------------------------------------------------
# Format: [path]="reason". Keep it minimal. Two kinds of entry:
#   justified: the interface really cannot support the check.
#   finding:   a real violation found when this test was written, recorded so
#              the suite stays green; fix the script, then delete the entry
#              (the "waivers are still needed" test fails once it is fixed).
# A waiver covers one check only (help or flag).
declare -gA WAIVE_HELP=(
    # --- justified: positional-only helpers, `--help` is taken as an operand
    [home/dot_local/bin/executable_ports]="justified: positional PORT only"
    [home/dot_local/bin/executable_killport]="justified: positional PORT only, usage goes to stderr with exit 1"
    [home/dot_local/bin/executable_logtop]="justified: positional FILE only, usage goes to stderr"
    [home/dot_local/bin/executable_psmem]="justified: positional N only"
    [home/dot_local/bin/executable_topn]="justified: positional N only"
    [home/dot_local/bin/executable_conns]="justified: positional only"
    [home/dot_local/bin/executable_rgc]="justified: positional pattern only"
    [home/dot_local/bin/executable_clipcopy]="justified: reads stdin, no options"
    [home/dot_local/bin/executable_wsl-open]="justified: positional path/URL only"
    [home/dot_local/bin/executable_dsh-remote]="justified: forwards every argument to the remote shell"
    [ops/ci-local.sh]="justified: arguments are the command to run inside the clean env"
    # --- finding: no help handling
    [home/dot_local/bin/executable_dsh-remote-status]="finding: --help runs tailscale"
    [ops/projects/github/sync-main.sh]="finding: --help exits 1"
    [ops/projects/health/dashboard.sh]="finding: --help starts the dashboard loop"
    [ops/projects/health/monitor.sh]="finding: --help starts the monitor loop"
    [ops/projects/health/verify-workspace.sh]="finding: --help runs the verification"
    [ops/projects/logging/watch/watch.sh]="finding: --help exits 1"
    [ops/projects/repo-checks.sh]="finding: --help exits 1"
    [ops/projects/workspace/stack/start.sh]="finding: --help exits 1"
)
declare -gA WAIVE_FLAG=(
    [home/dot_local/bin/executable_conns]="justified: positional N only; pipes into the sibling topn helper, which is not on the sandbox PATH"
    [home/dot_local/bin/executable_dsh-remote-status]="finding: unknown flag runs tailscale"
    [ops/ci-local.sh]="justified: arguments are the command to run inside the clean env"
    [ops/projects/health/dashboard.sh]="finding: unknown flag starts the dashboard loop"
    [ops/projects/health/monitor.sh]="finding: unknown flag starts the monitor loop"
    [ops/projects/health/verify-workspace.sh]="finding: unknown flag runs the verification"
)

# -- Sandbox -----------------------------------------------------------------
# sandbox_init DIR: scratch HOME and recording stubs under DIR.
sandbox_init() {
    SB="$1"
    SB_HOME="$SB/home"; SB_STUBS="$SB/bin"; SB_CALLS="$SB/calls"
    mkdir -p "$SB_HOME" "$SB_STUBS" "$SB/run"
    chmod 700 "$SB/run"
    : >"$SB_CALLS"
    # The helpers this repo installs into ~/.local/bin (topn, killport, ...)
    # exist on the developer's machine and not in CI: keep them off the PATH so
    # the result does not depend on which one it is.
    SB_PATH="$(printf '%s' "$PATH" | tr : '\n' | grep -v '/\.local/bin$' | paste -sd: -)"
    local t realgit
    for t in "${MUTATORS[@]}"; do
        printf '#!/bin/sh\necho "%s $*" >>"%s"\nexit 1\n' "$t" "$SB_CALLS" >"$SB_STUBS/$t"
        chmod +x "$SB_STUBS/$t"
    done
    # git: reads pass through, history-writing subcommands are recorded.
    realgit="$(command -v git)"
    cat >"$SB_STUBS/git" <<EOF
#!/bin/sh
for a in "\$@"; do
    case "\$a" in push|commit) echo "git \$*" >>"$SB_CALLS"; exit 1 ;; esac
done
exec "$realgit" "\$@"
EOF
    chmod +x "$SB_STUBS/git"
}

# probe ROOT SCRIPT ARG: run SCRIPT with ARG in the sandbox, from ROOT.
# Sets PROBE_STATUS, PROBE_OUT, PROBE_CALLS.
probe() {
    local root="$1" script="$2" arg="$3" interp=(bash)
    [[ "$script" == *.py ]] && interp=(python3 -I)
    : >"$SB_CALLS"
    PROBE_OUT="$(cd "$root" && env -i PATH="$SB_STUBS:$SB_PATH" HOME="$SB_HOME" \
        XDG_CONFIG_HOME="$SB_HOME/.config" XDG_DATA_HOME="$SB_HOME/.local/share" \
        XDG_STATE_HOME="$SB_HOME/.local/state" XDG_CACHE_HOME="$SB_HOME/.cache" \
        XDG_RUNTIME_DIR="$SB/run" TMPDIR="$SB" TERM=dumb LANG=C USER="${USER:-x}" \
        NIX_PATH_REFRESH=0 BATS_TEST_TMPDIR="$BATS_TEST_TMPDIR" \
        timeout "${PROBE_TIMEOUT:-8}" "${interp[@]}" "$script" "$arg" </dev/null 2>&1)"
    PROBE_STATUS=$?
    PROBE_CALLS="$(tr '\n' ';' <"$SB_CALLS")"
}

# check_help / check_flag: print a reason and return 1 on a violation.
check_help() {
    probe "$1" "$2" --help
    [ "$PROBE_STATUS" -eq 0 ] || { echo "--help exited $PROBE_STATUS"; return 1; }
    [ -z "$PROBE_CALLS" ] || { echo "--help called: $PROBE_CALLS"; return 1; }
    grep -qiE 'usage|^# |--[a-z]' <<<"$PROBE_OUT" || { echo "--help printed no usage"; return 1; }
}

check_flag() {
    probe "$1" "$2" --definitely-not-a-flag
    [ -z "$PROBE_CALLS" ] || { echo "unknown flag called: $PROBE_CALLS"; return 1; }
    case "$PROBE_STATUS" in
        0) echo "unknown flag exited 0"; return 1 ;;
        124) echo "unknown flag hung (timeout)"; return 1 ;;
        127) echo "unknown flag: command not found"; return 1 ;;
    esac
}

# violations ROOT CHECK [SCRIPT...]: unwaived violations, one per line.
violations() {
    local root="$1" check="$2" s why; shift 2
    local scripts=("$@")
    ((${#scripts[@]})) || mapfile -t scripts < <(entry_scripts "$root")
    for s in "${scripts[@]}"; do
        if [ "$check" = help ]; then [[ -v WAIVE_HELP[$s] ]] && continue
        else [[ -v WAIVE_FLAG[$s] ]] && continue; fi
        why="$(check_$check "$root" "$s")" || printf '%s: %s\n' "$s" "$why"
    done
}

# -- Tests -------------------------------------------------------------------

@test "discovery finds the entry points (a shrinking list would pass for the wrong reason)" {
    run entry_scripts "$REPO_ROOT"
    [ "$status" -eq 0 ]
    local want
    for want in ops/update-all.sh ops/install.sh ops/cleanup.sh ops/doctor.sh \
        ops/readiness.sh ops/system-setup.sh ops/vicinae-extension.sh \
        ops/projects/tmux/master.sh ops/projects/workspace/stop.sh \
        home/dot_local/bin/executable_killport home/dot_local/bin/executable_rgc; do
        grep -qxF "$want" <<<"$output" || { echo "not discovered: $want"; return 1; }
    done
    [ "$(wc -l <<<"$output")" -ge 40 ]
}

@test "every waiver names a discovered script and says why" {
    mapfile -t found < <(entry_scripts "$REPO_ROOT")
    local s
    for s in "${!WAIVE_HELP[@]}" "${!WAIVE_FLAG[@]}"; do
        printf '%s\n' "${found[@]}" | grep -qxF "$s" || { echo "waiver for a script that is not an entry point: $s"; return 1; }
    done
    for s in "${WAIVE_HELP[@]}" "${WAIVE_FLAG[@]}"; do
        [[ "$s" == justified:* || "$s" == finding:* ]] || { echo "waiver without justified:/finding: reason: $s"; return 1; }
    done
}

@test "every entry-point script answers --help with usage, exit 0 and no mutating call" {
    sandbox_init "$BATS_TEST_TMPDIR/sb"
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    run violations "$copy" help
    [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "every entry-point script rejects an unknown flag without a mutating call" {
    sandbox_init "$BATS_TEST_TMPDIR/sb"
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    run violations "$copy" flag
    [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "waivers are still needed: a waived check that now passes must lose its waiver" {
    sandbox_init "$BATS_TEST_TMPDIR/sb"
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    local s stale=""
    export PROBE_TIMEOUT=3
    for s in "${!WAIVE_HELP[@]}"; do
        check_help "$copy" "$s" >/dev/null || continue
        stale+=" help:$s"
    done
    for s in "${!WAIVE_FLAG[@]}"; do
        check_flag "$copy" "$s" >/dev/null || continue
        stale+=" flag:$s"
    done
    [ -z "$stale" ] || { echo "fixed, remove from the allowlist:$stale"; return 1; }
}

# -- Seeded violations: the check must notice each of these ------------------

@test "seeded: a script that ignores --help and runs a mutating tool is caught" {
    sandbox_init "$BATS_TEST_TMPDIR/sb"
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '#!/usr/bin/env bash\nnix profile install nixpkgs#hello\n' >"$copy/ops/seeded-noargs.sh"
    run violations "$copy" help ops/seeded-noargs.sh
    [[ "$output" == *"ops/seeded-noargs.sh: --help"* ]] || { echo "not caught: $output"; return 1; }
    run violations "$copy" flag ops/seeded-noargs.sh
    [[ "$output" == *"ops/seeded-noargs.sh: unknown flag called: nix"* ]] || { echo "not caught: $output"; return 1; }
}

@test "seeded: a script that exits 0 on an unknown flag is caught" {
    sandbox_init "$BATS_TEST_TMPDIR/sb"
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '#!/usr/bin/env bash\necho "usage: x"\nexit 0\n' >"$copy/ops/seeded-lenient.sh"
    run violations "$copy" flag ops/seeded-lenient.sh
    [[ "$output" == *"unknown flag exited 0"* ]] || { echo "not caught: $output"; return 1; }
    run violations "$copy" help ops/seeded-lenient.sh
    [ -z "$output" ]
}

@test "seeded: regressing doctor.sh to ignore its arguments is caught" {
    sandbox_init "$BATS_TEST_TMPDIR/sb"
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '#!/usr/bin/env bash\nchezmoi verify\n' >"$copy/ops/doctor.sh"
    run violations "$copy" help ops/doctor.sh
    [[ "$output" == *"ops/doctor.sh: --help"* ]]
    run violations "$copy" flag ops/doctor.sh
    [[ "$output" == *"ops/doctor.sh: unknown flag"* ]]
}

@test "seeded: a new fish function calling an unparsed script puts it under the contract" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '#!/usr/bin/env bash\ntrue\n' >"$copy/ops/seeded-new.sh"
    printf 'function seeded\n    bash "$DOTFILES_DIR/ops/seeded-new.sh" $argv\nend\n' \
        >>"$copy/home/dot_config/fish/conf.d/dotfiles.fish.tmpl"
    run entry_scripts "$copy"
    grep -qxF ops/seeded-new.sh <<<"$output"
}
