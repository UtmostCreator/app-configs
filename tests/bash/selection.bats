#!/usr/bin/env bats
# Install selection (T-0042): the committed selection input, the profile
# files and the myConfig.groups option, checked from the evaluated flake. A
# fixture directory stands in for the local selection and is passed the way the
# scripts will pass it: --override-input selection path:<dir>. Nothing is built
# or activated.

bats_require_minimum_version 1.5.0

setup_file() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export REPO_ROOT
    command -v nix >/dev/null || return 0
    # One drvPath per (selection, host) pair, evaluated once per file; the
    # tests compare the recorded values.
    local h
    for h in linux-cli linux-desktop; do
        drv "$h" default >"$BATS_FILE_TMPDIR/drv-default-$h" 2>"$BATS_FILE_TMPDIR/err-drv-default-$h" || true
    done
    drv linux-cli empty >"$BATS_FILE_TMPDIR/drv-empty-linux-cli" 2>"$BATS_FILE_TMPDIR/err-drv-empty-linux-cli" || true
    drv linux-cli all-on-work >"$BATS_FILE_TMPDIR/drv-all-on-work-linux-cli" 2>"$BATS_FILE_TMPDIR/err-drv-all-on-work-linux-cli" || true
    drv linux-desktop all-on-personal >"$BATS_FILE_TMPDIR/drv-all-on-personal-linux-desktop" 2>"$BATS_FILE_TMPDIR/err-drv-all-on-personal-linux-desktop" || true
    # macOS: the same identities for the standalone Home Manager output and for the
    # nix-darwin system (aarch64-darwin evaluates from Linux; nothing is built).
    local k
    for k in default empty all-on-work; do
        drv macos "$k" >"$BATS_FILE_TMPDIR/drv-$k-macos" 2>"$BATS_FILE_TMPDIR/err-drv-$k-macos" || true
        drvd "$k" >"$BATS_FILE_TMPDIR/drv-$k-darwin" 2>"$BATS_FILE_TMPDIR/err-drv-$k-darwin" || true
    done
    # linux-desktop: empty vs default, the host with the personal profile.
    drv linux-desktop empty >"$BATS_FILE_TMPDIR/drv-empty-linux-desktop" 2>"$BATS_FILE_TMPDIR/err-drv-empty-linux-desktop" || true
    local f
    for f in default media-go-off all-false; do
        pkgs linux-cli "$f" >"$BATS_FILE_TMPDIR/pkgs-$f.json" 2>"$BATS_FILE_TMPDIR/err-pkgs-$f" || true
    done
}

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIX="$BATS_TEST_DIRNAME/fixtures/selection"
    command -v nix >/dev/null || skip "nix not installed"
}

# sel <fixture>: the override arguments for one fixture ("default" = none).
sel() {
    if [ "$1" = default ]; then return 0; fi
    printf '%s\n' --override-input selection "path:$BATS_TEST_DIRNAME/fixtures/selection/$1"
}

# drv <host> <fixture>: activation drvPath.
drv() {
    local args=()
    mapfile -t args < <(sel "$2")
    timeout 600 nix eval --raw "path:$REPO_ROOT/nix#homeConfigurations.$1.activationPackage.drvPath" "${args[@]}"
}

# drvd <fixture>: drvPath of darwinConfigurations.macos.system.
drvd() {
    local args=()
    mapfile -t args < <(sel "$1")
    timeout 600 nix eval --raw "path:$REPO_ROOT/nix#darwinConfigurations.macos.system.drvPath" "${args[@]}"
}

# casks <fixture>: the names in darwinConfigurations.macos homebrew.casks, as JSON.
casks() {
    local args=()
    mapfile -t args < <(sel "$1")
    timeout 600 nix eval --json "path:$REPO_ROOT/nix#darwinConfigurations.macos.config.homebrew.casks" \
        "${args[@]}" --apply 'cs: map (c: c.name) cs'
}

