#!/usr/bin/env bats
# One implementation per cross-cutting step (bug type 10, "orchestration
# ordering", and the twin drift between install / bootstrap / update-all /
# system-setup). Fixing a step in one copy while its twin keeps the old
# behaviour is how a failed switch once removed home-manager-path and how
# only update-all.sh checked for profile conflicts.
#
#   1. `home-manager switch` runs only through ops/lib/hm-switch.sh.
#   2. The WSL1 refusal, nix-username check and bats real-HOME guard live in
#      ops/lib/preflight.sh; install.sh and bootstrap.sh call them, they do not
#      carry their own copy.
#   3. Every script with an apply mode contains the bats real-HOME guard.
#   5. every host build, switch and eval in ops/ passes the local install
#      selection (T-0042): ops/lib/selection.sh is the one source of the
#      override arguments.
#   4. fish and zsh twins: see tests/bash/ws-shell-parity.bats (ws-* names and
#      the script each one runs) and tests/bash/cli-abbr.bats (shortcuts).
#
# Each seeded test copies the repository, re-introduces the duplicate and
# asserts the check fails.

load ../lib/contract

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# -- 1. home-manager switch --------------------------------------------------

# Lines that run (or build a command line for) `home-manager switch`, outside
# comments, messages and the single owner. Prints path:line:text.
hm_switch_users() {
    local root="$1" f
    while IFS= read -r -d '' f; do
        case "$f" in ops/lib/hm-switch.sh | ops/history-report.py | ops/projects/logging/test/*) continue ;; esac
        grep -nE 'home-manager switch' "$root/$f" |
            grep -vE '^[0-9]+:[[:space:]]*(#|//)' |
            grep -vE "(fail|warn|log|echo|printf|ui_[a-z]+|note|description|--description|run:|hint=)[ (=\"'].*home-manager switch" |
            sed "s|^|$f:|"
    done < <(cd "$root" && find ops scripts home nix mise.toml -type f \
        \( -name '*.sh' -o -name '*.tmpl' -o -name '*.fish' -o -name '*.nix' -o -name mise.toml -o -name 'executable_*' \) \
        -print0 2>/dev/null)
}

@test "home-manager switch is invoked only through ops/lib/hm-switch.sh" {
    # Anything printed here either needs hm_switch / hm_switch_raw or an
    # entry below with the reason it cannot use them.
    local line unexpected=""
    while IFS= read -r line; do
        case "$line" in
            # --- finding: direct calls that skip the profile-conflict check
            ops/bootstrap.sh:*) ;;   # builds SWITCH_CMD for the dry-run line and --dry-run call; the real switch uses hm_switch
            home/dot_config/fish/conf.d/cli.fish:*) ;;  # hms: interactive wrapper, passes extra args (--show-trace) through
            mise.toml:*"--dry-run"*) ;; # sync:dry-run only previews; sync:apply uses hm_switch
            *) unexpected+="$line"$'\n' ;;
        esac
    done < <(hm_switch_users "$REPO_ROOT")
    [ -z "$unexpected" ] || { printf 'home-manager switch outside ops/lib/hm-switch.sh:\n%s' "$unexpected"; return 1; }
}

@test "the real switches go through hm_switch (install, bootstrap, update-all, mise sync:apply, cbm updater)" {
    local f
    for f in ops/install.sh ops/bootstrap.sh ops/update-all.sh ops/update-codebase-memory-mcp.sh; do
        grep -qE 'hm_switch(_raw)?[ "]' "$REPO_ROOT/$f" || { echo "$f does not call hm_switch"; return 1; }
        grep -q 'ops/lib/hm-switch.sh' "$REPO_ROOT/$f" || { echo "$f does not source hm-switch.sh"; return 1; }
    done
    awk '/^\[tasks."sync:apply"\]/{r=1} r' "$REPO_ROOT/mise.toml" | grep -q 'hm_switch ./nix'
}

@test "seeded: a second home-manager switch in a script is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\nhome-manager switch --flake "$REPO_ROOT/nix#$HOST_PROFILE"\n' >>"$copy/ops/cleanup.sh"
    run hm_switch_users "$copy"
    [[ "$output" == *"ops/cleanup.sh:"*"home-manager switch"* ]]
}

# -- 5. local install selection (T-0042) -----------------------------------

# Lines that build, switch or evaluate a host configuration without
# SELECTION_ARGS (or selection_args_text in a message that prints the command).
# Same file set as rule 1. A message call and its first quoted string
# (fail/warn/log/echo/printf/ui_*/step_fail/note "...") is removed before the
# match, so `cmd || fail "..."` is still judged on `cmd`. Comment lines and
# quoted continuation lines are skipped. Not covered on purpose: validators and
# CI, which evaluate the committed default (validate-config.sh, ci.sh,
# ci-local.sh), and vicinae-extension.sh (a hint). Prints path:line:text.
selection_sites() {
    local root="$1" f n text stripped
    while IFS= read -r -d '' f; do
        case "$f" in
            ops/validate-config.sh | ops/ci.sh | ops/ci-local.sh | ops/vicinae-extension.sh | ops/projects/*) continue ;;
        esac
        while IFS= read -r line; do
            n="${line%%:*}"; text="${line#*:}"
            case "$text" in *SELECTION_ARGS* | *selection_args_text*) continue ;; esac
            printf '%s:%s:%s\n' "$f" "$n" "$text"
        done < <(
            grep -nvE '^[[:space:]]*(#|//|"|'"'"'|description|hint=|--description)' "$root/$f" |
                sed -E 's/(fail|warn|log|echo|printf|ui_[a-z]+|step_fail|note|--description|hint=)[ (]*("[^"]*"|'"'"'[^'"'"']*'"'"')//g' |
                grep -E 'home-manager( +[^ |;&]+)* +(switch|build)|darwin-rebuild +(switch|build|check)|#darwin-rebuild|nix (build|eval) .*#'
        )
    done < <(cd "$root" && find ops scripts home nix mise.toml -type f \
        \( -name '*.sh' -o -name '*.tmpl' -o -name '*.fish' -o -name '*.nix' -o -name mise.toml -o -name 'executable_*' \) \
        -print0 2>/dev/null)
}

@test "every host build, switch and eval passes the selection arguments (rule 1 file set, hms included)" {
    run selection_sites "$REPO_ROOT"
    [ -z "$output" ] || { printf 'host build/switch/eval without SELECTION_ARGS:\n%s\n' "$output"; return 1; }
}

@test "the scripts that use SELECTION_ARGS source ops/lib/selection.sh themselves" {
    local f
    for f in ops/install.sh ops/bootstrap.sh ops/update-all.sh ops/audit.sh ops/lib/hm-switch.sh; do
        grep -q 'SELECTION_ARGS' "$REPO_ROOT/$f" || { echo "$f does not pass SELECTION_ARGS"; return 1; }
        grep -q 'lib/selection.sh' "$REPO_ROOT/$f" || { echo "$f does not source selection.sh"; return 1; }
    done
    # nothing else builds the override arguments
    run grep -rln -e '--override-input' "$REPO_ROOT/ops" --include='*.sh'
    [ "$output" = "$REPO_ROOT/ops/lib/selection.sh" ]
}

@test "seeded: a host build, a switch and an eval without the selection arguments are caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    {
        printf '\nhome-manager switch -b hm-bak --flake "$REPO_ROOT/nix#$HOST_PROFILE"\n'
        printf 'nix build --no-link "$REPO_ROOT/nix#homeConfigurations.wsl.activationPackage"\n'
        printf 'out="$(nix eval --raw "path:$ROOT/nix#homeConfigurations.wsl.activationPackage.outPath")"\n'
        printf 'sudo darwin-rebuild switch --flake "$REPO_ROOT/nix#macos"\n'
    } >>"$copy/ops/cleanup.sh"
    run selection_sites "$copy"
    [[ "$output" == *"ops/cleanup.sh:"*"home-manager switch"* ]]
    [[ "$output" == *"ops/cleanup.sh:"*"nix build"* ]]
    [[ "$output" == *"ops/cleanup.sh:"*"nix eval"* ]]
    [[ "$output" == *"ops/cleanup.sh:"*"darwin-rebuild switch"* ]]
}

@test "seeded: the || fail form, home-manager -b x switch and a variable build target are caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    {
        printf '\nhome-manager switch --flake "$D/nix#h" || fail "home-manager switch failed"\n'
        printf 'home-manager -b x switch --flake "$D/nix#h"\n'
        printf 'nix build "$FLAKE#$TARGET"\n'
    } >>"$copy/ops/cleanup.sh"
    run selection_sites "$copy"
    [[ "$output" == *'ops/cleanup.sh:'*'home-manager switch --flake "$D/nix#h"'* ]]
    [[ "$output" == *'ops/cleanup.sh:'*'home-manager -b x switch'* ]]
    [[ "$output" == *'ops/cleanup.sh:'*'nix build "$FLAKE#$TARGET"'* ]]
    # a bare message is not a call site
    : >"$copy/ops/cleanup.sh"
    printf 'fail "home-manager switch failed"\n' >>"$copy/ops/cleanup.sh"
    run selection_sites "$copy"
    [[ "$output" != *"ops/cleanup.sh:"* ]]
}

@test "mise sync:apply and sync:dry-run pass the selection arguments to darwin-rebuild" {
    local task
    for task in sync:apply sync:dry-run; do
        awk -v t="[tasks.\"$task\"]" '/^\[tasks/{r=($0==t)} r' "$REPO_ROOT/mise.toml" |
            grep -E 'darwin-rebuild (switch|check)' | grep -q 'SELECTION_ARGS' || { echo "$task: darwin-rebuild without SELECTION_ARGS"; return 1; }
        awk -v t="[tasks.\"$task\"]" '/^\[tasks/{r=($0==t)} r' "$REPO_ROOT/mise.toml" |
            grep -q 'ops/lib/selection.sh' || { echo "$task does not source selection.sh"; return 1; }
    done
    awk '/^\[tasks."sync:dry-run"\]/{r=1;next} /^\[tasks/{r=0} r' "$REPO_ROOT/mise.toml" |
        grep -E 'home-manager switch .*--dry-run' | grep -q 'SELECTION_ARGS'
}

@test "mise sync:apply and sync:dry-run declare a bash shell (selection.sh is not POSIX sh)" {
    local task
    for task in sync:apply sync:dry-run; do
        awk -v t="[tasks.\"$task\"]" '/^\[tasks/{r=($0==t)} r' "$REPO_ROOT/mise.toml" |
            grep -Eq '^shell = "bash -c' || { echo "$task: no bash shell declared"; return 1; }
    done
}

@test "seeded: dropping the arguments from a real call site is caught, adding them is accepted" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    sed -i 's| ${SELECTION_ARGS\[@\]+"${SELECTION_ARGS\[@\]}"}||' "$copy/ops/update-all.sh"
    run selection_sites "$copy"
    [[ "$output" == *"ops/update-all.sh:"*"nix build"* ]]
    [[ "$output" == *"ops/update-all.sh:"*"darwin-rebuild switch"* ]]
    printf '\nnix build --no-link "$REPO_ROOT/nix#homeConfigurations.wsl.activationPackage" ${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"}\n' >>"$copy/ops/cleanup.sh"
    run selection_sites "$copy"
    [[ "$output" != *"ops/cleanup.sh:"* ]]
}

# -- 2. preflight guards -----------------------------------------------------

# The inline forms of the three guards. Prints file:line for each hit.
inline_guards() {
    local root="$1" f
    for f in "$@"; do :; done
    shift
    for f in "$@"; do
        grep -nE -e '--wsl-version|username = "|BATS_TEST_TMPDIR' "$root/$f" |
            grep -vE '^[0-9]+:[[:space:]]*#' | sed "s|^|$f:|"
    done
}

@test "preflight.sh owns the WSL1 refusal, the username check and the bats guard" {
    grep -q -e '--wsl-version' "$REPO_ROOT/ops/lib/preflight.sh"
    grep -q 'username = ' "$REPO_ROOT/ops/lib/preflight.sh"
    grep -q 'BATS_TEST_TMPDIR' "$REPO_ROOT/ops/lib/preflight.sh"
}

@test "install.sh and bootstrap.sh call preflight and carry no inline copy of its guards" {
    local f
    for f in ops/install.sh ops/bootstrap.sh; do
        grep -q 'preflight_host_checks' "$REPO_ROOT/$f" || { echo "$f: no preflight_host_checks"; return 1; }
        grep -q 'preflight_bats_guard' "$REPO_ROOT/$f" || { echo "$f: no preflight_bats_guard"; return 1; }
    done
    run inline_guards "$REPO_ROOT" ops/install.sh ops/bootstrap.sh
    [ -z "$output" ] || { echo "inline guard copies:"; echo "$output"; return 1; }
}

@test "known twin: update-all.sh still carries its own WSL1 refusal (finding; its bats guard is the shared one)" {
    # update-all.sh uses preflight_bats_guard but keeps an inline WSL1 check
    # for an explicit HOST_PROFILE=wsl. When it moves to preflight_host_checks,
    # this test fails: delete it and add update-all.sh to the list above.
    grep -q 'preflight_bats_guard' "$REPO_ROOT/ops/update-all.sh"
    run inline_guards "$REPO_ROOT" ops/update-all.sh
    [[ "$output" == *"--wsl-version"* ]]
    [[ "$output" != *"BATS_TEST_TMPDIR"* ]]
}

@test "seeded: an inline WSL1 refusal or username check in install.sh is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\n[[ "$(bash ops/detect-host.sh --wsl-version)" == 1 ]] && exit 1\n' >>"$copy/ops/install.sh"
    printf '\nnix_user="$(sed -nE '"'"'s/^ *username = "(.*)";/\\1/p'"'"' nix/vars/default.nix)"\n' >>"$copy/ops/bootstrap.sh"
    run inline_guards "$copy" ops/install.sh ops/bootstrap.sh
    [[ "$output" == *"ops/install.sh:"*"--wsl-version"* ]]
    [[ "$output" == *"ops/bootstrap.sh:"*"username"* ]]
}

# -- 3. bats real-HOME guard on every apply mode ------------------------------

# Scripts with an apply mode that must refuse a real run from a bats test.
APPLY_SCRIPTS=(
    ops/install.sh ops/bootstrap.sh ops/update-all.sh ops/cleanup.sh
    ops/uninstall.sh ops/system-setup.sh ops/update-codebase-memory-mcp.sh
    ops/tailscale-setup.sh
)

unguarded_apply_scripts() {
    local root="$1" f; shift
    for f in "$@"; do
        grep -qE 'preflight_bats_guard|BATS_TEST_TMPDIR' "$root/$f" || printf '%s\n' "$f"
    done
}

@test "every script with an apply mode contains the bats real-HOME guard" {
    run unguarded_apply_scripts "$REPO_ROOT" "${APPLY_SCRIPTS[@]}"
    [ -z "$output" ] || { echo "no bats guard:"; echo "$output"; return 1; }
}

@test "no apply-mode script is missing from the list above" {
    # A new ops script with an --apply case label must be added to
    # APPLY_SCRIPTS (or to the finding below).
    local f unlisted=""
    while IFS= read -r f; do
        printf '%s\n' "${APPLY_SCRIPTS[@]}" | grep -qxF "$f" && continue
        case "$f" in
            # --- finding: writes under HOME / SYNC_OBSIDIAN_DIR with no bats guard. Its tests
            # run it from the real repo with a scratch HOME, so the shared guard would refuse them.
            ops/syncthing-obsidian-stignore.sh) continue ;;
        esac
        unlisted+="$f "
    done < <(cd "$REPO_ROOT" && grep -lE -e '^[[:space:]]*(-[a-z]\|)?--apply[|)]' ops/*.sh)
    [ -z "$unlisted" ] || { echo "apply mode without a guard check: $unlisted"; return 1; }
}

@test "seeded: an apply-mode script without the guard is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    sed -i '/preflight_bats_guard/d' "$copy/ops/cleanup.sh"
    run unguarded_apply_scripts "$copy" "${APPLY_SCRIPTS[@]}"
    [ "$output" = "ops/cleanup.sh" ]
}

# -- 4. fish/zsh twins ---------------------------------------------------------

@test "the shell-twin parity tests exist and still cover names and targets" {
    grep -q 'fish defines every ws command zsh defines' "$REPO_ROOT/tests/bash/ws-shell-parity.bats"
    grep -q 'each ws command runs the same script in fish and zsh' "$REPO_ROOT/tests/bash/ws-shell-parity.bats"
    grep -q 'zsh offers the same shortcuts as fish' "$REPO_ROOT/tests/bash/cli-abbr.bats"
}

# -- 6. remembered linux host (T-0044) ----------------------------------------

# Files outside ops/detect-host.sh that spell the host file's path
# (`app-configs/host`, not `app-configs/host-snapshots`). Same file set as rule 1.
host_file_path_users() {
    local root="$1" f
    while IFS= read -r -d '' f; do
        [ "$f" = ops/detect-host.sh ] && continue
        grep -qE 'app-configs/host($|[^-[:alnum:]_])' "$root/$f" && printf '%s\n' "$f"
    done < <(cd "$root" && find ops scripts home nix mise.toml -type f \
        \( -name '*.sh' -o -name '*.tmpl' -o -name '*.fish' -o -name '*.nix' -o -name '*.bats' -o -name mise.toml -o -name 'executable_*' \) \
        -print0 2>/dev/null)
    return 0
}

@test "only ops/detect-host.sh spells the host file path" {
    run host_file_path_users "$REPO_ROOT"
    [ -z "$output" ] || { printf 'host file path outside ops/detect-host.sh:\n%s\n' "$output"; return 1; }
    grep -qE 'app-configs/host($|[^-[:alnum:]_])' "$REPO_ROOT/ops/detect-host.sh"
}

@test "seeded: a second spelling of the host file path is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\nf="$HOME/.config/app-configs/host"\n' >>"$copy/ops/cleanup.sh"
    run host_file_path_users "$copy"
    [ "$output" = ops/cleanup.sh ]
}
