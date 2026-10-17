#!/usr/bin/env bats
# Tests for nix/modules/home/scripts/vicinae-resize.sh — Alt+Shift+F resizes
# the focused window to a percentage of the monitor it is on.
#
# Regression: monitor geometry came from XWayland's `xrandr`, which is not
# GNOME's logical layout. After a resolution/scale change the window was sized
# from the wrong numbers. Geometry now comes from Mutter's DisplayConfig
# (GetCurrentState, read as JSON via busctl), which is always current.
#
# D-Bus is stubbed: `gdbus` records MoveResize, `busctl` serves the focused
# window and a DisplayConfig state built by `display_state`, and `xrandr`
# always reports a stale 3440x1440 so any reliance on it shows up as a failure.
#
# Run:  bats tests/bash/vicinae-resize.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/nix/modules/home/scripts/vicinae-resize.sh"
    [ -f "$SCRIPT" ]

    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    export WIN_JSON="$BATS_TEST_TMPDIR/window.json"
    export DISPLAY_JSON="$BATS_TEST_TMPDIR/display.json"
    : >"$CALLS"

    cat >"$STUBS/gdbus" <<'EOF'
#!/usr/bin/env bash
method="" ; args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --method) method="${2##*.}"; shift 2 ;;
        call|--session) shift ;;
        --dest|--object-path) shift 2 ;;
        *) args+=("$1"); shift ;;
    esac
done
case "$method" in
    GetFocusedWindowSync)
        [ -s "$WIN_JSON" ] || exit 1
        printf "('%s',)\n" "$(cat "$WIN_JSON")" ;;
    MoveResize) echo "MoveResize ${args[*]}" >>"$CALLS"; echo "()" ;;
    *) exit 1 ;;
esac
EOF
    cat >"$STUBS/busctl" <<'EOF'
#!/usr/bin/env bash
if [ "${*: -1}" = GetFocusedWindowSync ]; then
    [ -s "$WIN_JSON" ] || exit 1
    jq -Rs '{type: "s", data: [.]}' "$WIN_JSON"
else
    [ -s "$DISPLAY_JSON" ] || exit 1
    cat "$DISPLAY_JSON"
fi
EOF
    cat >"$STUBS/xrandr" <<'EOF'
#!/usr/bin/env bash
echo "DP-1 connected primary 3440x1440+0+0 (normal left inverted right x axis y axis) 800mm x 330mm"
EOF
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
    unset VICINAE_RESIZE_TOP_MARGIN
}

# window <x> <y> <w> <h>: the focused window, as the Vicinae extension reports it.
window() {
    jq -nc --argjson x "$1" --argjson y "$2" --argjson w "$3" --argjson h "$4" \
        '{id: 42, title: "t", wm_class: "app", maximized: false, x: $x, y: $y, width: $w, height: $h, has_focus: true}' >"$WIN_JSON"
}

# display_state <layout-mode> <monitor>...
#   monitor = connector:modeW:modeH:x:y:scale:transform:primary
#   modeW=0 means the connector is plugged in but disabled (no current mode,
#   no logical monitor), like a closed laptop lid.
# Writes the busctl --json=short shape of DisplayConfig.GetCurrentState.
display_state() {
    local layout="$1"; shift
    printf '%s\n' "$@" | jq -Rn --argjson layout "$layout" '
        [inputs | split(":") | {c: .[0], w: (.[1]|tonumber), h: (.[2]|tonumber),
            x: (.[3]|tonumber), y: (.[4]|tonumber), s: (.[5]|tonumber),
            t: (.[6]|tonumber), p: (.[7] == "true")}] as $m
        | {type: "ua((ssss)a(siiddada{sv})a{sv})a(iiduba(ssss)a{sv})a{sv}",
           data: [1,
             [$m[] | [[.c, "V", "P", "S"],
                      [["2560x1600@60", 2560, 1600, 60.0, 1.0, [1.0], {}]]
                      + (if .w > 0 then [["cur", .w, .h, 60.0, 1.0, [1.0],
                            {"is-current": {type: "b", data: true}}]] else [] end),
                      {}]],
             [$m[] | select(.w > 0) | [.x, .y, .s, .t, .p, [[.c, "V", "P", "S"]], {}]],
             {"layout-mode": {type: "u", data: $layout}}]}' >"$DISPLAY_JSON"
}