# hmjson <host> <fixture> <attr under config>: evaluate to JSON.
hmjson() {
    local args=()
    mapfile -t args < <(sel "$2")
    timeout 600 nix eval --json "path:$REPO_ROOT/nix#homeConfigurations.$1.config.$3" "${args[@]}"
}

# pkgs <host> <fixture>: sorted package names of home.packages, as JSON.
pkgs() {
    local args=()
    mapfile -t args < <(sel "$2")
    timeout 600 nix eval --json "path:$REPO_ROOT/nix#homeConfigurations.$1.config.home.packages" \
        "${args[@]}" --apply 'ps: map (x: x.pname or x.name or "") ps' | jq -c 'sort'
}

# recorded <name>: a value recorded by setup_file; on an empty value, print the
# stderr of the eval that produced it so the failure is diagnosable.
recorded() {
    local v
    v="$(cat "$BATS_FILE_TMPDIR/drv-$1" 2>/dev/null)"
    if [ -z "$v" ]; then cat "$BATS_FILE_TMPDIR/err-drv-$1" >&2 2>/dev/null || true; fi
    printf '%s' "$v"
}

@test "the committed selection file exists and is empty (no selection)" {
    [ -f "$REPO_ROOT/nix/selection/selection.toml" ]
    [ ! -s "$REPO_ROOT/nix/selection/selection.toml" ]
}

@test "each profile file is named for a profile and lists exactly the declared groups" {
    run --separate-stderr nix eval --json --impure --expr '
      let
        dir = builtins.getEnv "REPO_ROOT" + "/nix/profiles";
        read = n: (builtins.fromTOML (builtins.readFile (dir + "/${n}.toml"))).groups;
      in { work = builtins.attrNames (read "work"); personal = builtins.attrNames (read "personal"); }'
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '.work == ["go","macInput","media","security"] and .personal == ["go","macInput","media","security"]' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "default: every group is on" {
    run --separate-stderr hmjson linux-cli default myConfig.groups
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '. == {go: true, macInput: true, media: true, security: true}' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "empty selection file via override: identical drvPath to no override" {
    [ -n "$(recorded default-linux-cli)" ]
    [ "$(recorded empty-linux-cli)" = "$(recorded default-linux-cli)" ]
}

@test "all-on fixture (work): same drvPath as the default on linux-cli" {
    [ -n "$(recorded default-linux-cli)" ]
    [ "$(recorded all-on-work-linux-cli)" = "$(recorded default-linux-cli)" ]
}

@test "all-on fixture (personal): same drvPath as the default on linux-desktop" {
    [ -n "$(recorded default-linux-desktop)" ]
    [ "$(recorded all-on-personal-linux-desktop)" = "$(recorded default-linux-desktop)" ]
}

@test "a selection profile overrides the host profile" {
    run --separate-stderr hmjson linux-desktop profile-only-personal myConfig.profile
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = '"personal"' ]
    run --separate-stderr hmjson linux-desktop all-on-work myConfig.profile
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = '"work"' ]
}

