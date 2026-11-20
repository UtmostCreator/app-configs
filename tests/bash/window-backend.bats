#!/usr/bin/env bats
# Tests for nix/modules/home/scripts/window-backend.sh — the one interface the
# window helpers (vicinae-toggle-app, vicinae-focus-tracker, vicinae-resize,
# vscode-recent-projects) use to reach the compositor (T-0031).
#
# Only the GNOME backend exists (window-backend-gnome.sh). These tests pin the
# exact busctl/gdbus/jq argv each wb_ function issues, which is the argv the
# helpers issued before they went through the library.
#
# Every tool is a stub that records its argv, one "<tool>|arg|arg..." line per
# call. `jq` records and then runs the real jq.
#
# Run:  bats tests/bash/window-backend.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPTS="$REPO_ROOT/nix/modules/home/scripts"
    LIB="$SCRIPTS/window-backend.sh"

    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    export PAYLOAD="$BATS_TEST_TMPDIR/payload"
    : >"$CALLS"
    REAL_JQ="$(command -v jq)"
    export REAL_JQ

    cat >"$STUBS/busctl" <<'EOF'
#!/usr/bin/env bash
(IFS='|'; printf 'busctl|%s\n' "$*") >>"$CALLS"
echo "busctl noise" >&2
[ "${BUS_FAIL:-0}" = 0 ] || exit 1
cat "$PAYLOAD"
EOF
    cat >"$STUBS/gdbus" <<'EOF'
#!/usr/bin/env bash
(IFS='|'; printf 'gdbus|%s\n' "$*") >>"$CALLS"
echo "()"
[ "${GDBUS_FAIL:-0}" = 0 ]
EOF
    cat >"$STUBS/jq" <<'EOF'
#!/usr/bin/env bash
(IFS='|'; printf 'jq|%s\n' "$*") >>"$CALLS"
exec "$REAL_JQ" "$@"
EOF
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
    unset WINDOW_BACKEND BUS_FAIL GDBUS_FAIL WB_BUSCTL WB_JQ WB_GDBUS
}

# Sources the library in a fresh bash and runs one command line against it.
wb() { run bash -c '. "$1"; shift; "$@"' wb "$LIB" "$@"; }

# Wraps a JSON document the way the Vicinae extension returns it over D-Bus:
# a single string holding the JSON text.
dbus_string() { printf '%s' "$1" | "$REAL_JQ" -Rs '{type: "s", data: [.]}' >"$PAYLOAD"; }

list_argv='busctl|--user|--json=short|call|org.gnome.Shell|/org/gnome/Shell/Extensions/Windows|org.gnome.Shell.Extensions.Windows|List'
focused_argv='busctl|--user|--json=short|call|org.gnome.Shell|/org/gnome/Shell/Extensions/Windows|org.gnome.Shell.Extensions.Windows|GetFocusedWindowSync'
gdbus_prefix='gdbus|call|--session|--dest|org.gnome.Shell|--object-path|/org/gnome/Shell/Extensions/Windows|--method|org.gnome.Shell.Extensions.Windows'

@test "wb_list: prints the window array, compact, from the List call" {
    dbus_string '[{"id": 10, "wm_class": "code", "title": "it'\''s \"x\"", "has_focus": true}]'
    wb wb_list
    [ "$status" -eq 0 ]
    [ "$output" = '[{"id":10,"wm_class":"code","title":"it'\''s \"x\"","has_focus":true}]' ]
    [ "$(cat "$CALLS")" = "$list_argv
jq|-ce|.data[0] | fromjson | select(type == \"array\")" ]
}

@test "wb_list: a failed List call returns 1, prints nothing, and skips jq" {
    dbus_string '[]'
    BUS_FAIL=1 wb wb_list
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$(cat "$CALLS")" = "$list_argv" ]
}

@test "wb_list: a payload that is not a window array returns 2 and prints nothing" {
    dbus_string '{"id": 10}'
    wb wb_list
    [ "$status" -eq 2 ]
    [ -z "$output" ]

    printf 'not json' >"$PAYLOAD"
    wb wb_list
    [ "$status" -eq 2 ]
    [ -z "$output" ]
}

