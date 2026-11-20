#!/usr/bin/env bats
# Tests for nix/modules/home/scripts/vscode-recent-projects.sh — Alt+E shows
# VS Code's recent projects in a Vicinae dmenu popup, opens the chosen folder
# with `code`, then focuses the matching VS Code window (T-0031).
#
# The Nix wrapper in nix/modules/home/gui.nix passes python3, code, basename,
# busctl, jq and gdbus as absolute paths (VRP_* variables); unset here, they
# fall back to PATH. `vicinae` and `sleep` come from the session.
# Here every one except jq and basename is a stub: `vicinae` plays the popup
# (prints $SELECTED), `code` and `gdbus` record their calls, `busctl` serves
# $WINDOWS (optionally only from the Nth List call on), `sleep` only records.
#
# Run:  bats tests/bash/vscode-recent-projects.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/nix/modules/home/scripts/vscode-recent-projects.sh"
    [ -f "$SCRIPT" ]

    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBS"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    export WINDOWS="$BATS_TEST_TMPDIR/windows.json"
    export LIST_COUNT="$BATS_TEST_TMPDIR/list-count"
    export MENU_INPUT="$BATS_TEST_TMPDIR/menu-input"
    export SELECTED="/work/app-configs"
    : >"$CALLS"
    : >"$LIST_COUNT"

    cat >"$STUBS/python3" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
[ -z "${RECENTS:-}" ] || printf '%s\n' "$RECENTS"
EOF
    cat >"$STUBS/vicinae" <<'EOF'
#!/usr/bin/env bash
echo "vicinae $*" >>"$CALLS"
cat >"$MENU_INPUT"
[ -z "${SELECTED:-}" ] || printf '%s\n' "$SELECTED"
EOF
    cat >"$STUBS/code" <<'EOF'
#!/usr/bin/env bash
echo "code $*" >>"$CALLS"
if [ "${CODE_FAIL:-0}" != 0 ]; then
    echo "code: boom"
    exit 1
fi
echo "noise that must stay quiet"
EOF
    # Serves $WINDOWS, but an empty window list until the ${WINDOWS_AFTER}th
    # List call, to play a VS Code window that appears late.
    cat >"$STUBS/busctl" <<'EOF'
#!/usr/bin/env bash
echo x >>"$LIST_COUNT"
[ "${BUS_FAIL:-0}" = 0 ] || exit 1
if [ "$(wc -l <"$LIST_COUNT")" -lt "${WINDOWS_AFTER:-1}" ]; then
    echo '[]' | jq -Rs '{type: "s", data: [.]}'
else
    jq -Rs '{type: "s", data: [.]}' "$WINDOWS"
fi
EOF
    cat >"$STUBS/gdbus" <<'EOF'
#!/usr/bin/env bash
echo "gdbus $*" >>"$CALLS"
[ "${ACTIVATE_FAIL:-0}" = 0 ]
EOF
    cat >"$STUBS/sleep" <<'EOF'
#!/usr/bin/env bash
echo "sleep $*" >>"$CALLS"
EOF
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
    unset BUS_FAIL ACTIVATE_FAIL CODE_FAIL WINDOWS_AFTER RECENTS

    # Order matters: the first `code` window is neither focused nor a title
    # match, so each selection rule picks a different id.
    jq -n '[
      {id: 1, wm_class: "brave-browser", title: "app-configs - Brave", has_focus: false},
      {id: 2, wm_class: "code", title: "a.txt - other - Visual Studio Code", has_focus: false},
      {id: 3, wm_class: "Code", title: "b.txt - third - Visual Studio Code", has_focus: true},
      {id: 4, wm_class: "code", title: "file - app-configs - Visual Studio Code", has_focus: false}
    ]' >"$WINDOWS"
}

activations() { grep -c '^gdbus ' "$CALLS" || true; }
sleeps() { grep -c '^sleep ' "$CALLS" || true; }

@test "the popup is Vicinae dmenu, fed with the recent-projects list" {
    export RECENTS=$'/work/app-configs\n/work/other'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(head -1 "$CALLS")" = "vicinae dmenu --navigation-title VS Code --placeholder Open recent project…" ]
    [ "$(cat "$MENU_INPUT")" = "$RECENTS" ]
}

@test "a dismissed popup opens nothing and focuses nothing" {
    export SELECTED=""
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run grep -q '^code ' "$CALLS"
    [ "$status" -eq 1 ]
    [ "$(activations)" -eq 0 ]
    [ ! -s "$LIST_COUNT" ]
}