@test "group deltas override the profile defaults" {
    run --separate-stderr hmjson linux-cli media-go-off myConfig.groups
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '. == {go: false, macInput: true, media: false, security: true}' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "an unknown group fails evaluation and names the key" {
    run hmjson linux-cli unknown-group myConfig.groups
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown group 'bogus'"* ]]
}

@test "an unknown profile fails evaluation and names the key" {
    run hmjson linux-cli unknown-profile myConfig.groups
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown profile 'nope'"* ]]
}

@test "an unknown top-level key fails evaluation and names the key" {
    run hmjson linux-cli bare-group-key myConfig.groups
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown key 'media'"* ]]
    run hmjson linux-cli typo-profile-key myConfig.groups
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown key 'profle'"* ]]
}

@test "groups without a profile fail evaluation and name the key" {
    run hmjson linux-cli groups-without-profile myConfig.groups
    [ "$status" -ne 0 ]
    [[ "$output" == *"'profile' is missing"* ]]
}

# Package names (pname) each group gates. Keep in step with the lib.optionals
# blocks in nix/modules/home/cli.nix and dev.nix.
MEDIA='["ffmpeg","imagemagick","viu","yt-dlp"]'
SECURITY='["osv-scanner","trivy"]'
GO='["delve","go","go-arch-lint","gofumpt","golangci-lint","gopls","goreleaser","gotestsum","gotools","govulncheck","gremlins","mockgen"]'

pk() { cat "$BATS_FILE_TMPDIR/pkgs-$1.json"; }

@test "default packages include every gated package" {
    [ -s "$BATS_FILE_TMPDIR/pkgs-default.json" ] || { cat "$BATS_FILE_TMPDIR/err-pkgs-default" >&2; return 1; }
    run jq -e --argjson g "$MEDIA" --argjson s "$SECURITY" --argjson o "$GO" \
        '($g + $s + $o) - . == []' "$BATS_FILE_TMPDIR/pkgs-default.json"
    [ "$status" -eq 0 ]
}

@test "media=false and go=false: ffmpeg and go are gone, core tools stay" {
    [ -s "$BATS_FILE_TMPDIR/pkgs-media-go-off.json" ]
    run jq -e '((["ffmpeg","go"] - . == ["ffmpeg","go"])
         and (["fish","ripgrep","fd","jq","git"] - . == [])
         and (["trivy","osv-scanner"] - . == []))' "$BATS_FILE_TMPDIR/pkgs-media-go-off.json"
    [ "$status" -eq 0 ]
}

@test "media=false and go=false remove exactly the media and go packages" {
    run jq -e --slurpfile off "$BATS_FILE_TMPDIR/pkgs-media-go-off.json" \
        --argjson g "$MEDIA" --argjson o "$GO" \
        '(. - $off[0] | sort) == (($g + $o) | sort)' "$BATS_FILE_TMPDIR/pkgs-default.json"
    [ "$status" -eq 0 ]
}

@test "all groups off remove exactly the gated packages and keep the tools the ops scripts need" {
    [ -s "$BATS_FILE_TMPDIR/pkgs-all-false.json" ]
    run jq -e --slurpfile off "$BATS_FILE_TMPDIR/pkgs-all-false.json" \
        --argjson g "$MEDIA" --argjson s "$SECURITY" --argjson o "$GO" \
        '(. - $off[0] | sort) == (($g + $s + $o) | sort)' "$BATS_FILE_TMPDIR/pkgs-default.json"
    [ "$status" -eq 0 ]
    # Home Manager side of what update-all, readiness and doctor check:
    # home-manager, git, jq, yq, gitleaks, and the readiness/doctor samples.
    run jq -e '["home-manager","git","jq","yq-go","gitleaks","fish","neovim","ripgrep","fd","bat","eza","fzf","zoxide","starship","atuin","tmux","lazygit","delta","gh","nodejs","php-with-extensions","docker","stripe-cli","repomix","scc","bats","actionlint","ShellCheck","shfmt","lychee","curl"] - . == []' \
        "$BATS_FILE_TMPDIR/pkgs-all-false.json"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "an evaluation with a local selection leaves nix/flake.lock byte-identical" {
    local before after
    before="$(sha256sum "$REPO_ROOT/nix/flake.lock")"
    run hmjson linux-cli media-go-off myConfig.groups
    [ "$status" -eq 0 ]
    run hmjson linux-cli all-on-work myConfig.profile
    [ "$status" -eq 0 ]
    after="$(sha256sum "$REPO_ROOT/nix/flake.lock")"
    [ "$before" = "$after" ]
}

@test "a selection directory with a space, ? and # in its path works with a real --override-input" {
    local dir="$BATS_TEST_TMPDIR/my sel?x#y%z"
    mkdir -p "$dir"
    cp "$BATS_TEST_DIRNAME/fixtures/selection/media-go-off/selection.toml" "$dir/"
    source "$REPO_ROOT/ops/lib/selection.sh"
    APP_CONFIGS_SELECTION_DIR="$dir" selection_args
    [ "${#SELECTION_ARGS[@]}" -eq 3 ]
    run --separate-stderr timeout 600 nix eval --json \
        "path:$REPO_ROOT/nix#homeConfigurations.linux-cli.config.myConfig.groups" "${SELECTION_ARGS[@]}"
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '. == {go: false, macInput: true, media: false, security: true}' <<<"$output"
    [ "$status" -eq 0 ]
}

# ── selection_validate and the preview's expressions, against the real flake ──
# (review round 1: the stubbed install tests cannot see what real Nix prints or
# whether the Nix expression strings still evaluate.)

# validate_fixture <fixture> [host]: selection_validate on a copy of the fixture.
validate_fixture() {
    local dir="$BATS_TEST_TMPDIR/sel-$1"
    mkdir -p "$dir" "$BATS_TEST_TMPDIR/work"
    cp "$BATS_TEST_DIRNAME/fixtures/selection/$1/selection.toml" "$dir/"
    export APP_CONFIGS_SELECTION_DIR="$dir"
    # shellcheck source=ops/lib/selection.sh
    source "$REPO_ROOT/ops/lib/selection.sh"
    SELECTION_REPO_ROOT="$REPO_ROOT" SELECTION_HOST="${2:-linux-cli}" SELECTION_WORK="$BATS_TEST_TMPDIR/work"
    run --separate-stderr selection_validate
}

@test "selection_validate rejects each invalid fixture and shows the line that names the key" {
    local case_ fixture expect
    for case_ in "unknown-group|unknown group 'bogus'" "unknown-profile|unknown profile" \
        "groups-without-profile|'profile' is missing" "typo-profile-key|unknown key 'profle'" \
        "bare-group-key|unknown key 'media'"; do
        fixture="${case_%%|*}"
        expect="${case_#*|}"
        validate_fixture "$fixture"
        [ "$status" -eq 1 ] || { echo "$fixture: status $status"; return 1; }
        [[ "$stderr" == *"$expect"* ]] || { echo "$fixture: missing '$expect' in:"; echo "$stderr"; return 1; }
    done
}

@test "selection_validate rejects a group of the wrong type and names the option" {
    validate_fixture wrong-type-group
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"myConfig.groups.media"* ]]
}