resize() { run bash "$SCRIPT" "$@"; }
moved() { cat "$CALLS"; }

@test "ultrawide at scale 1: 75% wide, full height under the top panel" {
    display_state 1 "DP-1:3440:1440:0:0:1:0:true"
    window 0 32 1200 800
    resize 75 100
    [ "$status" -eq 0 ]
    [ "$(moved)" = "MoveResize 42 430 32 2580 1408" ]
}

@test "regression: a resolution change is followed, stale xrandr is ignored" {
    display_state 1 "DP-1:1920:1080:0:0:1:0:true"
    window 100 100 800 600
    resize 75 100
    [ "$(moved)" = "MoveResize 42 240 32 1440 1048" ]
}

@test "fractional scale in logical layout: sizes use logical pixels" {
    # 2560x1600 at 133% is a 1920x1200 logical monitor.
    display_state 1 "DP-1:0:0:0:0:1:0:false" "eDP-2:2560:1600:0:0:1.3333333730697632:0:true"
    window 100 100 800 600
    resize 75 100
    [ "$(moved)" = "MoveResize 42 240 32 1440 1168" ]
}

@test "physical layout mode: sizes and the panel margin are in device pixels" {
    display_state 2 "eDP-2:2560:1600:0:0:2:0:true"
    window 100 100 800 600
    resize 50 50
    [ "$(moved)" = "MoveResize 42 640 448 1280 768" ]
}

@test "two monitors: the window is sized for the monitor it is on" {
    display_state 1 "eDP-2:2560:1600:0:0:1.3333333730697632:0:true" "DP-1:3440:1440:1920:0:1:0:false"
    window 2500 200 1000 700
    resize 75 100
    # Secondary monitor: no GNOME top panel there, so no margin.
    [ "$(moved)" = "MoveResize 42 2350 0 2580 1440" ]
}

@test "two monitors: a window on the primary still gets the panel margin" {
    display_state 1 "eDP-2:2560:1600:0:0:1.3333333730697632:0:true" "DP-1:3440:1440:1920:0:1:0:false"
    window 100 100 800 600
    resize 75 100
    [ "$(moved)" = "MoveResize 42 240 32 1440 1168" ]
}

@test "rotated monitor: width and height swap" {
    display_state 1 "DP-1:3440:1440:0:0:1:1:true"
    window 100 100 800 600
    resize 100 50
    [ "$(moved)" = "MoveResize 42 0 884 1440 1704" ]
}

@test "window centered off every monitor falls back to the primary" {
    display_state 1 "DP-1:1920:1080:0:0:1:0:true"
    window 5000 5000 400 300
    resize 75 100
    [ "$(moved)" = "MoveResize 42 240 32 1440 1048" ]
}

@test "top margin can be overridden" {
    display_state 1 "DP-1:1920:1080:0:0:1:0:true"
    window 100 100 800 600
    VICINAE_RESIZE_TOP_MARGIN=0 resize 50 50
    [ "$(moved)" = "MoveResize 42 480 270 960 540" ]
}

@test "defaults are 75% x 100%" {
    display_state 1 "DP-1:1920:1080:0:0:1:0:true"
    window 100 100 800 600
    resize
    [ "$(moved)" = "MoveResize 42 240 32 1440 1048" ]
}

@test "window D-Bus service missing: exits 0 without resizing" {
    display_state 1 "DP-1:1920:1080:0:0:1:0:true"
    : >"$WIN_JSON"
    resize 75 100
    [ "$status" -eq 0 ]
    [ -z "$(moved)" ]
}

@test "display config unavailable: exits 0 without resizing" {
    : >"$DISPLAY_JSON"
    window 100 100 800 600
    resize 75 100
    [ "$status" -eq 0 ]
    [ -z "$(moved)" ]
}

@test "invalid percentages are rejected" {
    display_state 1 "DP-1:1920:1080:0:0:1:0:true"
    window 100 100 800 600
    resize 0 100
    [ "$status" -eq 2 ]
    resize abc
    [ "$status" -eq 2 ]
    resize 101 50
    [ "$status" -eq 2 ]
    [ -z "$(moved)" ]
}
