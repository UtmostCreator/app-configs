#!/usr/bin/env bats
# Tests for the chezmoi modify_ script that owns VS Code's user settings.json
# (home/dot_config/Code/User/modify_settings.json.tmpl on Linux and
# home/Library/Application Support/Code/User/modify_settings.json.tmpl on
# macOS; both render home/.chezmoitemplates/vscode/modify-settings.sh).
#
# VS Code rewrites settings.json itself (workspace trust, UI toggles, synced
# settings). As a plain managed file every such rewrite became a chezmoi
# "edited since chezmoi wrote it" conflict that stopped `sys-update`. The
# modify_ script merges the repo's keys into whatever is on disk instead.
#
# Run:  bats tests/bash/vscode-settings-modify.bats

setup() {
    command -v chezmoi >/dev/null || skip "chezmoi not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    LINUX_TMPL="$REPO_ROOT/home/dot_config/Code/User/modify_settings.json.tmpl"
    MAC_TMPL="$REPO_ROOT/home/Library/Application Support/Code/User/modify_settings.json.tmpl"
    FULL="$REPO_ROOT/home/.chezmoitemplates/vscode/settings.full.json"
    MINIMAL="$REPO_ROOT/home/.chezmoitemplates/vscode/settings.minimal.json"
    [ -f "$LINUX_TMPL" ]
    [ -f "$MAC_TMPL" ]
    printf '{}\n' >"$BATS_TEST_TMPDIR/chezmoi.json"
    render full >"$BATS_TEST_TMPDIR/full.sh"
    render minimal >"$BATS_TEST_TMPDIR/minimal.sh"
    SCRIPT="$BATS_TEST_TMPDIR/full.sh"
    # The repo's full settings as strict JSON: an empty object merged with them.
    FULL_JSON="$(bash "$SCRIPT" <<<'{}')"
}

# render full|minimal [template]: the rendered modify script.
render() {
    local minimal=false tmpl="${2:-$LINUX_TMPL}"
    [ "$1" = minimal ] && minimal=true
    chezmoi --config "$BATS_TEST_TMPDIR/chezmoi.json" \
        --persistent-state "$BATS_TEST_TMPDIR/state.boltdb" \
        --source "$REPO_ROOT/home" \
        --override-data "{\"minimal\":$minimal}" \
        execute-template <"$tmpl"
}

modify() { bash "$SCRIPT"; }

@test "the old full-file templates are gone (one owner per target)" {
    [ ! -e "$REPO_ROOT/home/dot_config/Code/User/settings.json.tmpl" ]
    [ ! -e "$REPO_ROOT/home/Library/Application Support/Code/User/settings.json.tmpl" ]
}

@test "Linux and macOS render the same script" {
    [ "$(render full "$MAC_TMPL")" = "$(cat "$BATS_TEST_TMPDIR/full.sh")" ]
    [ "$(render minimal "$MAC_TMPL")" = "$(cat "$BATS_TEST_TMPDIR/minimal.sh")" ]
}

@test "rendered script passes bash -n" {
    bash -n "$BATS_TEST_TMPDIR/full.sh"
    bash -n "$BATS_TEST_TMPDIR/minimal.sh"
}

@test "both repo templates parse as JSONC into a full object" {
    [ "$(jq length <<<"$FULL_JSON")" -gt 50 ]
    [ "$(jq -r '."editor.minimap.enabled"' <<<"$FULL_JSON")" = true ]
    [ "$(bash "$BATS_TEST_TMPDIR/minimal.sh" <<<'{}' | jq -c '."files.eol"')" = '"\n"' ]
}

@test "no existing file: writes the repo template, comments and all" {
    run modify </dev/null
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$FULL")" ]
}

@test "minimal vs full: the minimal data key picks the minimal template" {
    run bash "$BATS_TEST_TMPDIR/minimal.sh" </dev/null
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$MINIMAL")" ]
    [ "$output" != "$(cat "$FULL")" ]
}

@test "keys VS Code or the user added are kept" {
    current="$(jq '. + {"zz.user.theme": "Solarized", "zz.user.flag": true}' <<<"$FULL_JSON")"
    run modify <<<"$current"
    [ "$status" -eq 0 ]
    [ "$(jq -r '."zz.user.theme"' <<<"$output")" = Solarized ]
    [ "$(jq -r '."zz.user.flag"' <<<"$output")" = true ]
}

@test "repo values win for managed keys" {
    current="$(jq '."editor.minimap.enabled" = false | ."search.exclude" = {}' <<<"$FULL_JSON")"
    run modify <<<"$current"
    [ "$status" -eq 0 ]
    [ "$(jq -S . <<<"$output")" = "$(jq -S . <<<"$FULL_JSON")" ]
}