@test "selection_validate accepts the valid fixtures" {
    local f
    for f in media-go-off all-false profile-only-personal; do
        validate_fixture "$f"
        [ "$status" -eq 0 ] || { echo "$f: $stderr"; return 1; }
    done
}

@test "the preview's state, members and check expressions evaluate against the real flake (linux-cli and macos)" {
    source "$REPO_ROOT/ops/lib/selection.sh"
    mkdir -p "$BATS_TEST_TMPDIR/w"
    SELECTION_REPO_ROOT="$REPO_ROOT"
    local host
    for host in linux-cli macos; do
        SELECTION_HOST="$host"
        groups=3
        if [ "$host" = macos ]; then groups=4; fi
        SELECTION_ARGS=()
        _sel_eval "$BATS_TEST_TMPDIR/w/state-$host" "$BATS_TEST_TMPDIR/w/err" "$(_sel_attr_state)" "$(_sel_expr_state)" || { cat "$BATS_TEST_TMPDIR/w/err"; return 1; }
        _sel_eval "$BATS_TEST_TMPDIR/w/members-$host" "$BATS_TEST_TMPDIR/w/err" "$(_sel_attr_members)" "$(_sel_expr_members)" || { cat "$BATS_TEST_TMPDIR/w/err"; return 1; }
        _sel_eval "$BATS_TEST_TMPDIR/w/check-$host" "$BATS_TEST_TMPDIR/w/err" "$(_sel_attr_check)" "$(_sel_expr_check)" || { cat "$BATS_TEST_TMPDIR/w/err"; return 1; }
        grep -q "^P"$'\t' "$BATS_TEST_TMPDIR/w/state-$host"
        # macInput exists on every host but only macOS offers it (it gates casks).
        [ "$(grep -c "^G"$'\t' "$BATS_TEST_TMPDIR/w/state-$host")" -eq "$groups" ]
        [ "$(grep -c "^K"$'\t' "$BATS_TEST_TMPDIR/w/state-$host")" -gt 50 ]
        grep -q "^H"$'\t' "$BATS_TEST_TMPDIR/w/members-$host"
        [ "$(grep -c "^N"$'\t' "$BATS_TEST_TMPDIR/w/members-$host")" -eq "$groups" ]
        if [ "$host" = macos ]; then
            grep -q "^N"$'\t'"macInput" "$BATS_TEST_TMPDIR/w/members-$host"
        else
            run grep -q macInput "$BATS_TEST_TMPDIR/w/members-$host" "$BATS_TEST_TMPDIR/w/state-$host"
            [ "$status" -eq 1 ]
        fi
        grep -q "^G"$'\t'"media"$'\t' "$BATS_TEST_TMPDIR/w/members-$host"
    done
    grep -q "^C"$'\t' "$BATS_TEST_TMPDIR/w/state-macos"
    # S1: the casks a group gates, from the darwin system.
    [ "$(grep -c "^X"$'\t' "$BATS_TEST_TMPDIR/w/members-macos")" -eq 2 ]
    grep -q "^X"$'\t'"macInput"$'\t'"karabiner-elements$" "$BATS_TEST_TMPDIR/w/members-macos"
    grep -q "^X"$'\t'"macInput"$'\t'"linearmouse$" "$BATS_TEST_TMPDIR/w/members-macos"
    run grep -c "^X" "$BATS_TEST_TMPDIR/w/members-linux-cli"
    [ "$output" = 0 ]
}

