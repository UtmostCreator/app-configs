#!/usr/bin/env bats
# home/dot_local/bin/executable_clipcopy picks the right clipboard backend.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_clipcopy"
    STUBS="$BATS_TEST_TMPDIR/bin"
    OUT="$BATS_TEST_TMPDIR/out"
    mkdir -p "$STUBS"
    # Core tools only; no clipboard commands unless a test adds a stub.
    for t in sh cat iconv od; do ln -s "$(command -v "$t")" "$STUBS/$t"; done
    unset WSL_DISTRO_NAME WSL_INTEROP WAYLAND_DISPLAY DISPLAY
}

stub() { # stub <name>: records its stdin to $OUT.<name>
    printf '#!/bin/sh\ncat >"%s.%s"\n' "$OUT" "$1" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

copy() { printf '%s' "$1" | PATH="$STUBS" "$STUBS/sh" "$SCRIPT"; }

@test "macOS uses pbcopy" {
    stub pbcopy; stub wl-copy
    WAYLAND_DISPLAY=wayland-0 copy "hello"
    [ "$(cat "$OUT.pbcopy")" = "hello" ]
    [ ! -e "$OUT.wl-copy" ]
}

@test "WSL uses clip.exe with UTF-16LE so non-ASCII text survives" {
    stub clip.exe; stub wl-copy
    WSL_DISTRO_NAME=Ubuntu WAYLAND_DISPLAY=wayland-0 copy "é"
    [ ! -e "$OUT.wl-copy" ]
    [ "$(od -An -tx1 "$OUT.clip.exe" | tr -d ' \n')" = "e900" ]
}

@test "Wayland uses wl-copy" {
    stub wl-copy; stub xclip
    WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 copy "hi"
    [ "$(cat "$OUT.wl-copy")" = "hi" ]
    [ ! -e "$OUT.xclip" ]
}

@test "X11 uses xclip" {
    stub xclip
    DISPLAY=:0 copy "hi"
    [ "$(cat "$OUT.xclip")" = "hi" ]
}

@test "no backend fails with a message" {
    run copy "hi"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no clipboard backend"* ]]
}
