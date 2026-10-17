#!/usr/bin/env bats
# Tests for home/dot_claude/modify_settings.json.tmpl — the chezmoi modify_
# script that owns ~/.claude/settings.json.
#
# Claude Code rewrites its settings file itself (key order, keys added from
# /config). A plain managed file turns every such rewrite into a chezmoi
# "has changed since chezmoi last wrote it" prompt, which fails `sys-update`
# (apply --no-tty → EOF). The modify_ script instead merges the repo's keys
# into whatever is on disk, so a rewrite with the same content is a no-op.
#
# Run:  bats tests/bash/claude-settings-modify.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TMPL="$REPO_ROOT/home/dot_claude/modify_settings.json.tmpl"
    MANAGED="$REPO_ROOT/home/.chezmoitemplates/claude/settings.json"
    [ -f "$TMPL" ]
    [ -f "$MANAGED" ]
    # Render the template once, with an empty config so host data is irrelevant.
    SCRIPT="$BATS_TEST_TMPDIR/modify.sh"
    printf "{}\n" >"$BATS_TEST_TMPDIR/chezmoi.json"
    chezmoi --config "$BATS_TEST_TMPDIR/chezmoi.json" --persistent-state "$BATS_TEST_TMPDIR/state.boltdb" --source "$REPO_ROOT/home" execute-template <"$TMPL" >"$SCRIPT"
}

modify() { bash "$SCRIPT"; }

@test "the old plain source file is gone (one owner for the target)" {
    [ ! -e "$REPO_ROOT/home/dot_claude/settings.json" ]
}

@test "managed settings are valid JSON" {
    jq -e 'type == "object"' "$MANAGED" >/dev/null
}

@test "no existing file: writes exactly the managed settings" {
    run modify </dev/null
    [ "$status" -eq 0 ]
    [ "$(jq -S . <<<"$output")" = "$(jq -S . "$MANAGED")" ]
}

@test "same content in another key order is left byte-for-byte alone" {
    current="$(jq '{hooks, theme} + .' "$MANAGED")"   # reorder keys
    [ "$current" != "$(cat "$MANAGED")" ]
    run modify <<<"$current"
    [ "$status" -eq 0 ]
    [ "$output" = "$current" ]
}

@test "keys Claude Code added itself are kept" {
    current="$(jq '. + {feedbackSurveyState: {lastShownTime: 1}}' "$MANAGED")"
    run modify <<<"$current"
    [ "$status" -eq 0 ]
    [ "$(jq -c .feedbackSurveyState <<<"$output")" = '{"lastShownTime":1}' ]
}

@test "repo values win for managed keys, arrays included" {
    current="$(jq '.theme = "light" | .hooks.PreToolUse = [] | .statusLine.padding = 9' "$MANAGED")"
    run modify <<<"$current"
    [ "$status" -eq 0 ]
    [ "$(jq -S . <<<"$output")" = "$(jq -S . "$MANAGED")" ]
}

@test "unparseable current file is replaced with the managed settings" {
    run modify <<<'{ not json'
    [ "$status" -eq 0 ]
    [ "$(jq -S . <<<"$output")" = "$(jq -S . "$MANAGED")" ]
}

@test "without jq the managed settings are written verbatim" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    for t in bash cat; do ln -s "$(command -v "$t")" "$BATS_TEST_TMPDIR/bin/$t"; done
    run env PATH="$BATS_TEST_TMPDIR/bin" bash "$SCRIPT" <<<'{"extra": 1}'
    [ "$status" -eq 0 ]
    [ "$(jq -S . <<<"$output")" = "$(jq -S . "$MANAGED")" ]
}