# ── Phase 2: macInput and the darwin outputs (AC11) ──

@test "AC11: the macos Home Manager output is the same for no selection, an empty file and all groups on" {
    [ -n "$(recorded default-macos)" ]
    [ "$(recorded empty-macos)" = "$(recorded default-macos)" ]
    [ "$(recorded all-on-work-macos)" = "$(recorded default-macos)" ]
}

@test "AC11: darwinConfigurations.macos.system is the same for no selection, an empty file and all groups on" {
    [ -n "$(recorded default-darwin)" ]
    [ "$(recorded empty-darwin)" = "$(recorded default-darwin)" ]
    [ "$(recorded all-on-work-darwin)" = "$(recorded default-darwin)" ]
}

@test "linux-desktop with an empty selection file is the same as no selection" {
    [ -n "$(recorded default-linux-desktop)" ]
    [ "$(recorded empty-linux-desktop)" = "$(recorded default-linux-desktop)" ]
}

@test "AC11: macInput is on by default and gates exactly karabiner-elements and linearmouse, in place" {
    run --separate-stderr casks default
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    local on="$output"
    run jq -e 'index("karabiner-elements") != null and index("linearmouse") != null
        and (index("betterdisplay") + 1 == index("karabiner-elements"))
        and (index("karabiner-elements") + 1 == index("linearmouse"))' <<<"$on"
    [ "$status" -eq 0 ] || { echo "$on"; return 1; }
    run --separate-stderr casks mac-input-off
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    local off="$output"
    run jq -e '(index("karabiner-elements") == null) and (index("linearmouse") == null)' <<<"$off"
    [ "$status" -eq 0 ] || { echo "$off"; return 1; }
    # Nothing else moves: the off list is the on list minus those two names.
    run jq -e --argjson on "$on" '$on - ["karabiner-elements","linearmouse"] == .' <<<"$off"
    [ "$status" -eq 0 ]
}

@test "macInput=false changes no Linux package set" {
    run --separate-stderr pkgs linux-cli mac-input-off
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = "$(pk default)" ]
}

@test "the Home Manager macos output also reads macInput from the selection" {
    run --separate-stderr hmjson macos mac-input-off myConfig.groups.macInput
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$output" = false ]
}

# ── Phase 3: WSL2 (AC15) ──

@test "AC15: the wsl profile evaluates with a non-default selection" {
    run --separate-stderr hmjson wsl media-go-off myConfig.groups
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '. == {go: false, macInput: true, media: false, security: true}' <<<"$output"
    [ "$status" -eq 0 ]
    run --separate-stderr pkgs wsl media-go-off
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '(["ffmpeg","go"] - . == ["ffmpeg","go"]) and (["fish","ripgrep","git"] - . == [])' <<<"$output"
    [ "$status" -eq 0 ]
}

