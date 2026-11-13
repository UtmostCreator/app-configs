#!/usr/bin/env bats
# The ws-* workspace launchers are exposed on every host, but Laravel Herd is
# macOS-only. On Linux/WSL the Herd steps must be skipped with a one-line
# message instead of failing on `open -a Herd` / `herd start`.
#
# uname, open, herd, colima, docker, mise and npm are PATH stubs; HOME is a
# scratch dir holding an empty backend checkout.
#
# Run:  bats tests/bash/projects-workspace-herd.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    WS="$REPO_ROOT/ops/projects/workspace"
    export HOME="$BATS_TEST_TMPDIR/home"
    STUBS="$BATS_TEST_TMPDIR/bin"
    MARKS="$BATS_TEST_TMPDIR/marks"
    mkdir -p "$HOME/Herd/backend" "$STUBS" "$MARKS"

    # Herd is absent on Linux: calling it at all is the bug.
    stub open "touch '$MARKS/open'; exit 127"
    stub herd "touch '$MARKS/herd'; exit 127"
    stub colima 'exit 0'
    stub docker 'case "$*" in
  *"{{.Id}}"*) echo 0123456789abcdef ;;
  *"{{.State.Status}}"*) echo running ;;
esac
exit 0'
    stub mise 'exit 0'
    stub npm 'exit 0'
}

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

run_with_os() {
    local os="$1"; shift
    stub uname "echo $os"
    run env PATH="$STUBS:$PATH" bash "$@"
}

@test "ws-stack start on Linux skips Herd with one message and continues" {
    run_with_os Linux "$WS/stack/start.sh"
    [ "$status" -eq 0 ]
    [ ! -f "$MARKS/open" ]
    [ ! -f "$MARKS/herd" ]
    [ "$(grep -c 'Skipping Herd' <<<"$output")" -eq 1 ]
    [[ "$output" != *"Ensuring Herd"* ]]
    [[ "$output" == *"Skipping Herd"*"macOS-only"* ]]
    [[ "$output" == *"Redis container is running"* ]]
}

@test "workspace start on Linux skips Herd and continues" {
    run_with_os Linux "$WS/start.sh"
    [ "$status" -eq 0 ]
    [ ! -f "$MARKS/herd" ]
    [[ "$output" == *"Skipping Herd"* ]]
    [[ "$output" == *"Redis is running"* ]]
}

@test "ws-stack start on macOS still opens and starts Herd" {
    stub open "touch '$MARKS/open'"
    stub herd "touch '$MARKS/herd'"
    run_with_os Darwin "$WS/stack/start.sh"
    [ "$status" -eq 0 ]
    [ -f "$MARKS/open" ]
    [ -f "$MARKS/herd" ]
    [[ "$output" != *"Skipping Herd"* ]]
}
