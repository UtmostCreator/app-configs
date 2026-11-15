#!/usr/bin/env bats
# sys-update --selection-diff (T-0043): the read-only comparison of what the
# next `sys-update --apply` would change. Every test runs a scratch copy of
# ops/update-all.sh and the libraries with nix, nix-store, chezmoi, brew and a
# logging git shim from fixtures/selection/stubs, answering from the TSV states
# in fixtures/selection/state (the real flake is never evaluated here). The PATH
# holds only the stubs and a few symlinked system tools. Exit codes under test:
# 0 in sync, 1 execution failure, 2 usage, 10 changes pending, 11 manual action
# required; precedence 1 > 11 > 10 > 0.

bats_require_minimum_version 1.5.0

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIXD="$BATS_TEST_DIRNAME/fixtures/selection"
    UNAME=utmostcreator
    HOME_T="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME_T"
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/sel"
    unset XDG_CONFIG_HOME WSL_DISTRO_NAME NIX_CONFIG STUB_NIX_FAIL_OVERRIDE STUB_NIX_EVAL_FAIL STUB_NIX_STORE_FAIL \
        STUB_CHEZMOI_STATUS STUB_CHEZMOI_STATUS_FAIL STUB_BREW_CASKS STUB_BREW_FAIL STUB_REFS_FILE NO_CLEANUP
    export XDG_STATE_HOME="$HOME_T/.local/state"
    export DETECT_HOST_WSL_RUN="$BATS_TEST_TMPDIR/no-wsl-run" DETECT_HOST_WSL_INTEROP="$BATS_TEST_TMPDIR/no-wsl-interop"
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"; mkdir -p "$TMPDIR"
    export GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
    export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"; : >"$STUB_LOG"
    export STUB_STATE_DIR="$FIXD/state"
    STATE="$BATS_TEST_TMPDIR/sysupdate-state"   # SYS_UPDATE_STATE_DIR: absent unless a test makes it
    RECDIR="$BATS_TEST_TMPDIR/app-state"        # APP_CONFIGS_STATE_DIR: absent unless a test makes it
    REAL_GIT="$(command -v git)"
    HOLD_PID=""
    STUBS="$BATS_TEST_TMPDIR/bin"; SYSBIN="$BATS_TEST_TMPDIR/sysbin"
    mkdir -p "$STUBS" "$SYSBIN"
    local t p
    for t in bash env git sed awk cat dirname head tail find xargs stat sort grep \
        uname mkdir tr rm cp mv chmod ls readlink basename sleep date wc cut id comm \
        mktemp ln timeout sh touch diff sha256sum tty seq flock mkfifo ps fish; do
        p="$(command -v "$t" 2>/dev/null)" || continue
        if [ -x "$p" ]; then ln -sf "$p" "$SYSBIN/$t"; fi
    done
    rm -f "$SYSBIN/git"
    TPATH="$STUBS:$SYSBIN"
    make_fake
}

teardown() {
    if [ -n "$HOLD_PID" ]; then kill "$HOLD_PID" 2>/dev/null || true; fi
}