@test "the selection is opened with code, quietly" {
    export SELECTED="/work/my projects/app-configs"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    grep -qx 'code /work/my projects/app-configs' "$CALLS"
}

@test "a failed code exits 1 with its output and focuses nothing" {
    export CODE_FAIL=1
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [ "$output" = "vscode-recent-projects: 'code /work/app-configs' failed: code: boom" ]
    [ "$(activations)" -eq 0 ]
    [ ! -s "$LIST_COUNT" ]
}

@test "focuses the code window whose title contains the project name" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(activations)" -eq 1 ]
    grep -qx 'gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows --method org.gnome.Shell.Extensions.Windows.Activate 4' "$CALLS"
    [ "$(sleeps)" -eq 0 ]
}

@test "without a title match, focuses the focused code window" {
    export SELECTED="/work/unlisted"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(activations)" -eq 1 ]
    grep -q '\.Activate 3$' "$CALLS"
}

@test "without a title match or focus, focuses the first code window" {
    export SELECTED="/work/unlisted"
    jq '.[2].has_focus = false' "$WINDOWS" >"$WINDOWS.tmp"
    mv "$WINDOWS.tmp" "$WINDOWS"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(activations)" -eq 1 ]
    grep -q '\.Activate 2$' "$CALLS"
}

@test "a title match in another app's window is ignored" {
    jq 'map(select(.id != 4))' "$WINDOWS" >"$WINDOWS.tmp"
    mv "$WINDOWS.tmp" "$WINDOWS"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(activations)" -eq 1 ]
    grep -q '\.Activate 3$' "$CALLS"
}

@test "polls until the new code window appears, then focuses it" {
    export WINDOWS_AFTER=3
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$LIST_COUNT")" -eq 3 ]
    [ "$(sleeps)" -eq 2 ]
    [ "$(grep -c '^sleep 0.3$' "$CALLS")" -eq 2 ]
    [ "$(activations)" -eq 1 ]
    grep -q '\.Activate 4$' "$CALLS"
}

@test "gives up cleanly after 10 polls when no code window appears" {
    jq 'map(select(.id == 1))' "$WINDOWS" >"$WINDOWS.tmp"
    mv "$WINDOWS.tmp" "$WINDOWS"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$LIST_COUNT")" -eq 10 ]
    [ "$(sleeps)" -eq 10 ]
    [ "$(activations)" -eq 0 ]
}

@test "unavailable D-Bus still exits 0 after 10 polls" {
    export BUS_FAIL=1
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$LIST_COUNT")" -eq 10 ]
    [ "$(sleeps)" -eq 10 ]
    [ "$(activations)" -eq 0 ]
    grep -qx 'code /work/app-configs' "$CALLS"
}

@test "a failed activation still exits 0 and is not retried" {
    export ACTIVATE_FAIL=1
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(activations)" -eq 1 ]
    [ "$(wc -l <"$LIST_COUNT")" -eq 1 ]
}

@test "recent folders come from VS Code's state DB: existing only, de-duplicated, in order" {
    real_python="$(PATH="${PATH#"$STUBS":}" command -v python3)" || skip "python3 not installed"
    rm "$STUBS/python3"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.config/Code/User/globalStorage" "$HOME/proj a" "$HOME/proj-b" "$HOME/ws"
    : >"$HOME/ws/x.code-workspace"
    "$real_python" - "$HOME" <<'PY'
import json, sqlite3, sys, urllib.parse
home = sys.argv[1]
uri = lambda p: "file://" + urllib.parse.quote(p)
entries = [
    {"folderUri": uri(home + "/proj a")},
    {"folderUri": uri(home + "/gone")},
    {"workspace": {"configPath": uri(home + "/ws/x.code-workspace")}},
    {"folderUri": uri(home + "/proj a")},
    {"folderUri": "vscode-remote://ssh/host/x"},
    {"fileUri": uri(home + "/ws/x.code-workspace")},
    {"folderUri": uri(home + "/proj-b")},
]
con = sqlite3.connect(home + "/.config/Code/User/globalStorage/state.vscdb")
con.execute("CREATE TABLE ItemTable (key TEXT, value TEXT)")
con.execute("INSERT INTO ItemTable VALUES (?, ?)",
            ("history.recentlyOpenedPathsList", json.dumps({"entries": entries})))
con.commit()
PY
    export SELECTED=""
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$MENU_INPUT")" = "$HOME/proj a
$HOME/ws/x.code-workspace
$HOME/proj-b" ]
}
