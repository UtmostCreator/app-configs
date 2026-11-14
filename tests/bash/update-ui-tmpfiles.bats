#!/usr/bin/env bats
# ops/lib/update-ui.sh captures each step into a temp file and appends it to
# the run log. Those captures used to pile up in /tmp, one per step per run.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"; mkdir -p "$TMPDIR"
    LOG="$BATS_TEST_TMPDIR/run.log"
    # shellcheck source=ops/lib/update-ui.sh
    source "$REPO_ROOT/ops/lib/update-ui.sh"
    ui_init "$LOG" 0
}

captures() { find "$TMPDIR" -name 'sys-update-step.*' | wc -l; }

@test "a finished step does not leave captures behind (the last one is kept for the caller)" {
    ui_run one echo first
    ui_run two echo second
    ui_run three echo third
    [ "$(captures)" -le 1 ]
    # the caller can still read the capture of the step that just ran
    grep -q third "$UI_LAST_LOG"
}

@test "ui_cleanup removes the last capture too, and the run log keeps everything" {
    ui_run one echo first
    ui_run two echo second
    ui_cleanup
    [ "$(captures)" -eq 0 ]
    grep -q first "$LOG"
    grep -q second "$LOG"
}

@test "a failing step keeps its capture readable for the error report" {
    run ui_run bad bash -c 'echo boom >&2; exit 4'
    [ "$status" -eq 4 ]
    ui_run bad bash -c 'echo boom >&2; exit 4' || true
    grep -q boom "$UI_LAST_LOG"
}