# selection_dir with a WSL-style environment. The directory must come from the
# Linux $HOME; a Windows drive mount (/mnt/<letter>) is never a home for it.
wsl_dir() {
    env -u APP_CONFIGS_SELECTION_DIR -u XDG_CONFIG_HOME "$@" bash -c 'source "$1/ops/lib/selection.sh"; selection_dir' _ "$REPO_ROOT"
}

@test "AC15: selection_dir resolves under the Linux HOME" {
    run --separate-stderr wsl_dir HOME=/home/x
    [ "$status" -eq 0 ]
    [ "$output" = /home/x/.config/app-configs/selection ]
}

@test "AC15: an XDG_CONFIG_HOME inside the Linux HOME is honoured" {
    run --separate-stderr wsl_dir HOME=/home/x XDG_CONFIG_HOME=/home/x/cfg
    [ "$status" -eq 0 ]
    [ "$output" = /home/x/cfg/app-configs/selection ]
}

@test "AC15: an XDG_CONFIG_HOME under /mnt/c is ignored in favour of HOME/.config" {
    run --separate-stderr wsl_dir HOME=/home/x XDG_CONFIG_HOME=/mnt/c/Users/x/AppData
    [ "$status" -eq 0 ]
    [ "$output" = /home/x/.config/app-configs/selection ]
}

@test "S6: the /mnt note is printed once per process, not on every call" {
    run --separate-stderr env -u APP_CONFIGS_SELECTION_DIR HOME=/home/x XDG_CONFIG_HOME=/mnt/c/Users/x/AppData \
        bash -c 'source "$1/ops/lib/selection.sh"; selection_args; selection_args; selection_args; selection_dir >/dev/null' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"XDG_CONFIG_HOME"* ]]
    [[ "$stderr" == *"/mnt/c"* ]]
    [ "$(grep -c 'XDG_CONFIG_HOME' <<<"$stderr")" -eq 1 ]
}

@test "S6: no note when XDG_CONFIG_HOME is not on a drive" {
    run --separate-stderr env -u APP_CONFIGS_SELECTION_DIR HOME=/home/x XDG_CONFIG_HOME=/home/x/cfg \
        bash -c 'source "$1/ops/lib/selection.sh"; selection_args' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
}

@test "AC15: any drive letter and the bare mount point are treated as Windows paths" {
    run --separate-stderr wsl_dir HOME=/home/x XDG_CONFIG_HOME=/mnt/d
    [ "$output" = /home/x/.config/app-configs/selection ]
    run --separate-stderr wsl_dir HOME=/home/x XDG_CONFIG_HOME=/mnt/wsl/foo
    [ "$output" = /mnt/wsl/foo/app-configs/selection ]
}

@test "AC15: APP_CONFIGS_SELECTION_DIR stays an explicit override" {
    run --separate-stderr env HOME=/home/x APP_CONFIGS_SELECTION_DIR=/mnt/c/scratch bash -c 'source "$1/ops/lib/selection.sh"; selection_dir' _ "$REPO_ROOT"
    [ "$output" = /mnt/c/scratch ]
}

# ── S2: a wrong-typed group fails every host build, not only install.sh ──

@test "S2: a wrong-type macInput fails the linux-cli build and names the option" {
    run drv linux-cli wrong-type-macinput
    [ "$status" -ne 0 ]
    [[ "$output" == *"myConfig.groups.macInput"* ]]
}

@test "S2: a wrong-type macInput fails the macos and darwin builds too" {
    run drv macos wrong-type-macinput
    [ "$status" -ne 0 ]
    [[ "$output" == *"myConfig.groups.macInput"* ]]
    run drvd wrong-type-macinput
    [ "$status" -ne 0 ]
    [[ "$output" == *"myConfig.groups.macInput"* ]]
}
