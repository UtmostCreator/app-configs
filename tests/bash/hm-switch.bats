#!/usr/bin/env bats
# ops/lib/hm-switch.sh: the one shared Home Manager switch. Every caller
# (update-all, install, bootstrap, the codebase-memory-mcp updater) goes
# through it, so the conflict check and -b hm-bak cannot be skipped by one.

# `! cmd` in the middle of a bats test does not fail it (set -e ignores a
# negated command), so assert absence explicitly.
refute_grep() { if grep -q "$@"; then echo "unexpected match: $*" >&2; return 1; fi; }

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    # An exact-command-line suite: never pick up a real selection file or an
    # exported XDG_CONFIG_HOME (tests that want a selection set their own).
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/no-selection"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$HOME/.nix-profile" "$STUBS" "$BATS_TEST_TMPDIR/out/home-path/bin"
    : >"$CALLS"
    printf '#!/usr/bin/env bash\nprintf "nix %%s\\n" "$*" >> "$CALLS"\nprintf "%%s\\n" "$BATS_TEST_TMPDIR/out"\n' >"$STUBS/nix"
    printf '#!/usr/bin/env bash\nprintf "home-manager %%s\\n" "$*" >> "$CALLS"\nexit "${FAIL_SWITCH:-0}"\n' >"$STUBS/home-manager"
    chmod +x "$STUBS/nix" "$STUBS/home-manager"
    PATH="$STUBS:$PATH"
    printf '{"elements":{}}\n' >"$HOME/.nix-profile/manifest.json"
    # shellcheck source=/dev/null
    source "$REPO_ROOT/ops/lib/hm-switch.sh"
}

add_conflict() {
    mkdir -p "$BATS_TEST_TMPDIR/parallel/bin"
    touch "$BATS_TEST_TMPDIR/parallel/bin/parallel" "$BATS_TEST_TMPDIR/out/home-path/bin/parallel"
    printf '{"elements":{"parallel":{"originalUrl":"flake:nixpkgs","storePaths":["%s"]}}}\n' \
        "$BATS_TEST_TMPDIR/parallel" >"$HOME/.nix-profile/manifest.json"
}

@test "a clean profile switches with -b hm-bak after the check" {
    run hm_switch /repo/nix linux-desktop
    [ "$status" -eq 0 ]
    grep -qx 'home-manager switch -b hm-bak --flake /repo/nix#linux-desktop' "$CALLS"
}

@test "a colliding nix-profile entry stops before the switch, naming the fix" {
    add_conflict
    run hm_switch /repo/nix linux-desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *"nix profile remove parallel"* ]]
    refute_grep '^home-manager' "$CALLS"
}

@test "with neither jq nor nix the check is an error, not an empty conflict list" {
    local empty="$BATS_TEST_TMPDIR/empty"; mkdir -p "$empty"
    run env PATH="$empty" "$BASH" -c "source '$REPO_ROOT/ops/lib/hm-switch.sh'; hm_check_conflicts /repo/nix p; echo status=\$?; echo \"\$HM_CHECK_MSG\""
    [[ "$output" == *"status=2"* ]]
    [[ "$output" == *"neither jq nor nix"* ]]
}

@test "without jq the check borrows it from nixpkgs (a fresh bootstrap has no jq)" {
    printf '#!/usr/bin/env bash\nprintf "nix %%s\\n" "$*" >> "$CALLS"\n[ "$1" = run ] && exit 0\nprintf "%%s\\n" "$BATS_TEST_TMPDIR/out"\n' >"$STUBS/nix"
    local t
    for t in bash tail cut sort paste dirname cat sed grep find; do ln -sf "$(command -v "$t")" "$STUBS/$t"; done
    run env PATH="$STUBS" "$BASH" -c "source '$REPO_ROOT/ops/lib/hm-switch.sh'; hm_check_conflicts /repo/nix p; echo status=\$?"
    [[ "$output" == *"status=0"* ]]
    grep -q '^nix run nixpkgs#jq -- ' "$CALLS"
}

@test "a profile without a manifest is an error" {
    rm "$HOME/.nix-profile/manifest.json"
    run hm_switch /repo/nix linux-desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest.json is missing"* ]]
    refute_grep '^home-manager' "$CALLS"
}

@test "a host with no nix profile at all has nothing to collide with" {
    rm -r "$HOME/.nix-profile"
    run hm_switch /repo/nix linux-desktop
    [ "$status" -eq 0 ]
    grep -q '^home-manager switch' "$CALLS"
}

@test "an activation package that cannot be built is an error" {
    printf '#!/usr/bin/env bash\nexit 1\n' >"$STUBS/nix"
    run hm_switch /repo/nix linux-desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not build"* ]]
    refute_grep '^home-manager' "$CALLS"
}

@test "a failed switch explains the existing .hm-bak abort" {
    FAIL_SWITCH=1 run hm_switch_raw /repo/nix linux-desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *".hm-bak file already exists"* ]]
}

@test "hm_switch_describe prints the exact switch command line" {
    [ "$(hm_switch_describe /repo/nix wsl)" = "home-manager switch -b hm-bak --flake /repo/nix#wsl" ]
}