# make_fake: a scratch repo with update-all.sh, the libraries, the profile files
# and stub tools. .git is an empty directory (the repo revision is unknown)
# until a test calls real_git.
make_fake() {
    FAKE="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FAKE/ops" "$FAKE/nix/vars" "$FAKE/nix/profiles" "$FAKE/home/.chezmoidata" "$FAKE/.git"
    cp "$REPO_ROOT/ops/update-all.sh" "$REPO_ROOT/ops/update-version-report.sh" "$REPO_ROOT/ops/detect-host.sh" "$FAKE/ops/"
    cp -R "$REPO_ROOT/ops/lib" "$FAKE/ops/lib"
    cp "$REPO_ROOT"/nix/profiles/*.toml "$FAKE/nix/profiles/"
    cp "$REPO_ROOT/nix/flake.lock" "$FAKE/nix/flake.lock"
    cp "$REPO_ROOT/.chezmoiroot" "$FAKE/"
    printf '{\n  username = "%s";\n}\n' "$UNAME" >"$FAKE/nix/vars/default.nix"
    # Deterministic generated machine-local data with dummy values: the fake repo
    # is an isolated test context and must never borrow the real checkout's file.
    printf 'name: Test User\nemail: test@example.invalid\n' >"$FAKE/home/.chezmoidata/personal.yaml"
    local s
    for s in nix nix-store chezmoi git; do
        cp "$FIXD/stubs/$s" "$STUBS/$s"; chmod +x "$STUBS/$s"
    done
    for s in home-manager darwin-rebuild mise lefthook; do
        printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >>"$STUB_LOG"\nexit 0\n' "$s" >"$STUBS/$s"
        chmod +x "$STUBS/$s"
    done
}

# real_git: turn the scratch repo into a real git repository with one commit.
real_git() {
    rm -rf "$FAKE/.git"
    "$REAL_GIT" -C "$FAKE" init -q
    "$REAL_GIT" -C "$FAKE" add -A
    "$REAL_GIT" -C "$FAKE" -c user.name=t -c user.email=t@e.t -c commit.gpgsign=false commit -q -m init
}

with_brew() { cp "$FIXD/stubs/brew" "$STUBS/brew"; chmod +x "$STUBS/brew"; }

# install_gen <state>: a fake current Home Manager generation that holds what the
# state fixture holds (packages through STUB_REFS_FILE, files as symlinks).
install_gen() {
    local profiles="$XDG_STATE_HOME/nix/profiles" gen k a b
    gen="$profiles/home-manager-1-link"
    mkdir -p "$gen/home-path" "$gen/home-files"
    ln -sfn home-manager-1-link "$profiles/home-manager"
    while IFS=$'\t' read -r k a b; do
        if [ "$k" = F ]; then
            mkdir -p "$gen/home-files/$(dirname "$a")"
            ln -sfn "$b" "$gen/home-files/$a"
        fi
    done <"$FIXD/state/$1.tsv"
    export STUB_REFS_FILE="$BATS_TEST_TMPDIR/refs"
    awk -F'\t' '$1 == "K" { print $2 }' "$FIXD/state/$1.tsv" | grep -v dummy-xdg >"$STUB_REFS_FILE"
}

write_sel() {
    mkdir -p "$APP_CONFIGS_SELECTION_DIR"
    printf '%b' "$1" >"$APP_CONFIGS_SELECTION_DIR/selection.toml"
}

# chz <text>: what `chezmoi status` prints (printf %b).
chz() { printf '%b' "$1" >"$BATS_TEST_TMPDIR/chezmoi-status"; export STUB_CHEZMOI_STATUS="$BATS_TEST_TMPDIR/chezmoi-status"; }

# sd <args>: update-all.sh with stdout and stderr kept apart.
sd() {
    run --separate-stderr env HOME="$HOME_T" PATH="$TPATH" HOST_PROFILE="${HP:-linux-desktop}" USER="$UNAME" \
        SYS_UPDATE_STATE_DIR="$STATE" APP_CONFIGS_STATE_DIR="$RECDIR" REAL_GIT="$REAL_GIT" \
        timeout 120 bash "$FAKE/ops/update-all.sh" "$@" </dev/null
}

# tree_sum <dir>: sha256 of every file and symlink target below it, sorted.
tree_sum() {
    [ -e "$1" ] || { echo "absent: $1"; return 0; }
    (cd "$1" && find . \( -type f -o -type l \) | LC_ALL=C sort | while IFS= read -r f; do
        if [ -L "$f" ]; then printf 'link %s -> %s\n' "$f" "$(readlink "$f")"; else sha256sum "$f"; fi
    done)
}

section() { printf '%s\n' "$output" | awk -v h="$1" 'f && /^[^ ]/ { exit } index($0, h) == 1 { f = 1 } f'; }
line_of() { printf '%s\n' "$output" | grep -n "$1" | head -n1 | cut -d: -f1; }
refute_log() {
    if grep -Eq "$1" "$STUB_LOG"; then grep -E "$1" "$STUB_LOG"; return 1; fi
}

# ── the exit matrix ─────────────────────────────────────────────────────────

@test "in sync: exit 0, RESULT: IN SYNC, nothing listed as pending" {
    install_gen committed
    sd --selection-diff
    [ "$status" -eq 0 ]
    [[ "$output" == *"read-only: nothing is built, written or applied"* ]]
    [[ "$output" == *"RESULT: IN SYNC"* ]]
    [[ "$output" != *"REMOVE ("* && "$output" != *"ADD ("* && "$output" != *"CHANGE ("* ]]
}

@test "a package the selection adds: exit 10, ADD lists it" {
    install_gen work-nomedia
    write_sel 'profile = "work"\n'
    sd --selection-diff
    [ "$status" -eq 10 ]
    [[ "$output" == *"RESULT: CHANGES PENDING"* ]]
    [[ "$output" == *"ADD (4)"* ]]
    [[ "$output" == *"ffmpeg"* ]]
}

@test "a package the selection removes: exit 10, REMOVE comes before ADD and CHANGE" {
    install_gen work
    chz ' A .config/new\n'
    write_sel 'profile = "work"\n\n[groups]\nmedia = false\n'
    sd --selection-diff
    [ "$status" -eq 10 ]
    [[ "$output" == *"REMOVE (4): the next sys-update --apply would remove"* ]]
    [[ "$output" == *"ffmpeg"* ]]
    [ "$(line_of '^REMOVE (')" -lt "$(line_of '^ADD (')" ]
}

@test "a changed package version: exit 10, CHANGE lists it with both versions" {
    install_gen work
    sed -i 's/ffmpeg-7.0.1/ffmpeg-7.0.0/' "$STUB_REFS_FILE"
    write_sel 'profile = "work"\n'
    sd --selection-diff
    [ "$status" -eq 10 ]
    [[ "$output" == *"CHANGE (1)"* ]]
    [[ "$output" == *"ffmpeg"*"7.0.0"*"7.0.1"* ]]
}

@test "a Home Manager file link that differs is a change, a missing one an add" {
    install_gen work
    ln -sfn /nix/store/00000000000000000000000000000000-other "$XDG_STATE_HOME/nix/profiles/home-manager-1-link/home-files/.config/mimeapps.list"
    rm "$XDG_STATE_HOME/nix/profiles/home-manager-1-link/home-files/.config/systemd/user/nix-gc.timer"
    write_sel 'profile = "work"\n'
    sd --selection-diff
    [ "$status" -eq 10 ]
    [[ "$output" == *".config/mimeapps.list"* ]]
    [[ "$output" == *".config/systemd/user/nix-gc.timer"* ]]
    [[ "$output" == *"unit"* ]]
}

@test "chezmoi edited here and in the repo (MM): a conflict, exit 11" {
    install_gen committed
    chz 'MM .zshrc\n'
    sd --selection-diff
    [ "$status" -eq 11 ]
    [[ "$output" == *"CONFLICT (1)"* ]]
    [[ "$output" == *".zshrc"* ]]
    [[ "$output" == *"RESULT: ACTION REQUIRED"* ]]
    sd --selection-diff --json
    [ "$status" -eq 11 ]
    [[ "$output" == *'"chezmoi": {"status": "pending", "reason": "conflicts_present"}'* ]]
}

@test "a conflict together with an add is still 11" {
    install_gen work-nomedia
    write_sel 'profile = "work"\n'
    chz 'MM .zshrc\n'
    sd --selection-diff
    [ "$status" -eq 11 ]
    [[ "$output" == *"CONFLICT (1)"* && "$output" == *"ADD (4)"* ]]
}

@test "chezmoi: add, change, remove and script rows are counted; a local-only change is a keep" {
    install_gen committed
    chz ' A a\n M b\n D c\n R s\nM  keepme\n'
    sd --selection-diff --json
    [ "$status" -eq 10 ]
    [[ "$output" == *'"counts": {"add": 1, "remove": 1, "change": 2,'* ]]
    [[ "$output" != *'"name": "keepme"'* ]]
    [[ "$output" == *'"keep": '* ]]
}

@test "the installed generation cannot be read: exit 11, unknown, never a zero keep" {
    install_gen committed
    export STUB_NIX_STORE_FAIL=1
    sd --selection-diff
    [ "$status" -eq 11 ]
    [[ "$output" == *"UNKNOWN ("* ]]
    [[ "$output" == *"Packages: unknown — "* ]]
    [[ "$output" == *"assessment incomplete"* ]]
    [[ "$output" != *"Packages: keep"* ]]
    sd --selection-diff --json
    [[ "$output" == *'"installed": {"state": "unknown"'* ]]
    [[ "$output" == *'"packages": {"status": "unknown", "reason": "generation_unreadable"}'* ]]
    [[ "$output" == *'"hm_files": {"status": "unknown", "reason": "generation_unreadable"}'* ]]
    [[ "$output" == *'"keep": 0'* ]]
}

@test "chezmoi status fails: exit 11 with the source unknown" {
    install_gen committed
    export STUB_CHEZMOI_STATUS_FAIL="timeout obtaining persistent state lock"
    sd --selection-diff
    [ "$status" -eq 11 ]
    [[ "$output" == *"ERROR (1)"* ]]
    [[ "$output" == *"persistent state lock"* ]]
}

@test "macOS: brew fails: exit 11, the cask source is unknown" {
    HP=macos; with_brew
    install_gen mac-committed
    export STUB_BREW_FAIL=1
    sd --selection-diff
    [ "$status" -eq 11 ]
    [[ "$output" == *"ERROR (1)"* && "$output" == *"cask"* ]]
}

@test "macOS: a deselected cask that stays installed is MANUAL and does not count towards the exit code" {
    HP=macos; with_brew
    install_gen mac-committed
    printf 'rectangle\nkarabiner-elements\nlinearmouse\nraycast\n' >"$BATS_TEST_TMPDIR/casks"
    export STUB_BREW_CASKS="$BATS_TEST_TMPDIR/casks"
    write_sel 'profile = "work"\n\n[groups]\nmacInput = false\n'
    sd --selection-diff
    [ "$status" -eq 0 ]
    [[ "$output" == *"MANUAL (2)"* ]]
    [[ "$output" == *"brew uninstall --cask karabiner-elements"* ]]
    [[ "$output" == *"brew uninstall --cask linearmouse"* ]]
    [[ "$output" == *"RESULT: IN SYNC"* ]]
}

@test "macOS: a missing cask is an add (exit 10) next to the manual ones" {
    HP=macos; with_brew
    install_gen mac-committed
    printf 'rectangle\nkarabiner-elements\nlinearmouse\n' >"$BATS_TEST_TMPDIR/casks"
    export STUB_BREW_CASKS="$BATS_TEST_TMPDIR/casks"
    write_sel 'profile = "work"\n\n[groups]\nmacInput = false\n'
    sd --selection-diff
    [ "$status" -eq 10 ]
    [[ "$output" == *"ADD (1)"* && "$output" == *"raycast"* ]]
    [[ "$output" == *"MANUAL (2)"* ]]
}

@test "the declared state does not evaluate: exit 1, the Nix error on stderr, nothing on stdout" {
    install_gen committed
    export STUB_NIX_EVAL_FAIL=1
    sd --selection-diff
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"stub: evaluation failure"* ]]
    [ -z "$output" ]
}

@test "an evaluation failure wins over a conflict and over pending changes (1 > 11 > 10)" {
    install_gen work-nomedia
    write_sel 'profile = "work"\n'
    chz 'MM .zshrc\n'
    export STUB_NIX_EVAL_FAIL=1
    sd --selection-diff
    [ "$status" -eq 1 ]
}

@test "an invalid selection file is an evaluation failure: exit 1, no lenient fallback" {
    install_gen committed
    write_sel 'bogus = 1\n'
    sd --selection-diff
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"unknown key 'bogus'"* ]]
}

@test "nix missing: exit 1 with a clear message" {
    install_gen committed
    rm "$STUBS/nix"
    sd --selection-diff
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"nix"* ]]
}

# ── arguments ───────────────────────────────────────────────────────────────

@test "--apply never turns the diff into an apply, in either argument order, and creates no lock or state" {
    install_gen committed
    sd --apply --selection-diff
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESULT: IN SYNC"* ]]
    sd --selection-diff --apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESULT: IN SYNC"* ]]
    [ ! -e "$STATE" ]
    [ ! -e "$RECDIR" ]
    refute_log '^(home-manager|darwin-rebuild)|^chezmoi( --source=[^ ]+)? apply( |$)'
}

@test "--yes, --no-pull and --verbose are accepted and ignored" {
    install_gen committed
    sd --selection-diff --yes --no-pull --verbose
    [ "$status" -eq 0 ]
    sd -y -v --selection-diff
    [ "$status" -eq 0 ]
}

@test "usage: --json alone, and rollback, --force, --gc, --allow-dirty, --skip-verify, --full-check, --no-cleanup with --selection-diff exit 2" {
    install_gen committed
    local a
    sd --json
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"--json"* ]]
    for a in rollback --force --gc --allow-dirty --skip-verify --full-check --no-cleanup; do
        sd --selection-diff "$a"
        [ "$status" -eq 2 ] || { echo "$a: $status"; return 1; }
        [[ "$stderr" == *"$a"* ]] || { echo "$a: $stderr"; return 1; }
        [ -z "$output" ]
    done
    [ ! -s "$STUB_LOG" ]
}

@test "--help documents the flags and the exit codes 10 and 11; the header comment does too" {
    sd --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--selection-diff"* && "$output" == *"--json"* ]]
    printf '%s\n' "$output" | grep -Eq '^ *10 +changes pending'
    printf '%s\n' "$output" | grep -Eq '^ *11 +action required'
    head -n 80 "$REPO_ROOT/ops/update-all.sh" | grep -Eq '^# +10 +changes pending'
}

# ── read-only, lock-free, prompt-free ───────────────────────────────────────

@test "read-only: the repo, .git, the state, selection and record dirs are byte-identical and nothing is left behind" {
    real_git
    install_gen work
    write_sel 'profile = "work"\n\n[groups]\nmedia = false\n'
    chz ' A .config/new\n'
    mkdir -p "$STATE/runs" "$RECDIR"
    printf '%s\n' "$STATE/runs/r1.meta" >"$STATE/last-run"
    printf 'run_id=r1\nstatus=done\nexit_code=0\n' >"$STATE/runs/r1.meta"
    printf 'schema_version=9\n' >"$RECDIR/installed.meta"
    local before after
    before="$(tree_sum "$FAKE"; tree_sum "$STATE"; tree_sum "$APP_CONFIGS_SELECTION_DIR"; tree_sum "$RECDIR")"
    sd --selection-diff
    [ "$status" -eq 10 ]
    sd --selection-diff --json
    [ "$status" -eq 10 ]
    after="$(tree_sum "$FAKE"; tree_sum "$STATE"; tree_sum "$APP_CONFIGS_SELECTION_DIR"; tree_sum "$RECDIR")"
    [ "$before" = "$after" ]
    [ -z "$(find "$FAKE" "$BATS_TEST_TMPDIR" -maxdepth 2 -name 'result*' -type l)" ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "read-only: no state, record or selection directory is created when none existed" {
    install_gen committed
    sd --selection-diff
    [ "$status" -eq 0 ]
    [ ! -e "$STATE" ]
    [ ! -e "$RECDIR" ]
    [ ! -e "$APP_CONFIGS_SELECTION_DIR" ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "the stub log shows evaluation and status only: no build, switch, apply, commit, pull or install" {
    real_git
    HP=macos; with_brew
    install_gen mac-committed
    printf 'rectangle\nkarabiner-elements\nlinearmouse\n' >"$BATS_TEST_TMPDIR/casks"
    export STUB_BREW_CASKS="$BATS_TEST_TMPDIR/casks"
    sd --selection-diff
    [ "$status" -eq 0 ]
    grep -q '^nix eval ' "$STUB_LOG"
    grep -q '^chezmoi .* status' "$STUB_LOG"
    refute_log '^nix (build|run|profile|store|flake update|copy)'
    refute_log '^nix-store .*(--realise|-r )'
    refute_log '^(home-manager|darwin-rebuild|mise|lefthook)'
    refute_log '^chezmoi( --source=[^ ]+)? (apply|init|update|add|forget)( |$)'
    refute_log '^git( --no-optional-locks)?( -C [^ ]+)? (commit|pull|fetch|push|merge|checkout|reset|add|stash)( |$)'
    refute_log '^brew (install|uninstall|upgrade|update|cleanup)'
    # the lock file is never written, so every eval carries the flag
    ! grep '^nix eval ' "$STUB_LOG" | grep -vq -- '--no-write-lock-file'
}

@test "it never takes, waits for or probes the lock: a held sys-update lock does not block it" {
    install_gen committed
    mkdir -p "$STATE"
    bash -c 'exec 9>"$1"; flock -x 9; exec sleep 100' _ "$STATE/lock" &
    HOLD_PID=$!
    local i
    for i in $(seq 1 50); do
        if ! flock -n "$STATE/lock" true 2>/dev/null; then break; fi
        sleep 0.1
    done
    run flock -n "$STATE/lock" true
    [ "$status" -ne 0 ]
    sd --selection-diff
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESULT: IN SYNC"* ]]
    kill -0 "$HOLD_PID"
    [ ! -e "$STATE/lock.d" ]
}

@test "it never prompts: a stdin that nobody writes to is not read" {
    install_gen committed
    mkfifo "$BATS_TEST_TMPDIR/fifo"
    run --separate-stderr env HOME="$HOME_T" PATH="$TPATH" HOST_PROFILE=linux-desktop USER="$UNAME" \
        SYS_UPDATE_STATE_DIR="$STATE" REAL_GIT="$REAL_GIT" \
        timeout 60 bash "$FAKE/ops/update-all.sh" --apply --selection-diff <>"$BATS_TEST_TMPDIR/fifo"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESULT: IN SYNC"* ]]
}

# ── the last run ────────────────────────────────────────────────────────────

last_run() { # last_run <meta text>
    mkdir -p "$STATE/runs"
    printf '%s\n' "$STATE/runs/r1.meta" >"$STATE/last-run"
    printf '%b' "$1" >"$STATE/runs/r1.meta"
}

@test "an unfinished last run (no exit code) is manual action required and its record is untouched" {
    install_gen committed
    last_run 'run_id=r1\nstatus=activating\n'
    local before
    before="$(tree_sum "$STATE")"
    sd --selection-diff
    [ "$status" -eq 11 ]
    [[ "$output" == *"MANUAL ("* ]]
    [[ "$output" == *"r1"* && "$output" == *"no exit code"* ]]
    [ "$before" = "$(tree_sum "$STATE")" ]
}

@test "a last run that failed in activate is manual action required and says so" {
    install_gen committed
    last_run 'run_id=r1\nstatus=failed:activate\nexit_code=1\n'
    sd --selection-diff
    [ "$status" -eq 11 ]
    [[ "$output" == *"failed:activate"* ]]
    [[ "$output" == *"sys-update rollback"* ]]
}

@test "a finished, successful last run does not matter" {
    install_gen committed
    last_run 'run_id=r1\nstatus=done\nexit_code=0\n'
    sd --selection-diff
    [ "$status" -eq 0 ]
}

# ── output shape ────────────────────────────────────────────────────────────

@test "a section lists 30 entries and then says how many more, with the full count in the header" {
    install_gen committed
    local i text=""
    for i in $(seq 1 45); do text+=" A f$i\n"; done
    chz "$text"
    sd --selection-diff
    [ "$status" -eq 10 ]
    [[ "$output" == *"ADD (45)"* ]]
    [[ "$output" == *"and 15 more"* ]]
    [ "$(section 'ADD (' | grep -c 'chezmoi')" -eq 30 ]
}

@test "the header names the selected profile and where each value comes from" {
    install_gen work
    write_sel 'profile = "work"\n\n[groups]\nmedia = false\n'
    sd --selection-diff
    [[ "$output" == *"Selected:"* ]]
    [[ "$output" == *"profile work (local)"* ]]
    [[ "$output" == *"media=off (local)"* ]]
    [[ "$output" == *"go=on (profile)"* ]]
    [[ "$output" == *"Record:"*"absent"* ]]
    [[ "$output" == *"Limitations"* ]]
}

@test "a group key that this host does not have is listed as unsupported" {
    install_gen work
    write_sel 'profile = "work"\n\n[groups]\nmacInput = false\n'
    sd --selection-diff
    [[ "$output" == *"UNSUPPORTED (1)"* && "$output" == *"macInput"* ]]
}

# ── --json ──────────────────────────────────────────────────────────────────

@test "--json: stdout is exactly the golden envelope, for a path with a space, a quote and a backslash" {
    install_gen work
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/sel dir \"q\" back\\slash"
    write_sel 'profile = "work"\n\n[groups]\nmedia = false\n'
    chz ' M .config/foo\n A .config/new\nM  .zprofile\n'
    sd --selection-diff --json
    [ "$status" -eq 10 ]
    printf '%s\n' "${output//"$BATS_TEST_TMPDIR"/@TMP@}" >"$BATS_TEST_TMPDIR/actual.json"
    diff "$BATS_TEST_DIRNAME/fixtures/selection-diff/expected.json" "$BATS_TEST_TMPDIR/actual.json"
}

@test "--json: stdout holds only JSON, diagnostics go to stderr, and it parses" {
    command -v python3 >/dev/null || skip "python3 not installed"
    install_gen work
    write_sel 'profile = "work"\n\n[groups]\nmedia = false\n'
    sd --selection-diff --json
    [ "$status" -eq 10 ]
    [[ "$stderr" == *"evaluating"* ]]
    [[ "$output" == "{"* && "$output" == *"}" ]]
    printf '%s' "$output" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert d["exit_code"]==10 and d["outcome"]=="changes-pending" and d["applied"] is False and d["check"] is True'
}

@test "--json: a control character in a name is escaped and the envelope still parses" {
    command -v python3 >/dev/null || skip "python3 not installed"
    install_gen committed
    chz ' A a\x01b\x1fc"d\\e\n'
    sd --selection-diff --json
    [ "$status" -eq 10 ]
    [[ "$output" == *'a\u0001b\u001fc\"d\\e'* ]]
    printf '%s' "$output" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert d["entries"][0]["name"] == "a\x01b\x1fc\"d\\e", d["entries"][0]["name"]'
}

@test "--json: key order is stable and entries are sorted" {
    install_gen work
    write_sel 'profile = "work"\n\n[groups]\nmedia = false\n'
    chz ' A z\n A a\n'
    sd --selection-diff --json
    local keys
    keys="$(printf '%s\n' "$output" | grep -oE '^  "[a-z_]+"' | tr -d ' "' | tr '\n' ' ')"
    [ "$keys" = "schema_version command check applied outcome exit_code host repo selection applied_selection installed record causes complete checks counts entries limitations notes " ]
    [ "$(printf '%s\n' "$output" | grep -o '"name": "[^"]*"' | head -n2 | tr '\n' ' ')" = '"name": "a" "name": "z" ' ]
}

@test "--json: unchanged items appear only as counts" {
    install_gen committed
    sd --selection-diff --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"entries": []'* ]]
    [[ "$output" == *'"outcome": "in-sync"'* ]]
    [[ "$output" == *'"keep": '[1-9]* ]]
}

@test "--json: unknown sources are entries, not zero counts" {
    install_gen committed
    export STUB_NIX_STORE_FAIL=1
    sd --selection-diff --json
    [ "$status" -eq 11 ]
    [[ "$output" == *'"outcome": "action-required"'* ]]
    [[ "$output" == *'"operation": "unknown"'* ]]
    [[ "$output" == *'"unknown": 2'* ]]
}

# ── fail closed, tab-safe, failed envelope ──────────────────────────────────

@test "fail closed: a classifier that fails is exit 1, never a quiet in sync" {
    install_gen committed
    local real_awk
    real_awk="$(command -v awk)"
    rm -f "$STUBS/awk" "$SYSBIN/awk"
    printf '#!/bin/sh\ncase "$*" in *"chezmoi apply creates it"*) echo "awk: forced failure" >&2; exit 2 ;; esac\nexec %s "$@"\n' "$real_awk" >"$SYSBIN/awk"
    chmod +x "$SYSBIN/awk"
    sd --selection-diff
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [[ "$stderr" == *"internal error"* ]]
}

@test "an unknown source forces 11 by itself, and a failed unknown-entry append is a failure, never a quiet 0" {
    run bash -c '
        source "$1/ops/lib/selection.sh"; source "$1/ops/lib/selection-facts.sh"; source "$1/ops/lib/selection-diff.sh"
        w="$2/w"; mkdir -p "$w"; : >"$w/entries.sorted.tsv"
        SELECTION_WORK="$w"; SD_RECORD_STATE=ok
        for c in packages hm_files casks run; do _sd_check $c in_sync; done; _sd_check chezmoi unknown machine_data_missing
        selection_diff_outcome; echo "outcome=$SD_OUTCOME exit=$SD_EXIT"
        mkdir "$w/entries.tsv"
        _sd_unknown_entry chezmoi x 2>/dev/null; echo "append=$?"' _ "$REPO_ROOT" "$BATS_TEST_TMPDIR"
    [[ "$output" == *"outcome=action-required exit=11"* ]]
    [[ "$output" == *"append=1"* ]]
}

@test "a tab in a path never breaks the JSON: it is shown as \\t and by_apply stays true" {
    command -v python3 >/dev/null || skip "python3 not installed"
    install_gen committed
    chz ' A a\tb\n'
    sd --selection-diff --json
    [ "$status" -eq 10 ]
    printf '%s' "$output" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); e=d["entries"][0]; assert e["name"] == "a\\tb" and e["by_apply"] is True and e["operation"] == "add", e'
}

@test "--json: an early failure prints a minimal failed envelope, and the human output stays empty" {
    command -v python3 >/dev/null || skip "python3 not installed"
    install_gen committed
    export STUB_NIX_EVAL_FAIL=1
    sd --selection-diff --json
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"stub: evaluation failure"* ]]
    printf '%s' "$output" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert d == {"schema_version": 1, "command": "selection-diff", "check": True, "applied": False, "outcome": "failed", "exit_code": 1, "error": d["error"]} and d["error"], d'
    sd --selection-diff
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

# ── per-check states and machine-local data ─────────────────────────────────

@test "machine data missing: chezmoi is unknown with a structured reason, the rest stays verified, exit 11, chezmoi never runs" {
    install_gen committed
    rm "$FAKE/home/.chezmoidata/personal.yaml"
    sd --selection-diff --json
    [ "$status" -eq 11 ]
    [[ "$output" == *'"complete": false'* ]]
    [[ "$output" == *'"chezmoi": {"status": "unknown", "reason": "machine_data_missing", "required": ["home/.chezmoidata/personal.yaml"]}'* ]]
    [[ "$output" == *'"packages": {"status": "in_sync"}'* ]]
    [[ "$output" == *'"hm_files": {"status": "in_sync"}'* ]]
    [[ "$output" == *'"keep": '[1-9]* ]]
    [[ "$output" == *'"outcome": "action-required"'* ]]
    refute_log '^chezmoi '
    sd --selection-diff
    [ "$status" -eq 11 ]
    [[ "$output" == *"chezmoi: unknown — machine-local data missing (home/.chezmoidata/personal.yaml); "*" other items in sync; assessment incomplete"* ]]
    [[ "$output" == *"RESULT: ACTION REQUIRED (exit 11): assessment incomplete"* ]]
}

@test "machine data unreadable: unknown with reason machine_data_unreadable" {
    install_gen committed
    chmod 000 "$FAKE/home/.chezmoidata/personal.yaml"
    sd --selection-diff --json
    chmod 600 "$FAKE/home/.chezmoidata/personal.yaml"
    [ "$status" -eq 11 ]
    [[ "$output" == *'"chezmoi": {"status": "unknown", "reason": "machine_data_unreadable", "required": ["home/.chezmoidata/personal.yaml"]}'* ]]
    refute_log '^chezmoi '
}

@test "machine data empty or malformed (chezmoi fails): error chezmoi_failed with a fixed class, never the raw message" {
    install_gen committed
    : >"$FAKE/home/.chezmoidata/personal.yaml"
    export STUB_CHEZMOI_STATUS_FAIL='template: .chezmoiignore:25:44: map has no entry for key "x"; value PRIVATE-CANARY-7'
    sd --selection-diff --json
    [ "$status" -eq 11 ]
    [[ "$output" == *'"chezmoi": {"status": "error", "reason": "chezmoi_failed", "detail": "template_error"}'* ]]
    [[ "$output" == *'"complete": false'* ]]
    [[ "$output$stderr" != *PRIVATE-CANARY-7* ]]
    sd --selection-diff
    [[ "$output$stderr" != *PRIVATE-CANARY-7* ]]
    [[ "$output" == *"ERROR (1)"* ]]
    [[ "$output" == *"chezmoi: error — "* ]]
}

@test "valid machine data: chezmoi is verified, complete is true, the file is never read or changed" {
    install_gen committed
    printf 'name: PRIVATE-CANARY-9\nemail: x@example.invalid\n' >"$FAKE/home/.chezmoidata/personal.yaml"
    local before
    before="$(tree_sum "$FAKE/home")"
    sd --selection-diff --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"complete": true'* ]]
    [[ "$output" == *'"chezmoi": {"status": "in_sync"}'* ]]
    [[ "$output$stderr" != *PRIVATE-CANARY-9* ]]
    [ "$before" = "$(tree_sum "$FAKE/home")" ]
    run grep -c PRIVATE-CANARY-9 "$STUB_LOG"
    [ "$output" = 0 ]
}

@test "the machine-data decision only tests the file, it never opens it" {
    local f="$REPO_ROOT/ops/lib/selection-diff.sh" body
    body="$(awk '/^_sd_machine_data_state\(\) \{/ { f = 1 } f { print } f && /^}/ { exit }' "$f")"
    [ -n "$body" ]
    # strip the allowed tests, [[ ]] made only of -e/-L/-f/-r "$f", !, || and &&: nothing may
    # remain that uses the path variable or redirects input
    local rest
    rest="$(printf '%s\n' "$body" | sed -E 's/\[\[( (!|\|\||&&|-[eLfr] "\$f"))+ \]\]//g')"
    [[ "$rest" != *'$f'* ]] || { echo "unexpected use of the path: $rest"; return 1; }
    [[ "$rest" != *'<'* ]] || { echo "unexpected redirection: $rest"; return 1; }
    # nothing else in the library names the file, except the one assignment of its path
    run bash -c 'grep -vE "^[[:space:]]*#" "$1" | grep "personal\.yaml" | grep -vc "SD_MACHINE_DATA_REL="' _ "$f"
    [ "$output" = 0 ]
    # selection-facts.sh never names it either
    run bash -c 'grep -vE "^[[:space:]]*#" "$1" | grep -c "personal\.yaml"' _ "$REPO_ROOT/ops/lib/selection-facts.sh"
    [ "$output" = 0 ]
    # and no command that reads content is given the path
    run grep -nE '(cat|source|head|tail|sed|awk|grep|sha256sum|shasum|od|xxd)[[:space:]]+[^#|;]*(SD_MACHINE_DATA_REL|personal\.yaml)' "$f"
    [ "$status" -ne 0 ]
}

@test "a temporary worktree without the machine data reports it missing and does not borrow the main checkout's file" {
    printf 'home/.chezmoidata/personal.yaml\n' >"$FAKE/.gitignore"
    real_git
    printf 'name: PRIVATE-CANARY-3\n' >"$FAKE/home/.chezmoidata/personal.yaml"
    "$REAL_GIT" -C "$FAKE" worktree add -q "$BATS_TEST_TMPDIR/wt" 2>&1
    [ ! -e "$BATS_TEST_TMPDIR/wt/home/.chezmoidata/personal.yaml" ]
    install_gen committed
    local main="$FAKE"
    FAKE="$BATS_TEST_TMPDIR/wt"
    sd --selection-diff --json
    FAKE="$main"
    [ "$status" -eq 11 ]
    [[ "$output" == *'"reason": "machine_data_missing"'* ]]
    [[ "$output$stderr" != *PRIVATE-CANARY-3* ]]
    refute_log '^chezmoi '
}

@test "first install: a profile directory without a generation is pending with reason no_generation, not unknown" {
    mkdir -p "$XDG_STATE_HOME/nix/profiles"
    sd --selection-diff --json
    [ "$status" -eq 10 ]
    [[ "$output" == *'"packages": {"status": "pending", "reason": "no_generation"}'* ]]
    [[ "$output" == *'"complete": true'* ]]
}

@test "no Home Manager profile directory at all: unknown with generation_unreadable, not pending" {
    sd --selection-diff --json
    [ "$status" -eq 11 ]
    [[ "$output" == *'"packages": {"status": "unknown", "reason": "generation_unreadable"}'* ]]
    [[ "$output" == *'"installed": {"state": "unknown"'* ]]
}

@test "macOS without brew: casks unknown with reason brew_missing" {
    HP=macos
    install_gen mac-committed
    sd --selection-diff --json
    [ "$status" -eq 11 ]
    [[ "$output" == *'"casks": {"status": "unknown", "reason": "brew_missing"}'* ]]
}

@test "macOS brew failing: casks error with reason brew_failed; other components stay verified" {
    HP=macos; with_brew
    install_gen mac-committed
    export STUB_BREW_FAIL=1
    sd --selection-diff --json
    [ "$status" -eq 11 ]
    [[ "$output" == *'"casks": {"status": "error", "reason": "brew_failed"}'* ]]
    [[ "$output" == *'"packages": {"status": "in_sync"}'* ]]
}

@test "the last run: unfinished is unknown (run_unfinished), failed is error (last_run_failed); the record is a limitation only" {
    install_gen committed
    last_run 'run_id=r1\nstatus=activating\n'
    sd --selection-diff --json
    [ "$status" -eq 11 ]
    [[ "$output" == *'"run": {"status": "unknown", "reason": "run_unfinished", "detail": "status activating"}'* ]]
    [[ "$output" == *'"record": {"status": "unknown", "reason": "record_absent", "affects_exit": false}'* ]]
    last_run 'run_id=r1\nstatus=failed:activate\nexit_code=1\n'
    sd --selection-diff --json
    [[ "$output" == *'"run": {"status": "error", "reason": "last_run_failed", "detail": "status failed:activate"}'* ]]
}

# ── the applied-state record ────────────────────────────────────────────────

# write_record: the record of the current generation, as install.sh writes it.
write_record() {
    bash -c 'source "$1/ops/lib/selection.sh"; source "$1/ops/lib/install-record.sh"; install_record_write install linux-desktop home-manager "$2" "$3"' \
        _ "$REPO_ROOT" "$XDG_STATE_HOME/nix/profiles/home-manager" "$FAKE"
}
rec_env() { export APP_CONFIGS_STATE_DIR="$RECDIR"; }

@test "record ok: the causes are filled, and a selection that changed since is named with its applied hash" {
    real_git
    rec_env
    install_gen committed
    write_record
    sd --selection-diff --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"record": {"state": "ok"}'* ]]
    [[ "$output" == *'"causes": {"selection_changed": "no", "repo_changed": "no", "generation_changed_outside": "no"}'* ]]
    [[ "$output" == *'"applied_selection": null'* ]]
    write_sel 'profile = "personal"\n'
    sd --selection-diff --json
    [[ "$output" == *'"causes": {"selection_changed": "yes", "repo_changed": "no"'* ]]
    [[ "$output" == *'"applied_selection": {"file": "absent", "sha256": "none"}'* ]]
    sd --selection-diff
    [[ "$output" == *"Record:    ok; written by install"* ]]
    [[ "$output" == *"selection changed since the last apply: yes"* ]]
    [[ "$output" != *"Limitations"*"applied-state record is"* ]]
}

@test "record ok: a repo that moved since is a cause" {
    real_git
    rec_env
    install_gen committed
    write_record
    printf 'more\n' >>"$FAKE/nix/vars/default.nix"
    sd --selection-diff --json
    [[ "$output" == *'"repo_changed": "yes"'* ]]
}

@test "record: repo_changed is no only when both sides are clean at the same rev; clean vs dirty is yes; dirty on both is unknown" {
    real_git
    rec_env
    install_gen committed
    # both clean
    write_record
    sd --selection-diff --json
    [[ "$output" == *'"repo_changed": "no"'* ]]
    # record clean, tree dirty now
    printf 'edit\n' >>"$FAKE/nix/vars/default.nix"
    sd --selection-diff --json
    [[ "$output" == *'"repo_changed": "yes"'* ]]
    # dirty on both: the uncommitted content may differ
    write_record
    grep -qx 'repo_dirty=yes' "$RECDIR/installed.meta"
    sd --selection-diff --json
    [[ "$output" == *'"repo_changed": "unknown"'* ]]
    # record dirty, tree clean now
    "$REAL_GIT" -C "$FAKE" checkout -q -- nix/vars/default.nix
    sd --selection-diff --json
    [[ "$output" == *'"repo_changed": "yes"'* ]]
    [[ "$output" == *'"repo": {"rev": "'*'", "dirty": "no"}'* ]]
}

@test "record: a selection file that cannot be hashed makes selection_changed unknown, not yes" {
    rec_env
    install_gen committed
    write_sel 'profile = "personal"\n'
    write_record
    printf '#!/bin/sh\nexit 1\n' >"$STUBS/sha256sum"; chmod +x "$STUBS/sha256sum"
    sd --selection-diff --json
    [[ "$output" == *'"record": {"state": "ok"}'* ]]
    [[ "$output" == *'"selection_changed": "unknown"'* ]]
    [[ "$output" == *'"applied_selection": null'* ]]
}

@test "record stale: the profile moved since, so every cause is unknown and the diff still works" {
    rec_env
    install_gen committed
    write_record
    cp -a "$XDG_STATE_HOME/nix/profiles/home-manager-1-link" "$XDG_STATE_HOME/nix/profiles/home-manager-2-link"
    ln -sfn home-manager-2-link "$XDG_STATE_HOME/nix/profiles/home-manager"
    sd --selection-diff --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"record": {"state": "stale"}'* ]]
    [[ "$output" == *'"causes": {"selection_changed": "unknown", "repo_changed": "unknown", "generation_changed_outside": "unknown"}'* ]]
    [[ "$output" == *"The applied-state record is stale, so the causes of the changes are unknown."* ]]
}

@test "record invalid or absent: unknown causes, an explicit state, never a false in sync for the attribution" {
    rec_env
    install_gen committed
    mkdir -p "$RECDIR"
    printf 'schema_version=9\nnonsense\n' >"$RECDIR/installed.meta"
    sd --selection-diff --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"record": {"state": "invalid"}'* ]]
    [[ "$output" == *'"selection_changed": "unknown"'* ]]
    sd --selection-diff
    [[ "$output" == *"Record:    invalid (the causes of the changes are unknown)"* ]]
    rm "$RECDIR/installed.meta"
    sd --selection-diff
    [[ "$output" == *"Record:    absent (the causes of the changes are unknown)"* ]]
}

# ── the wrappers prepend --apply ────────────────────────────────────────────

render() { # render <template> <out>
    local r="$FAKE"
    chezmoi execute-template --config "$BATS_TEST_TMPDIR/chezmoi.toml" --source "$r" \
        --override-data '{"chezmoi":{"os":"linux"},"name":"T","email":"t@e.t","signingKey":""}' \
        --file "$REPO_ROOT/$1" >"$2"
}

@test "wrapper: the bash sys-update always adds --apply, and sys-update --selection-diff still runs the diff, not an apply" {
    command -v chezmoi >/dev/null || skip "chezmoi not installed"
    : >"$BATS_TEST_TMPDIR/chezmoi.toml"
    render home/dot_local/bin/executable_sys-update.tmpl "$BATS_TEST_TMPDIR/sys-update"
    grep -q 'update-all.sh" --apply "\$@"' "$BATS_TEST_TMPDIR/sys-update"
    chmod +x "$BATS_TEST_TMPDIR/sys-update"
    install_gen committed
    run --separate-stderr env HOME="$HOME_T" PATH="$TPATH" HOST_PROFILE=linux-desktop USER="$UNAME" \
        SYS_UPDATE_STATE_DIR="$STATE" REAL_GIT="$REAL_GIT" timeout 120 bash "$BATS_TEST_TMPDIR/sys-update" --selection-diff
    [ "$status" -eq 0 ]
    [[ "$output" == *"read-only: nothing is built, written or applied"* ]]
    [[ "$output" == *"RESULT: IN SYNC"* ]]
    [ ! -e "$STATE" ]
    refute_log '^(home-manager|darwin-rebuild)|^chezmoi( --source=[^ ]+)? apply( |$)'
}

@test "wrapper: the fish sys-update always adds --apply, and sys-update --selection-diff still runs the diff, not an apply" {
    command -v fish >/dev/null || skip "fish not installed"
    command -v chezmoi >/dev/null || skip "chezmoi not installed"
    : >"$BATS_TEST_TMPDIR/chezmoi.toml"
    render home/dot_config/fish/conf.d/dotfiles.fish.tmpl "$BATS_TEST_TMPDIR/dotfiles.fish"
    grep -q 'update-all.sh" --apply \$argv' "$BATS_TEST_TMPDIR/dotfiles.fish"
    fish -n "$BATS_TEST_TMPDIR/dotfiles.fish"
    install_gen committed
    run --separate-stderr env HOME="$HOME_T" PATH="$TPATH" HOST_PROFILE=linux-desktop USER="$UNAME" \
        SYS_UPDATE_STATE_DIR="$STATE" REAL_GIT="$REAL_GIT" \
        timeout 120 fish --no-config -c "source $BATS_TEST_TMPDIR/dotfiles.fish; sys-update --selection-diff"
    [ "$status" -eq 0 ]
    [[ "$output" == *"read-only: nothing is built, written or applied"* ]]
    [[ "$output" == *"RESULT: IN SYNC"* ]]
    [ ! -e "$STATE" ]
    refute_log '^(home-manager|darwin-rebuild)|^chezmoi( --source=[^ ]+)? apply( |$)'
}
