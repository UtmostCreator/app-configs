#!/usr/bin/env bats
# The applied-state record (T-0043): ops/lib/install-record.sh writes it after a
# successful apply (sys-update) or install, and reads it back as ok, absent,
# invalid or stale. Machine-local, never committed; it holds the sha256 of the
# selection file, never its content.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset XDG_STATE_HOME XDG_CONFIG_HOME
    export APP_CONFIGS_STATE_DIR="$BATS_TEST_TMPDIR/state dir"
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/sel"
    export GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
    REC="$APP_CONFIGS_STATE_DIR/installed.meta"
    GEN="$BATS_TEST_TMPDIR/profiles/home-manager-7-link"
    mkdir -p "$GEN" "$BATS_TEST_TMPDIR/profiles"
    ln -sfn home-manager-7-link "$BATS_TEST_TMPDIR/profiles/home-manager"
    GEN_REAL="$(readlink -f "$GEN")"
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/nix" "$REPO/home"
    printf 'x\n' >"$REPO/nix/a.nix"; printf 'y\n' >"$REPO/home/b"
    git -C "$REPO" init -q
    git -C "$REPO" add -A
    git -C "$REPO" -c user.name=t -c user.email=t@e.t -c commit.gpgsign=false commit -q -m init
    REV="$(git -C "$REPO" rev-parse HEAD)"
}

# rec <function and args>: runs a record function in a fresh shell, like the scripts do.
rec() {
    run bash -c 'source "$1/ops/lib/selection.sh"; source "$1/ops/lib/install-record.sh"; shift; "$@"' _ "$REPO_ROOT" "$@"
}

good_record() { # good_record: a valid record for the generation of the profile link
    mkdir -p "$APP_CONFIGS_STATE_DIR"
    cat >"$REC" <<EOF
schema_version=1
written_by=sys-update
written_at=2026-11-15T10:00:00Z
run_id=20261115T100000Z-42
host=linux-desktop
generation_kind=home-manager
generation=$GEN_REAL
repo_rev=$REV
repo_dirty=no
selection_file=absent
selection_sha256=none
EOF
}

# ── the write ───────────────────────────────────────────────────────────────

@test "write: exact bytes, fixed key order, LF endings, nothing else" {
    INSTALL_RECORD_RUN_ID=20261115T100000Z-42 rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    grep -Eq '^written_at=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$REC"
    sed 's/^written_at=.*/written_at=@NOW@/' "$REC" >"$BATS_TEST_TMPDIR/got"
    printf 'schema_version=1\nwritten_by=sys-update\nwritten_at=@NOW@\nrun_id=20261115T100000Z-42\nhost=linux-desktop\ngeneration_kind=home-manager\ngeneration=%s\nrepo_rev=%s\nrepo_dirty=no\nselection_file=absent\nselection_sha256=none\n' \
        "$GEN_REAL" "$REV" >"$BATS_TEST_TMPDIR/want"
    cmp "$BATS_TEST_TMPDIR/want" "$BATS_TEST_TMPDIR/got"
    run grep -c $'\r' "$REC"
    [ "$output" = 0 ]
    [ "$(wc -l <"$REC")" -eq 11 ]
}

@test "write: run_id is none without a run, written_by install is accepted" {
    rec install_record_write install linux-cli home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    [ "$status" -eq 0 ]
    grep -qx 'run_id=none' "$REC"
    grep -qx 'written_by=install' "$REC"
    rec install_record_read
    [ "$status" -eq 0 ]
}

@test "write: the selection is recorded as its sha256 only, never its content" {
    mkdir -p "$APP_CONFIGS_SELECTION_DIR"
    printf 'profile = "work"\n# SECRETMARK-4711\n' >"$APP_CONFIGS_SELECTION_DIR/selection.toml"
    local want
    want="$(sha256sum <"$APP_CONFIGS_SELECTION_DIR/selection.toml" | cut -d' ' -f1)"
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    [ "$status" -eq 0 ]
    grep -qx 'selection_file=present' "$REC"
    grep -qx "selection_sha256=$want" "$REC"
    run grep -c SECRETMARK "$REC"
    [ "$output" = 0 ]
}

@test "write: a dirty tree under nix or home is repo_dirty=yes, a clean one no, no git is unknown" {
    printf 'changed\n' >>"$REPO/nix/a.nix"
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    grep -qx 'repo_dirty=yes' "$REC"
    git -C "$REPO" checkout -q -- nix/a.nix
    printf 'untracked\n' >"$REPO/notes.txt"
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    grep -qx 'repo_dirty=no' "$REC"
    mkdir -p "$BATS_TEST_TMPDIR/nogit"
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$BATS_TEST_TMPDIR/nogit"
    grep -qx 'repo_rev=unknown' "$REC"
    grep -qx 'repo_dirty=unknown' "$REC"
}

@test "write: atomic: a temp file in the target dir, mv, and nothing left behind; the file is private" {
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    [ "$status" -eq 0 ]
    [ "$(ls -A "$APP_CONFIGS_STATE_DIR")" = installed.meta ]
    [ "$(stat -c %a "$REC")" = 600 ]
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    [ "$(ls -A "$APP_CONFIGS_STATE_DIR")" = installed.meta ]
}

@test "write: a failed write warns, returns non-zero, leaves no temp file and keeps the old record" {
    good_record
    cp "$REC" "$BATS_TEST_TMPDIR/before"
    chmod 500 "$APP_CONFIGS_STATE_DIR"
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    chmod 700 "$APP_CONFIGS_STATE_DIR"
    [ "$status" -ne 0 ]
    [[ "$output" == *"applied-state record"* ]]
    [ "$(ls -A "$APP_CONFIGS_STATE_DIR")" = installed.meta ]
    cmp "$REC" "$BATS_TEST_TMPDIR/before"
}

