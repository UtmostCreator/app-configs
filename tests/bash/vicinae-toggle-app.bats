#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/nix/modules/home/scripts/vicinae-toggle-app.sh"
    export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/runtime"
    export WINDOWS="$BATS_TEST_TMPDIR/windows.json"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    mkdir -p "$BATS_TEST_TMPDIR/bin" "$XDG_RUNTIME_DIR/vicinae-toggle-app"
    : >"$CALLS"
    cat >"$BATS_TEST_TMPDIR/bin/busctl" <<'EOF'
#!/usr/bin/env bash
[ "${BUS_FAIL:-0}" = 0 ] || exit 1
jq -Rs '{type: "s", data: [.]}' "$WINDOWS"
EOF
    cat >"$BATS_TEST_TMPDIR/bin/gdbus" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CALLS"
[ "${ACTIVATE_FAIL:-0}" = 0 ]
EOF
    cat >"$BATS_TEST_TMPDIR/bin/vicinae" <<'EOF'
#!/usr/bin/env bash
echo "launch $*" >>"$CALLS"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    unset BUS_FAIL ACTIVATE_FAIL
    # A title containing an apostrophe makes gdbus quote/escape its entire
    # JSON string differently. Double quotes, newlines and slashes must also
    # survive both the D-Bus string and JSON decoding layers.
    jq -n --arg title $'Creator\047s "terminal" \\ path\nnext line' '[
      {id: 10, wm_class: "com.mitchellh.ghostty", title: $title, has_focus: false},
      {id: 20, wm_class: "Brave-browser", title: $title, has_focus: false},
      {id: 21, wm_class: "brave-browser", title: "second", has_focus: false}
    ]' >"$WINDOWS"
}

@test "Alt+Shift+T activates the existing terminal with escaped window titles" {
    run bash "$SCRIPT" com.mitchellh.ghostty
    [ "$status" -eq 0 ]
    [[ "$(cat "$CALLS")" = *".Activate 10" ]]
    [ "$(wc -l <"$CALLS")" -eq 1 ]
}

@test "F1 returns to the most recently used browser window" {
    echo 21 >"$XDG_RUNTIME_DIR/vicinae-toggle-app/brave-browser"
    run bash "$SCRIPT" brave-browser
    [ "$status" -eq 0 ]
    [[ "$(cat "$CALLS")" = *".Activate 21" ]]
    [ "$(wc -l <"$CALLS")" -eq 1 ]
}

@test "a closed remembered browser window falls back to an existing one" {
    echo 999 >"$XDG_RUNTIME_DIR/vicinae-toggle-app/brave-browser"
    run bash "$SCRIPT" brave-browser
    [ "$status" -eq 0 ]
    [[ "$(cat "$CALLS")" = *".Activate 20" ]]
}

@test "an already focused window keeps the existing minimize toggle behavior" {
    jq '.[0].has_focus = true' "$WINDOWS" >"$WINDOWS.tmp"
    mv "$WINDOWS.tmp" "$WINDOWS"
    run bash "$SCRIPT" com.mitchellh.ghostty
    [ "$status" -eq 0 ]
    [[ "$(cat "$CALLS")" = *".Minimize 10" ]]
    [ "$(cat "$XDG_RUNTIME_DIR/vicinae-toggle-app/com.mitchellh.ghostty")" = 10 ]
}

@test "launches only when a valid window list has no matching app" {
    echo '[]' >"$WINDOWS"
    run bash "$SCRIPT" brave-browser
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = "launch app launch brave-browser" ]
}

@test "unavailable D-Bus never launches a duplicate" {
    export BUS_FAIL=1
    run bash "$SCRIPT" brave-browser
    [ "$status" -eq 1 ]
    [ ! -s "$CALLS" ]
}

@test "invalid window data never launches a duplicate" {
    for data in 'not json' '{}' 'null' ''; do
        printf '%s' "$data" >"$WINDOWS"
        run bash "$SCRIPT" brave-browser
        [ "$status" -eq 1 ]
        [ ! -s "$CALLS" ]
    done
}

@test "failed activation never launches a duplicate" {
    export ACTIVATE_FAIL=1
    run bash "$SCRIPT" brave-browser
    [ "$status" -eq 1 ]
    [[ "$(cat "$CALLS")" = *".Activate 20" ]]
    [ "$(wc -l <"$CALLS")" -eq 1 ]
}

@test "focus tracker remembers the focused window despite escaped titles" {
    jq '.[2].has_focus = true' "$WINDOWS" >"$WINDOWS.tmp"
    mv "$WINDOWS.tmp" "$WINDOWS"
    # Stop after one iteration, after the tracker has written its state.
    cat >"$BATS_TEST_TMPDIR/bin/sleep" <<'EOF'
#!/usr/bin/env bash
kill -TERM "$PPID"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/sleep"
    run bash "$REPO_ROOT/nix/modules/home/scripts/vicinae-focus-tracker.sh"
    [ "$(cat "$XDG_RUNTIME_DIR/vicinae-toggle-app/brave-browser")" = 21 ]
}