@test "a merge that changes nothing is byte-for-byte the input" {
    # VS Code's own formatting (4-space indent, no trailing newline).
    current="$(jq --indent 4 '. + {"zz.vscode.toggle": "prompt"}' <<<"$FULL_JSON")"
    printf '%s' "$current" >"$BATS_TEST_TMPDIR/in.json"
    modify <"$BATS_TEST_TMPDIR/in.json" >"$BATS_TEST_TMPDIR/out.json"
    cmp "$BATS_TEST_TMPDIR/in.json" "$BATS_TEST_TMPDIR/out.json"
}

@test "idempotent: a second run gives the same bytes" {
    current="$(jq '."editor.minimap.enabled" = false | . + {"zzz.user": 1}' <<<"$FULL_JSON")"
    modify <<<"$current" >"$BATS_TEST_TMPDIR/one.json"
    modify <"$BATS_TEST_TMPDIR/one.json" >"$BATS_TEST_TMPDIR/two.json"
    cmp "$BATS_TEST_TMPDIR/one.json" "$BATS_TEST_TMPDIR/two.json"
    [ "$(tail -c1 "$BATS_TEST_TMPDIR/one.json" | od -An -c | tr -d ' ')" = '\n' ]
}

@test "deterministic: live key order is kept, new repo keys follow it" {
    run modify <<<'{"zzz.user": 1, "editor.minimap.enabled": false}'
    [ "$status" -eq 0 ]
    [ "$(jq -r 'keys_unsorted[0:2] | join(",")' <<<"$output")" = "zzz.user,editor.minimap.enabled" ]
    [ "$(jq -r '."editor.minimap.enabled"' <<<"$output")" = true ]
}

@test "JSONC input (comments, trailing commas) is merged, not wiped" {
    current='{
  // my own note
  "zz.user.theme": "Solarized", /* inline */
  "url.with.slashes": "http://example.com/a//b",
  "editor.minimap.enabled": false,
}'
    run modify <<<"$current"
    [ "$status" -eq 0 ]
    [ "$(jq -r '."zz.user.theme"' <<<"$output")" = Solarized ]
    [ "$(jq -r '."url.with.slashes"' <<<"$output")" = "http://example.com/a//b" ]
    [ "$(jq -r '."editor.minimap.enabled"' <<<"$output")" = true ]
}

@test "the live file as chezmoi wrote it before (the JSONC template) is left alone" {
    run modify <"$FULL"
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$FULL")" ]
}

@test "unparseable input is emitted unchanged with a warning on stderr" {
    printf '{ "a": 1, oops\n' >"$BATS_TEST_TMPDIR/bad.json"
    modify <"$BATS_TEST_TMPDIR/bad.json" >"$BATS_TEST_TMPDIR/out.json" 2>"$BATS_TEST_TMPDIR/err"
    cmp "$BATS_TEST_TMPDIR/bad.json" "$BATS_TEST_TMPDIR/out.json"
    grep -qi 'left unchanged' "$BATS_TEST_TMPDIR/err"
}

@test "a non-object JSON file is emitted unchanged" {
    run bash -c 'bash "$1" <<<"[1, 2]" 2>/dev/null' _ "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$output" = '[1, 2]' ]
}

@test "VS Code flipping a repo-owned toggle is merged back, other keys kept" {
    # The real-world trigger: VS Code wrote untrustedFiles "prompt" and its own
    # keys; the repo value comes back without touching the rest.
    current="$(jq '."security.workspace.trust.untrustedFiles" = "prompt" | . + {"zz.vscode.state": 3}' <<<"$FULL_JSON")"
    run modify <<<"$current"
    [ "$status" -eq 0 ]
    [ "$(jq -r '."security.workspace.trust.untrustedFiles"' <<<"$output")" = open ]
    [ "$(jq -r '."zz.vscode.state"' <<<"$output")" = 3 ]
}

@test "without jq an existing file is left unchanged" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    for t in bash cat mktemp rm awk grep; do ln -s "$(command -v "$t")" "$BATS_TEST_TMPDIR/bin/$t"; done
    run env PATH="$BATS_TEST_TMPDIR/bin" bash "$SCRIPT" <<<'{"extra": 1}'
    [ "$status" -eq 0 ]
    [[ "$output" == *'{"extra": 1}'* ]]
}

@test "without jq and no file yet the repo template is written" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    for t in bash cat mktemp rm awk grep; do ln -s "$(command -v "$t")" "$BATS_TEST_TMPDIR/bin/$t"; done
    run env PATH="$BATS_TEST_TMPDIR/bin" bash "$SCRIPT" </dev/null
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$FULL")" ]
}