@test "wb_focused: prints the focused window object from GetFocusedWindowSync" {
    dbus_string '{"id": 7, "x": 1, "y": 2, "width": 3, "height": 4}'
    wb wb_focused
    [ "$status" -eq 0 ]
    [ "$output" = '{"id":7,"x":1,"y":2,"width":3,"height":4}' ]
    [ "$(cat "$CALLS")" = "$focused_argv
jq|-ce|.data[0] | fromjson | select(type == \"object\")" ]
}

@test "wb_focused: a failed call or a non-object payload fails and prints nothing" {
    dbus_string '{"id": 7}'
    BUS_FAIL=1 wb wb_focused
    [ "$status" -eq 1 ]
    [ -z "$output" ]

    dbus_string '[]'
    wb wb_focused
    [ "$status" -eq 2 ]
    [ -z "$output" ]
}

@test "wb_outputs: prints the Mutter DisplayConfig state as busctl returns it" {
    printf '{"type":"ua","data":[1,[],[],{}]}\n' >"$PAYLOAD"
    wb wb_outputs
    [ "$status" -eq 0 ]
    [ "$output" = '{"type":"ua","data":[1,[],[],{}]}' ]
    [ "$(cat "$CALLS")" = 'busctl|--user|--json=short|call|org.gnome.Mutter.DisplayConfig|/org/gnome/Mutter/DisplayConfig|org.gnome.Mutter.DisplayConfig|GetCurrentState' ]
}

@test "wb_outputs: a failed call fails and prints nothing" {
    : >"$PAYLOAD"
    BUS_FAIL=1 wb wb_outputs
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "wb_focus: calls Activate with the window id" {
    wb wb_focus 42
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = "$gdbus_prefix.Activate|42" ]
}

@test "wb_hide: calls Minimize with the window id" {
    wb wb_hide 42
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = "$gdbus_prefix.Minimize|42" ]
}

@test "wb_move_resize: calls MoveResize with id, x, y, width, height" {
    wb wb_move_resize 42 430 32 2580 1408
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = "$gdbus_prefix.MoveResize|42|430|32|2580|1408" ]
}

@test "window actions pass the gdbus exit status through" {
    for fn in wb_focus wb_hide wb_move_resize; do
        echo "fn: $fn"
        GDBUS_FAIL=1 wb "$fn" 42 0 0 1 1
        [ "$status" -eq 1 ]
    done
}

@test "WB_BUSCTL, WB_JQ and WB_GDBUS name the tools, bypassing PATH" {
    alt="$BATS_TEST_TMPDIR/alt"
    mkdir -p "$alt"
    for tool in busctl jq gdbus; do
        cp "$STUBS/$tool" "$alt/$tool"
        printf '#!/usr/bin/env bash\necho "%s from PATH" >>"$CALLS"\nexit 1\n' "$tool" >"$STUBS/$tool"
    done
    dbus_string '[]'
    WB_BUSCTL="$alt/busctl" WB_JQ="$alt/jq" WB_GDBUS="$alt/gdbus" \
        run bash -c '. "$1"; wb_list && wb_focus 5' wb "$LIB"
    [ "$status" -eq 0 ]
    run grep -c 'from PATH' "$CALLS"
    [ "$output" = 0 ]
    [ "$(wc -l <"$CALLS")" -eq 3 ]
}

@test "WINDOW_BACKEND=gnome selects the GNOME backend explicitly" {
    dbus_string '[]'
    WINDOW_BACKEND=gnome wb wb_list
    [ "$status" -eq 0 ]
    [ "$output" = '[]' ]
}

@test "an unknown WINDOW_BACKEND fails clearly before any call" {
    WINDOW_BACKEND=sway wb wb_list
    [ "$status" -eq 2 ]
    [ "$output" = "window-backend: unknown WINDOW_BACKEND 'sway' (supported: gnome)" ]
    [ ! -s "$CALLS" ]
}

@test "an unknown WINDOW_BACKEND stops a helper before it touches a window" {
    WINDOW_BACKEND=sway run bash "$SCRIPTS/vicinae-toggle-app.sh" code
    [ "$status" -eq 2 ]
    [ "$output" = "window-backend: unknown WINDOW_BACKEND 'sway' (supported: gnome)" ]
    [ ! -s "$CALLS" ]
}

@test "the library is found next to itself from any working directory" {
    dbus_string '[]'
    cd "$SCRIPTS"
    run bash -c '. window-backend.sh; wb_list'
    [ "$status" -eq 0 ]
    [ "$output" = '[]' ]

    # A helper run by bare file name finds the library too.
    run bash vicinae-resize.sh 0
    [ "$status" -eq 2 ]
    [[ "$output" = usage:* ]]
}

@test "sourcing the library twice, or after its backend, is harmless" {
    dbus_string '[]'
    run bash -c '. "$1/window-backend-gnome.sh"; . "$1/window-backend.sh"; . "$1/window-backend.sh"; wb_list' wb "$SCRIPTS"
    [ "$status" -eq 0 ]
    [ "$output" = '[]' ]
}

@test "the library has no side effects on shell options or PATH" {
    run bash -c 'before="$-:$PATH"; . "$1" || exit 3; [ "$before" = "$-:$PATH" ]' wb "$LIB"
    [ "$status" -eq 0 ]
}