@test "no script, mise task or switch doc runs a bare 'home-manager switch --flake'" {
    cd "$REPO_ROOT"
    # Lines that apply a switch must carry -b hm-bak; --dry-run previews and
    # prose that merely names the command are exempt.
    run grep -nE 'home-manager switch.*--flake' \
        ops/*.sh ops/lib/*.sh mise.toml docs/platforms/nixos/*.md docs/reference/profiles.md \
        nix/modules/home/scripts/*.sh
    bad="$(printf '%s\n' "$output" | grep -v -e 'hm-bak' -e '--dry-run' -e 'hm-switch.sh' || true)"
    [ -z "$bad" ] || { echo "$bad" >&2; return 1; }
}

# -- local install selection (T-0042): ops/lib/selection.sh is the one source --

mk_selection() {
    SEL="$BATS_TEST_TMPDIR/sel"; mkdir -p "$SEL"
    printf 'profile = "work"\n' >"$SEL/selection.toml"
    export APP_CONFIGS_SELECTION_DIR="$SEL"
}

@test "selection: no local file passes nothing; a local file passes the absolute override" {
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/none"
    selection_args
    [ "${#SELECTION_ARGS[@]}" -eq 0 ]
    mk_selection
    cd "$BATS_TEST_TMPDIR"
    export APP_CONFIGS_SELECTION_DIR="sel"
    selection_args
    [ "${SELECTION_ARGS[*]}" = "--override-input selection path:$(cd "$SEL" && pwd -P)" ]
}

@test "selection: the default directory is under XDG_CONFIG_HOME, else HOME/.config" {
    unset APP_CONFIGS_SELECTION_DIR
    XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" run selection_dir
    [ "$output" = "$BATS_TEST_TMPDIR/xdg/app-configs/selection" ]
    unset XDG_CONFIG_HOME
    run selection_dir
    [ "$output" = "$HOME/.config/app-configs/selection" ]
}

@test "selection: with a local file the pre-check build and the switch both carry the override" {
    mk_selection
    run hm_switch /repo/nix linux-desktop
    [ "$status" -eq 0 ]
    grep -q "^nix build --no-link --print-out-paths /repo/nix#homeConfigurations.linux-desktop.activationPackage --override-input selection path:$SEL\$" "$CALLS"
    grep -qx "home-manager switch -b hm-bak --flake /repo/nix#linux-desktop --override-input selection path:$SEL" "$CALLS"
}

@test "selection: without a local file the command lines are unchanged" {
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/none"
    run hm_switch /repo/nix linux-desktop
    [ "$status" -eq 0 ]
    grep -qx 'nix build --no-link --print-out-paths /repo/nix#homeConfigurations.linux-desktop.activationPackage' "$CALLS"
    grep -qx 'home-manager switch -b hm-bak --flake /repo/nix#linux-desktop' "$CALLS"
    [ "$(hm_switch_describe /repo/nix linux-desktop)" = 'home-manager switch -b hm-bak --flake /repo/nix#linux-desktop' ]
}

@test "selection: the description shows the override" {
    mk_selection
    run hm_switch_describe /repo/nix wsl
    [ "$output" = "home-manager switch -b hm-bak --flake /repo/nix#wsl --override-input selection path:$SEL" ]
}

@test "selection: a selection that fails the pre-check build stops before the switch" {
    mk_selection
    printf '#!/usr/bin/env bash\nprintf "nix %%s\\n" "$*" >> "$CALLS"\ncase "$*" in *--override-input*) exit 1 ;; esac\nprintf "%%s\\n" "$BATS_TEST_TMPDIR/out"\n' >"$STUBS/nix"
    run hm_switch /repo/nix linux-desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *"--override-input selection path:$SEL"* ]]
    refute_grep '^home-manager' "$CALLS"
}

@test "selection: empty SELECTION_ARGS is safe under set -u on this and older bash" {
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/none"
    run "$BASH" -u -c "source '$REPO_ROOT/ops/lib/hm-switch.sh'; hm_switch_describe /repo/nix p"
    [ "$status" -eq 0 ]
    [ "$output" = 'home-manager switch -b hm-bak --flake /repo/nix#p' ]
}

@test "selection: no prompt can run in hm-switch.sh, selection.sh, selection-facts.sh, selection-diff.sh, install-record.sh or selection-preview.sh" {
    run grep -nE '(^|[^[:alnum:]_])read[[:space:]]' "$REPO_ROOT/ops/lib/hm-switch.sh" "$REPO_ROOT/ops/lib/selection.sh" "$REPO_ROOT/ops/lib/selection-facts.sh" "$REPO_ROOT/ops/lib/selection-diff.sh" "$REPO_ROOT/ops/lib/install-record.sh" "$REPO_ROOT/ops/lib/selection-preview.sh"
    [ "$status" -ne 0 ]
}

@test "selection: a directory with a space, ?, # or % is percent-encoded in the URL and the printed form" {
    SEL="$BATS_TEST_TMPDIR/we ird?d#r%20x"; mkdir -p "$SEL"
    printf 'profile = "work"\n' >"$SEL/selection.toml"
    export APP_CONFIGS_SELECTION_DIR="$SEL"
    selection_args
    abs="$(cd "$SEL" && pwd -P)"
    [ "${SELECTION_ARGS[1]}" = selection ]
    enc="${abs//%/%25}"; enc="${enc// /%20}"; enc="${enc//\?/%3F}"; enc="${enc//#/%23}"
    [ "${SELECTION_ARGS[2]}" = "path:$enc" ]
    [[ "${SELECTION_ARGS[2]}" != *" "* && "${SELECTION_ARGS[2]}" != *"?"* && "${SELECTION_ARGS[2]}" != *"#"* ]]
    # %20 in the name stays %2520, so it cannot select a directory with a space
    [[ "${SELECTION_ARGS[2]}" == *"%2520x" ]]
    # the printed form has no raw space either, so it can be pasted into a shell
    [[ "$(selection_args_text)" != *"we ird"* ]]
}
