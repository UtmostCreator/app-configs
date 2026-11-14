#!/usr/bin/env bats
# ops/uninstall.sh lists the existing snapshots. It used `find -printf`, which
# BSD find (macOS) does not have; with stderr hidden the inventory was just
# empty. A find without -printf stands in for BSD find here.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    export DOTFILES_SNAPSHOT_ROOT="$BATS_TEST_TMPDIR/snaps"
    mkdir -p "$DOTFILES_SNAPSHOT_ROOT/20260102T000000Z" "$DOTFILES_SNAPSHOT_ROOT/20260101T000000Z"
    : >"$DOTFILES_SNAPSHOT_ROOT/not-a-snapshot-dir"

    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    REAL_FIND="$(command -v find)"
    export REAL_FIND
    cat >"$STUBS/find" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
    if [[ "$a" == -printf ]]; then echo "find: unknown primary or operator: -printf" >&2; exit 1; fi
done
exec "$REAL_FIND" "$@"
STUB
    chmod +x "$STUBS/find"
}

@test "the snapshot inventory lists directories without find -printf, oldest first" {
    run env PATH="$STUBS:$PATH" bash "$REPO_ROOT/ops/uninstall.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Existing snapshots"* ]]
    first="$(grep -n '20260101T000000Z' <<<"$output" | head -1 | cut -d: -f1)"
    second="$(grep -n '20260102T000000Z' <<<"$output" | head -1 | cut -d: -f1)"
    [ -n "$first" ]
    [ -n "$second" ]
    [ "$first" -lt "$second" ]
    [[ "$output" != *"not-a-snapshot-dir"* ]]
}

@test "an empty snapshot directory lists nothing and still succeeds" {
    rm -r "$DOTFILES_SNAPSHOT_ROOT"; mkdir "$DOTFILES_SNAPSHOT_ROOT"
    run env PATH="$STUBS:$PATH" bash "$REPO_ROOT/ops/uninstall.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Existing snapshots"* ]]
}