@test "write: a generation that cannot be resolved writes nothing" {
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/nowhere" "$REPO"
    [ "$status" -ne 0 ]
    [ ! -e "$REC" ]
}

@test "write: a bad writer, host or kind is refused" {
    rec install_record_write nobody linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    [ "$status" -ne 0 ]
    rec install_record_write sys-update linux-desktop spaceship "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    [ "$status" -ne 0 ]
    [ ! -e "$REC" ]
}

@test "write: the default location is XDG_STATE_HOME/app-configs, else HOME/.local/state/app-configs" {
    unset APP_CONFIGS_STATE_DIR
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/xdg"
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    [ -f "$BATS_TEST_TMPDIR/xdg/app-configs/installed.meta" ]
    unset XDG_STATE_HOME
    rec install_record_write sys-update linux-desktop home-manager "$BATS_TEST_TMPDIR/profiles/home-manager" "$REPO"
    [ -f "$HOME/.local/state/app-configs/installed.meta" ]
}

# ── the read ────────────────────────────────────────────────────────────────

@test "read: no file is absent" {
    rec install_record_read "$GEN_REAL"
    [ "$status" -eq 0 ]
    [ "$output" = absent ]
}

@test "read: a valid record for the current generation is ok" {
    good_record
    rec install_record_read "$GEN_REAL"
    [ "$status" -eq 0 ]
    [ "$output" = ok ]
}

@test "read: a record for another generation is stale" {
    good_record
    rec install_record_read "$BATS_TEST_TMPDIR/some-other-generation"
    [ "$output" = stale ]
    rec install_record_read ""
    [ "$output" = stale ]
}

@test "read: the fields are available to the caller after an ok read" {
    good_record
    run bash -c 'source "$1/ops/lib/selection.sh"; source "$1/ops/lib/install-record.sh"; install_record_read "$2" >/dev/null; echo "$IR_WRITTEN_BY $IR_REPO_REV $IR_SELECTION_SHA256 $IR_REPO_DIRTY"' _ "$REPO_ROOT" "$GEN_REAL"
    [ "$output" = "sys-update $REV none no" ]
}

@test "read: each way a record can be invalid" {
    local mutate
    for mutate in \
        's/^schema_version=1/schema_version=2/' \
        's/^repo_rev=.*/repo_rev=abc123/' \
        's/^repo_dirty=no/repo_dirty=maybe/' \
        's/^written_by=.*/written_by=somebody/' \
        's/^written_at=.*/written_at=yesterday/' \
        's/^selection_sha256=none/selection_sha256=nothex/' \
        's/^selection_file=absent/selection_file=present/' \
        's/^generation_kind=.*/generation_kind=other/' \
        's/^generation=.*/generation=relative\/path/' \
        '/^host=/d' \
        '/^run_id=/d' \
        's/^host=.*/&\nextra=1/' \
        's/^host=.*/&\nhost=again/' \
        's/$/\r/' \
        '1{h;d};2{G}'; do
        good_record
        sed -i -e "$mutate" "$REC"
        rec install_record_read "$GEN_REAL"
        [ "$output" = invalid ] || { echo "mutation $mutate gave: $output"; return 1; }
    done
}

@test "read: an empty file and a directory in its place are invalid" {
    mkdir -p "$APP_CONFIGS_STATE_DIR"
    : >"$REC"
    rec install_record_read "$GEN_REAL"
    [ "$output" = invalid ]
    rm "$REC"; mkdir "$REC"
    rec install_record_read "$GEN_REAL"
    [ "$output" = invalid ]
}

@test "read: never writes: the record and its directory are unchanged" {
    good_record
    local before after
    before="$(cd "$APP_CONFIGS_STATE_DIR" && ls -la --time-style=+ . && sha256sum installed.meta)"
    rec install_record_read "$GEN_REAL"
    after="$(cd "$APP_CONFIGS_STATE_DIR" && ls -la --time-style=+ . && sha256sum installed.meta)"
    [ "$before" = "$after" ]
}

# ── portability and guards ──────────────────────────────────────────────────

@test "install-record.sh uses no bash 4 features, reads no input and sources cleanly with mapfile disabled" {
    local f="$REPO_ROOT/ops/lib/install-record.sh"
    run grep -nE '(^|[^[:alnum:]_])read[[:space:]]' "$f"
    [ "$status" -ne 0 ]
    run grep -nE '(declare|local|typeset) +-[A-Za-z]*[An]|(^|[^[:alnum:]_])(mapfile|readarray)([^[:alnum:]_]|$)' "$f"
    [ "$status" -ne 0 ]
    run grep -nE '\$\{[A-Za-z_]+(,,|\^\^)|&>>|\|&' "$f"
    [ "$status" -ne 0 ]
    run env -i PATH="$PATH" HOME="$HOME" APP_CONFIGS_STATE_DIR="$APP_CONFIGS_STATE_DIR" bash -c '
        enable -n mapfile readarray
        set -euo pipefail
        source "$1/ops/lib/selection.sh"
        source "$1/ops/lib/install-record.sh"
        install_record_write install linux-cli home-manager "$2/profiles/home-manager" "$3"
        install_record_read "$4"' _ "$REPO_ROOT" "$BATS_TEST_TMPDIR" "$REPO" "$GEN_REAL"
    [ "$status" -eq 0 ]
    [ "$output" = ok ]
}
