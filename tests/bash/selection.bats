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
    run jq -e '.work == ["go","media","security"] and .personal == ["go","media","security"]' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "default: every group is on" {
    run --separate-stderr hmjson linux-cli default myConfig.groups
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    run jq -e '. == {go: true, media: true, security: true}' <<<"$output"
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
    run jq -e '. == {go: false, media: false, security: true}' <<<"$output"
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
    run jq -e '. == {go: false, media: false, security: true}' <<<"$output"
    [ "$status" -eq 0 ]
}
