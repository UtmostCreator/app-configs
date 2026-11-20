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

# --- Characterization tests (T-0031): behaviour that had no test. ------------

# Make `vicinae app launch` fail and record the direct executable fallbacks.
stub_failed_launch() {
    cat >"$BATS_TEST_TMPDIR/bin/vicinae" <<'EOF'
#!/usr/bin/env bash
echo "launch $*" >>"$CALLS"
exit 1
EOF
    for name in ghostty brave; do
        cat >"$BATS_TEST_TMPDIR/bin/$name" <<EOF
#!/usr/bin/env bash
echo "$name \$*" >>"\$CALLS"
EOF
    done
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
}

# One tracker iteration: `sleep` records its call, then stops the tracker.
stub_tracker_sleep() {
    cat >"$BATS_TEST_TMPDIR/bin/sleep" <<'EOF'
#!/usr/bin/env bash
echo "sleep $*" >>"$CALLS"
kill -TERM "$PPID"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/sleep"
}

@test "no app id prints usage and exits 2 without touching any window" {
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [ "$output" = "usage: vicinae-toggle-app <app_id> [wm_class]" ]
    [ ! -s "$CALLS" ]
}

@test "an explicit wm_class, not the app id, selects the running window" {
    jq -n '[
      {id: 30, wm_class: "org.keepassxc.KeePassXC", title: "decoy", has_focus: false},
      {id: 31, wm_class: "KeePassXC", title: "vault", has_focus: false}
    ]' >"$WINDOWS"
    run bash "$SCRIPT" org.keepassxc.KeePassXC keepassxc
    [ "$status" -eq 0 ]
    [[ "$(cat "$CALLS")" = *".Activate 31" ]]
    [ "$(wc -l <"$CALLS")" -eq 1 ]
    # MRU state is keyed by the wm_class, not the app id.
    [ "$(cat "$XDG_RUNTIME_DIR/vicinae-toggle-app/keepassxc")" = 31 ]
    [ ! -e "$XDG_RUNTIME_DIR/vicinae-toggle-app/org.keepassxc.keepassxc" ]
}

@test "an explicit wm_class with no window launches by app id" {
    jq -n '[{id: 30, wm_class: "org.keepassxc.KeePassXC", title: "decoy", has_focus: false}]' >"$WINDOWS"
    run bash "$SCRIPT" org.keepassxc.KeePassXC keepassxc
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = "launch app launch org.keepassxc.KeePassXC" ]
}

@test "the toggle MRU file name is the lowercased, sanitised wm_class" {
    jq -n '[{id: 40, wm_class: "My App/Odd:Class", title: "t", has_focus: true}]' >"$WINDOWS"
    run bash "$SCRIPT" some-app "My App/Odd:Class"
    [ "$status" -eq 0 ]
    [[ "$(cat "$CALLS")" = *".Minimize 40" ]]
    [ "$(ls "$XDG_RUNTIME_DIR/vicinae-toggle-app")" = "my_app_odd_class" ]
    [ "$(cat "$XDG_RUNTIME_DIR/vicinae-toggle-app/my_app_odd_class")" = 40 ]
}

@test "a failed Vicinae launch falls back to the ghostty executable" {
    echo '[]' >"$WINDOWS"
    stub_failed_launch
    run bash "$SCRIPT" com.mitchellh.ghostty
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = "launch app launch com.mitchellh.ghostty
ghostty --gtk-single-instance=true" ]
}

@test "a failed Vicinae launch falls back to the brave executable" {
    echo '[]' >"$WINDOWS"
    stub_failed_launch
    run bash "$SCRIPT" brave-browser
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = "launch app launch brave-browser
brave " ]
}

@test "a failed Vicinae launch of any other app exits 1 with no fallback" {
    echo '[]' >"$WINDOWS"
    stub_failed_launch
    run bash "$SCRIPT" obsidian
    [ "$status" -eq 1 ]
    [ "$(cat "$CALLS")" = "launch app launch obsidian" ]
}

@test "focus tracker writes nothing and keeps polling when D-Bus is unavailable" {
    export BUS_FAIL=1
    stub_tracker_sleep
    run bash "$REPO_ROOT/nix/modules/home/scripts/vicinae-focus-tracker.sh"
    [ "$(cat "$CALLS")" = "sleep 0.25" ]
    [ -z "$(ls -A "$XDG_RUNTIME_DIR/vicinae-toggle-app")" ]
}

@test "focus tracker writes nothing when no window is focused" {
    stub_tracker_sleep
    run bash "$REPO_ROOT/nix/modules/home/scripts/vicinae-focus-tracker.sh"
    [ "$(cat "$CALLS")" = "sleep 0.25" ]
    [ -z "$(ls -A "$XDG_RUNTIME_DIR/vicinae-toggle-app")" ]
}

@test "focus tracker file name is the lowercased, sanitised wm_class" {
    jq -n '[{id: 77, wm_class: "My App/Odd:Class", title: "t", has_focus: true}]' >"$WINDOWS"
    stub_tracker_sleep
    run bash "$REPO_ROOT/nix/modules/home/scripts/vicinae-focus-tracker.sh"
    [ "$(cat "$CALLS")" = "sleep 0.25" ]
    [ "$(ls "$XDG_RUNTIME_DIR/vicinae-toggle-app")" = "my_app_odd_class" ]
    [ "$(cat "$XDG_RUNTIME_DIR/vicinae-toggle-app/my_app_odd_class")" = 77 ]
}
