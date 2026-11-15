#!/usr/bin/env bats
# sys-install and the install selection (T-0042 T5): --profile, --reconfigure,
# the TTY prompt, the read-only preview and the write of the local selection.
#
# Every test runs a scratch copy of ops/install.sh with nix, nix-store, chezmoi
# and brew replaced by the stubs in fixtures/selection/stubs. The stubs answer
# from the TSV states in fixtures/selection/state. The real nix is never run
# here (tests/bash/selection.bats evaluates the real flake), the PATH holds only
# the stubs and a few symlinked system tools, and the selection directory is
# always pinned with APP_CONFIGS_SELECTION_DIR. TTY flows run under script(1),
# like tests/bash/bootstrap-safety.bats.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIXD="$BATS_TEST_DIRNAME/fixtures/selection"
    UNAME=utmostcreator
    HOME_T="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME_T"
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/sel"
    unset XDG_CONFIG_HOME WSL_DISTRO_NAME NIX_CONFIG STUB_NIX_FAIL_OVERRIDE STUB_NIX_EVAL_FAIL STUB_NIX_STORE_FAIL \
        STUB_CHEZMOI_STATUS STUB_CHEZMOI_STATUS_FAIL STUB_BREW_CASKS STUB_REFS_FILE
    export XDG_STATE_HOME="$HOME_T/.local/state"
    export DETECT_HOST_WSL_RUN="$BATS_TEST_TMPDIR/no-wsl-run" DETECT_HOST_WSL_INTEROP="$BATS_TEST_TMPDIR/no-wsl-interop"
    export INSTALL_NIX_DEFAULT_PROFILE="$BATS_TEST_TMPDIR/no-nix-profile" \
        INSTALL_ETC_PROFILE_D="$BATS_TEST_TMPDIR/no-profile.d" \
        INSTALL_NIXOS_MARKER="$BATS_TEST_TMPDIR/no-nixos-marker" \
        INSTALL_OS_RELEASE="$BATS_TEST_TMPDIR/no-os-release"
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"; mkdir -p "$TMPDIR"
    export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"; : >"$STUB_LOG"
    export STUB_STATE_DIR="$FIXD/state"
    STUBS="$BATS_TEST_TMPDIR/bin"; SYSBIN="$BATS_TEST_TMPDIR/sysbin"
    mkdir -p "$STUBS" "$SYSBIN"
    local t p
    for t in bash env git curl sed awk cat dirname head tail find xargs stat sort grep \
        uname mkdir tee tr rm cp mv chmod ls readlink basename sleep date wc cut id comm \
        mktemp ln script timeout sh touch diff sha256sum tty stty seq; do
        p="$(command -v "$t" 2>/dev/null)" || continue
        if [ -x "$p" ]; then ln -sf "$p" "$SYSBIN/$t"; fi
    done
    TPATH="$STUBS:$SYSBIN"
    make_fake
}

# make_fake: a scratch repo with install.sh, the shared libs, the profile
# files and stub tools. Nothing in it is real except the scripts under test.
make_fake() {
    FAKE="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FAKE/ops" "$FAKE/nix/vars" "$FAKE/nix/profiles" "$FAKE/home/.chezmoidata" "$FAKE/.git"
    cp "$REPO_ROOT/ops/install.sh" "$REPO_ROOT/ops/update-version-report.sh" "$FAKE/ops/"
    cp -R "$REPO_ROOT/ops/lib" "$FAKE/ops/lib"
    cp "$REPO_ROOT"/nix/profiles/*.toml "$FAKE/nix/profiles/"
    cp "$REPO_ROOT/nix/flake.lock" "$FAKE/nix/flake.lock"
    printf '{\n  username = "%s";\n}\n' "$UNAME" >"$FAKE/nix/vars/default.nix"
    : >"$FAKE/home/.chezmoidata/personal.yaml"
    local s
    for s in nix nix-store chezmoi; do
        cp "$FIXD/stubs/$s" "$STUBS/$s"; chmod +x "$STUBS/$s"
    done
    for s in home-manager mise lefthook; do
        printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >>"$STUB_LOG"\nexit 0\n' "$s" >"$STUBS/$s"
        chmod +x "$STUBS/$s"
    done
    for s in snapshot-home doctor; do printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE/ops/$s.sh"; chmod +x "$FAKE/ops/$s.sh"; done
    printf '#!/usr/bin/env bash\necho Europe/London\n' >"$FAKE/ops/detect-timezone.sh"; chmod +x "$FAKE/ops/detect-timezone.sh"
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

# write_sel <toml text>: a local selection file in the pinned directory.
write_sel() {
    mkdir -p "$APP_CONFIGS_SELECTION_DIR"
    printf '%b' "$1" >"$APP_CONFIGS_SELECTION_DIR/selection.toml"
}
sel_text() { cat "$APP_CONFIGS_SELECTION_DIR/selection.toml"; }
no_sel_file() { [ ! -e "$APP_CONFIGS_SELECTION_DIR/selection.toml" ]; }

# inst <args>: install.sh without a TTY.
inst() {
    run env HOME="$HOME_T" PATH="$TPATH" HOST_PROFILE="${HP:-linux-desktop}" USER="$UNAME" \
        bash "$FAKE/ops/install.sh" "$@" </dev/null
}

# inst_tty <answers> <args>: stdin and stderr on a pty. Answers are printf %b
# text, one per prompt, each ending in \n; when they run out the pty reads EOF.
inst_tty() {
    local answers="$1"
    shift
    # script(1) starts the command with $SHELL: pin bash (a login fish would
    # write its own state into the suite HOME).
    run env SHELL="$(command -v bash)" bash -c 'printf "%b" "$1" | timeout 60 script -qec "$2" /dev/null' _ "$answers" \
        "env HOME=$HOME_T PATH=$TPATH HOST_PROFILE=${HP:-linux-desktop} USER=$UNAME bash $FAKE/ops/install.sh $*"
    output="${output//$'\r'/}"
}

# section <header prefix>: the lines of $output from the header (column 0) up to
# the next column-0 line.
section() { printf '%s\n' "$output" | awk -v h="$1" 'f && /^[^ ]/ { exit } index($0, h) == 1 { f = 1 } f'; }

calls() { grep -c "$1" "$STUB_LOG" || true; }
no_mutation() { # no chezmoi apply/init, no switch, no mise, no lefthook
    if grep -Eq '^(chezmoi .*(apply|init)|home-manager|mise|lefthook)' "$STUB_LOG"; then
        grep -E '^(chezmoi|home-manager|mise|lefthook)' "$STUB_LOG"
        return 1
    fi
}

# ── AC6: no TTY ─────────────────────────────────────────────────────────────

@test "AC6: --reconfigure without a TTY exits 1 before any mutation and writes nothing" {
    inst --reconfigure
    [ "$status" -eq 1 ]
    [[ "$output" == *"--reconfigure needs a terminal"* ]]
    [[ "$output" != *"Preflight"* ]]
    [ ! -s "$STUB_LOG" ]
    no_sel_file
}

@test "AC6: --reconfigure --dry-run without a TTY also exits 1" {
    inst --reconfigure --dry-run
    [ "$status" -eq 1 ]
    [ ! -s "$STUB_LOG" ]
    no_sel_file
}

@test "AC6: --dry-run without a TTY and without a local file prompts for nothing, writes nothing, uses the default" {
    inst --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"no local selection"* ]]
    [[ "$output" != *"[Y/n]"* ]]
    [[ "$output" != *"[a]pply"* ]]
    [[ "$output" != *"dry run: would write"* ]]
    [[ "$output" == *"home-manager switch -b hm-bak --flake $FAKE/nix#linux-desktop"* ]]
    [[ "$output" != *"--override-input"* ]]
    [ ! -e "$APP_CONFIGS_SELECTION_DIR" ]
}

@test "AC6: --dry-run with a local file: SELECTION_ARGS carries the override and nothing is asked" {
    write_sel 'profile = "work"\n'
    inst --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"--override-input selection path:$APP_CONFIGS_SELECTION_DIR"* ]]
    [[ "$output" != *"[Y/n]"* ]]
    [ "$(sel_text)" = 'profile = "work"' ]
}

@test "a plain apply without a local file or a TTY writes nothing, never blocks and uses the committed default" {
    inst
    [ "$status" -eq 0 ]
    [[ "$output" == *"no local selection"* ]]
    [[ "$output" != *"Preview (nothing applied)"* ]]
    no_sel_file
    grep -q "^home-manager switch -b hm-bak --flake $FAKE/nix#linux-desktop\$" "$STUB_LOG"
}

# ── a local file: one line, no prompt, validated before any change ──────────

@test "a plain apply with a local file prints one line, asks nothing and prints no preview" {
    write_sel 'profile = "work"\n'
    inst
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'Selection: ')" -eq 1 ]
    [[ "$output" == *"Selection: $APP_CONFIGS_SELECTION_DIR/selection.toml (profile work)"* ]]
    [[ "$output" != *"Preview (nothing applied)"* ]]
    [[ "$output" != *"Present state"* ]]
    grep -q "^home-manager switch -b hm-bak --flake $FAKE/nix#linux-desktop --override-input selection path:$APP_CONFIGS_SELECTION_DIR\$" "$STUB_LOG"
}

@test "a plain apply with a local file validates it before chezmoi and the switch" {
    write_sel 'profile = "work"\n'
    inst
    [ "$status" -eq 0 ]
    local v c h
    v="$(grep -n "^nix eval .*--override-input selection" "$STUB_LOG" | head -n1 | cut -d: -f1)"
    c="$(grep -n '^chezmoi' "$STUB_LOG" | head -n1 | cut -d: -f1)"
    h="$(grep -n '^home-manager' "$STUB_LOG" | head -n1 | cut -d: -f1)"
    [ -n "$v" ]
    [ -n "$c" ]
    [ -n "$h" ]
    [ "$v" -lt "$c" ]
    [ "$v" -lt "$h" ]
}

@test "a plain apply with an invalid local file fails before chezmoi and the switch, naming the key" {
    write_sel 'bogus = 1\n'
    inst
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown key 'bogus'"* ]]
    no_mutation
    [ "$(sel_text)" = 'bogus = 1' ]
}

# ── --profile ───────────────────────────────────────────────────────────────

@test "AC7: --profile writes only profile, previews and continues without asking" {
    inst --profile work
    [ "$status" -eq 0 ]
    [ "$(sel_text)" = 'profile = "work"' ]
    [[ "$output" == *"Preview (nothing applied): profile personal -> work"* ]]
    [[ "$output" != *"[a]pply"* ]]
    grep -q "^home-manager switch -b hm-bak --flake $FAKE/nix#linux-desktop --override-input selection path:$APP_CONFIGS_SELECTION_DIR\$" "$STUB_LOG"
}

@test "AC7: --profile drops the group overrides and the preview says they are replaced" {
    write_sel 'profile = "work"\n\n[groups]\nmedia = false\n'
    inst --profile personal
    [ "$status" -eq 0 ]
    [ "$(sel_text)" = 'profile = "personal"' ]
    [[ "$output" == *"replaces your existing group overrides (media=off)"* ]]
}

@test "AC7: --profile on a TTY asks nothing either" {
    inst_tty '\n' --profile work
    [ "$status" -eq 0 ]
    [[ "$output" != *"[a]pply"* ]]
    [[ "$output" != *"[Y/n]"* ]]
    [ "$(sel_text)" = 'profile = "work"' ]
}

@test "--profile with an unknown profile fails before any mutation" {
    inst --profile bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown profile 'bogus'"* ]]
    [ ! -s "$STUB_LOG" ]
    no_sel_file
}

@test "--profile repairs an invalid local file instead of failing on it" {
    write_sel 'bogus = 1\n'
    inst --profile work
    [ "$status" -eq 0 ]
    [[ "$output" == *"current selection is invalid"* ]]
    [ "$(sel_text)" = 'profile = "work"' ]
}

@test "--profile with a failing preview stops the install: nothing written, no chezmoi, no switch" {
    export STUB_NIX_FAIL_OVERRIDE=1
    inst --profile work
    [ "$status" -eq 1 ]
    [[ "$output" == *"stub: evaluating the proposed selection failed"* ]]
    no_sel_file
    no_mutation
}

@test "--profile --dry-run without a TTY prints the preview, writes nothing and never prompts" {
    inst --profile work --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Preview (nothing applied): profile personal -> work"* ]]
    [[ "$output" == *"dry run: would write $APP_CONFIGS_SELECTION_DIR/selection.toml"* ]]
    [[ "$output" != *"[Y/n]"* ]]
    [ ! -e "$APP_CONFIGS_SELECTION_DIR" ]
}

# ── the TTY prompt flow ─────────────────────────────────────────────────────

@test "AC7f: a on a TTY writes only the deltas and the install continues" {
    inst_tty 'work\n\nn\n\na\n'
    [ "$status" -eq 0 ]
    [ "$(sel_text)" = "$(printf 'profile = "work"\n\n[groups]\nmedia = false')" ]
    [[ "$output" == *"[a]pply  [c]hange selection  [q]uit"* ]]
    grep -q "^home-manager switch .*--override-input selection path:$APP_CONFIGS_SELECTION_DIR\$" "$STUB_LOG"
}

@test "AC7f: all defaults for the host profile write only the profile line" {
    inst_tty '\n\n\n\na\n'
    [ "$status" -eq 0 ]
    [ "$(sel_text)" = 'profile = "personal"' ]
}

@test "AC7f: c returns to the prompts with the current answers pre-filled" {
    inst_tty 'work\n\nn\n\nc\n\n\n\n\na\n'
    [ "$status" -eq 0 ]
    [ "$(sel_text)" = "$(printf 'profile = "work"\n\n[groups]\nmedia = false')" ]
    [ "$(printf '%s\n' "$output" | grep -c 'Preview (nothing applied)')" -eq 2 ]
    # the second pass offers media as [y/N]: the first answer was no
    [[ "$output" == *"media"*"[Y/n]"*"media"*"[y/N]"* ]]
    [[ "$output" == *"[work]"* ]]
}

@test "AC7f: an empty answer at the a/c/q prompt asks again" {
    inst_tty 'work\n\n\n\n\na\n'
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -o '\[a\]pply  \[c\]hange selection  \[q\]uit' | wc -l)" -eq 2 ]
    [ "$(sel_text)" = 'profile = "work"' ]
}

@test "AC7f: q writes nothing, runs no chezmoi and no switch, and says what was not done" {
    inst_tty 'work\n\nn\n\nq\n'
    [ "$status" -ne 0 ]
    no_sel_file
    no_mutation
    [[ "$output" == *"cancelled at the selection step: no selection saved, no dotfiles applied, no switch run; what earlier steps did (Nix, base tools, preflight seeding of personal.yaml) remains"* ]]
    [[ "$output" != *"nothing changed"* ]]
}

@test "AC7f: q at the profile prompt also cancels" {
    inst_tty 'q\n'
    [ "$status" -ne 0 ]
    no_sel_file
    no_mutation
    [[ "$output" == *"cancelled at the selection step"* ]]
}

@test "AC7f: EOF at a prompt cancels the same way" {
    inst_tty 'work\n\n'
    [ "$status" -ne 0 ]
    no_sel_file
    no_mutation
    [[ "$output" == *"cancelled at the selection step: no selection saved, no dotfiles applied, no switch run"* ]]
}

@test "AC7f: EOF at the a/c/q prompt cancels and writes nothing" {
    inst_tty 'work\n\n\n\n'
    [ "$status" -ne 0 ]
    no_sel_file
    no_mutation
}

@test "AC7f: a dry-run on a TTY prompts, previews and on a only says what it would write" {
    inst_tty 'work\n\nn\n\na\n' --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"dry run: would write $APP_CONFIGS_SELECTION_DIR/selection.toml"* ]]
    [ ! -e "$APP_CONFIGS_SELECTION_DIR" ]
}

@test "AC7f: q in a dry-run on a TTY stops, and does not claim earlier steps ran" {
    inst_tty 'q\n' --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"cancelled at the selection step"* ]]
    [[ "$output" != *"earlier steps"* ]]
}

@test "AC7: a second run with the file present asks nothing" {
    inst_tty 'work\n\nn\n\na\n'
    [ "$status" -eq 0 ]
    inst_tty '\n'
    [ "$status" -eq 0 ]
    [[ "$output" != *"[Y/n]"* ]]
    [[ "$output" != *"[a]pply"* ]]
    [[ "$output" == *"Selection: $APP_CONFIGS_SELECTION_DIR/selection.toml (profile work)"* ]]
}

@test "prompts go to stderr and the preview to stdout" {
    run env SHELL="$(command -v bash)" bash -c 'printf "work\n\nn\n\na\n" | timeout 60 script -qec "$1" /dev/null' _ \
        "env HOME=$HOME_T PATH=$TPATH HOST_PROFILE=linux-desktop USER=$UNAME bash $FAKE/ops/install.sh --dry-run 1>$BATS_TEST_TMPDIR/stdout.txt"
    [ "$status" -eq 0 ]
    grep -q 'Preview (nothing applied)' "$BATS_TEST_TMPDIR/stdout.txt"
    run grep -F '[Y/n]' "$BATS_TEST_TMPDIR/stdout.txt"
    [ "$status" -ne 0 ]
}

@test "--reconfigure on a TTY pre-selects the current effective values" {
    write_sel 'profile = "work"\n\n[groups]\nmedia = false\n'
    inst_tty '\n\n\n\na\n' --reconfigure
    [ "$status" -eq 0 ]
    [[ "$output" == *"[work]"* ]]
    [[ "$output" == *"media"*"[y/N]"* ]]
    [ "$(sel_text)" = "$(printf 'profile = "work"\n\n[groups]\nmedia = false')" ]
}

@test "--reconfigure with an invalid file shows the error and pre-fills from the host default" {
    write_sel 'bogus = 1\n'
    inst_tty '\n\n\n\na\n' --reconfigure
    [ "$status" -eq 0 ]
    [[ "$output" == *"unknown key 'bogus'"* ]]
    [[ "$output" == *"[personal]"* ]]
    [ "$(sel_text)" = 'profile = "personal"' ]
}

# ── AC7e: the present-state table ───────────────────────────────────────────

@test "AC7e: the present-state table prints before the first prompt, with installed n/m against the current generation" {
    install_gen committed
    inst_tty 'q\n'
    local before="${output%%Profile (*}"
    [[ "$before" == *"Present state"* ]]
    [[ "$before" == *"media"*"installed 4/4"*"ffmpeg imagemagick viu yt-dlp"* ]]
    [[ "$before" == *"installed 7/7"* ]]
}

@test "AC7e: on a first install the table shows 0/m and annotates what is on PATH, not from Home Manager" {
    printf '#!/bin/sh\nexit 0\n' >"$STUBS/ffmpeg"; chmod +x "$STUBS/ffmpeg"
    inst_tty 'work\n\n\n\nq\n'
    [[ "$output" == *"No Home Manager generation yet (first install)"* ]]
    local before="${output%%Profile (*}"
    [[ "$before" == *"media"*"installed 0/4"* ]]
    [[ "$before" == *"ffmpeg: on PATH, not from Home Manager: $STUBS/ffmpeg"* ]]
    [[ "$before" != *"imagemagick: on PATH"* ]]
}

# ── the preview ─────────────────────────────────────────────────────────────

@test "personal -> work on linux-desktop lists the removal of the personal apps" {
    install_gen committed
    inst --profile work --dry-run
    [ "$status" -eq 0 ]
    local s
    s="$(section 'Outcome by group')"
    [[ "$s" == *"personal apps"*"remove 7"* ]]
    local n
    for n in openclaw syncthing sync-open sync-start sync-stop telegram-desktop vesktop; do
        [[ "$s" == *"$n"* ]] || { echo "missing $n"; echo "$s"; return 1; }
    done
    [[ "$output" == *"Note: deselected packages leave PATH at the next switch; files in \$HOME and app data stay"* ]]
}

@test "outcome by group says keep, add, remove and stays off from installed and proposed" {
    install_gen committed
    write_sel 'profile = "personal"\n'
    inst --profile work --dry-run
    local s
    s="$(section 'Outcome by group')"
    [[ "$s" == *"media"*"keep 4"* ]]
    [[ "$s" == *"go"*"keep 2"* ]]
    # media off: removed; go stays kept
    write_sel 'profile = "work"\n'
    : >"$STUB_LOG"
    install_gen work
    inst --profile personal --dry-run
    s="$(section 'Outcome by group')"
    [[ "$s" == *"personal apps"*"add 7"* ]]
    # a group that is off now and stays off
    install_gen work-nomedia
    write_sel 'profile = "work"\n\n[groups]\nmedia = false\n'
    inst --profile work --dry-run
    [ "$status" -eq 0 ]
    s="$(section 'Outcome by group')"
    [[ "$s" == *"media"*"add 4"* ]]
}

@test "AC7: the preview lists additions and removals with versions" {
    install_gen committed
    inst --profile work --dry-run
    local s
    s="$(section 'Packages, from your selection')"
    [[ "$s" == *"- 7 removed"* ]]
    [[ "$s" == *"REMOVED"* ]]
    [[ "$s" == *"vesktop"*"1.5.3"* ]]
    [[ "$s" == *"telegram-desktop"*"5.1.7"* ]]
    [[ "$s" != *"ADDED"* ]]
}

@test "AC7a: package rows compare installed with proposed, split into your selection and pending changes" {
    install_gen committed
    # the installed ripgrep is older than the repo's: a pending change, not the selection's
    sed -i 's/ripgrep-14.1.0/ripgrep-13.0.0/' "$STUB_REFS_FILE"
    inst --profile work --dry-run
    [ "$status" -eq 0 ]
    local mine pending
    mine="$(section 'Packages, from your selection')"
    pending="$(section 'Packages, pending changes')"
    [[ "$mine" == *"vesktop"* ]]
    [[ "$mine" != *"ripgrep"* ]]
    [[ "$pending" == *"UPGRADED"* ]]
    [[ "$pending" == *"ripgrep"*"13.0.0"*"14.1.0"* ]]
    [[ "$pending" != *"vesktop"* ]]
    [[ "$output" == *"pending changes (repo, or a selection not yet applied)"* ]]
}

@test "AC7k: a version change of a kept package shows as upgraded under pending changes" {
    install_gen committed
    sed -i 's/ffmpeg-7.0.1/ffmpeg-6.1.0/' "$STUB_REFS_FILE"
    inst --dry-run
    [ "$status" -eq 0 ]
    local pending
    pending="$(section 'Packages, pending changes')"
    [[ "$pending" == *"1 upgraded"* ]]
    [[ "$pending" == *"ffmpeg"*"6.1.0"*"7.0.1"* ]]
}

@test "AC7l: comparing an identical configuration shows no package changes, the noise list applied" {
    install_gen committed
    inst --profile personal --dry-run
    [ "$status" -eq 0 ]
    local mine pending
    mine="$(section 'Packages, from your selection')"
    pending="$(section 'Packages, pending changes')"
    [[ "$mine" == *"no package changes (19 unchanged)"* ]]
    [[ "$pending" == *"no package changes (19 unchanged)"* ]]
    [[ "$output" != *"dummy-xdg-mime-dirs"* ]]
}

@test "AC7b: Home Manager files and units: removed, annotated as user units" {
    install_gen committed
    inst --profile work --dry-run
    [ "$status" -eq 0 ]
    local s
    s="$(section 'Home Manager files and services, from your selection')"
    [[ "$s" == *"removed"*".config/systemd/user/syncthing.service (user unit)"* ]]
    [[ "$s" == *"removed"*".openclaw/openclaw.json"* ]]
    [[ "$s" != *".openclaw/openclaw.json (user unit)"* ]]
    [[ "$s" == *"changed"*".config/fish/config.fish"* ]]
    [[ "$s" != *"nix-gc.timer"* ]]
}

@test "AC7b: Home Manager files and units: added" {
    write_sel 'profile = "work"\n'
    install_gen work
    inst --profile personal --dry-run
    [ "$status" -eq 0 ]
    local s
    s="$(section 'Home Manager files and services, from your selection')"
    [[ "$s" == *"added"*".config/systemd/user/syncthing.service (user unit)"* ]]
    [[ "$s" == *"added"*".config/systemd/user/default.target.wants/syncthing.service (user unit)"* ]]
    [[ "$s" == *"changed"*".config/fish/config.fish"* ]]
}

@test "AC7b: pending changes in files are reported separately from the selection's" {
    install_gen committed
    local gen="$XDG_STATE_HOME/nix/profiles/home-manager-1-link/home-files"
    rm "$gen/.config/mimeapps.list"
    ln -sfn /nix/store/00000000000000000000000000000000-old-nix-gc.timer "$gen/.config/systemd/user/nix-gc.timer"
    inst --profile work --dry-run
    local pending mine
    pending="$(section 'Home Manager files and services, pending changes')"
    mine="$(section 'Home Manager files and services, from your selection')"
    [[ "$pending" == *"added"*".config/mimeapps.list"* ]]
    [[ "$pending" == *"changed"*".config/systemd/user/nix-gc.timer (user unit)"* ]]
    [[ "$mine" != *"mimeapps.list"* ]]
}

@test "AC7c: the chezmoi section shows counts and at most 20 paths, no diff" {
    local f="$BATS_TEST_TMPDIR/status.txt" i
    : >"$f"
    for i in $(seq 1 12); do printf ' A dot_added%s\n' "$i" >>"$f"; done
    for i in $(seq 1 9); do printf ' M dot_mod%s\n' "$i" >>"$f"; done
    printf ' D dot_gone\n' >>"$f"
    for i in 1 2 3; do printf ' R run_script%s\n' "$i" >>"$f"; done
    export STUB_CHEZMOI_STATUS="$f"
    inst --dry-run
    [ "$status" -eq 0 ]
    local s
    s="$(section 'chezmoi files')"
    [[ "$s" == *"pending repo changes (the selection does not change chezmoi on Linux)"* ]]
    [[ "$s" == *"added 12, modified 9, removed 1, scripts 3"* ]]
    [ "$(printf '%s\n' "$s" | grep -cE '^ +[AMDR] ')" -eq 20 ]
    [[ "$s" == *"and 5 more"* ]]
    [[ "$s" == *"full diff: chezmoi --source=$FAKE diff"* ]]
    grep -q "^chezmoi --source=$FAKE status --no-tty\$" "$STUB_LOG"
    [ "$(calls '^chezmoi .* diff')" -eq 0 ]
}

@test "AC7c: a failing chezmoi status prints unavailable and the preview still succeeds" {
    export STUB_CHEZMOI_STATUS_FAIL="no source state yet"
    inst --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"unavailable (chezmoi: no source state yet); after install: chezmoi diff"* ]]
}

@test "AC7j: with no Home Manager profile the first-install header shows and every selected item is an add" {
    inst --profile work --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"No Home Manager generation yet (first install)"* ]]
    local s
    s="$(section 'Packages, pending changes')"
    [[ "$s" == *"19 added"* || "$s" == *"+ 19 added"* ]]
}

@test "AC7j: an unreadable installed generation prints unknown and the selection comparison still prints" {
    install_gen committed
    export STUB_NIX_STORE_FAIL=1
    inst --profile work --dry-run
    [ "$status" -eq 0 ]
    [[ "$(section 'Packages, pending changes')" == *"unknown"* ]]
    [[ "$(section 'Outcome by group')" == *"unknown"* ]]
    [[ "$(section 'Packages, from your selection')" == *"vesktop"* ]]
}

@test "AC7i: an invalid selection exits 1, names the key, prints no preview section and writes nothing" {
    write_sel 'bogus = 1\n'
    inst --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown key 'bogus'"* ]]
    [[ "$output" != *"Present state"* ]]
    [[ "$output" != *"Packages,"* ]]
    [[ "$output" != *"Outcome by group"* ]]
    [ "$(sel_text)" = 'bogus = 1' ]
}

@test "AC7i: a proposed selection that cannot be evaluated prints no section and writes nothing" {
    export STUB_NIX_FAIL_OVERRIDE=1
    inst --profile work --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"stub: evaluating the proposed selection failed"* ]]
    [[ "$output" != *"Present state"* ]]
    [[ "$output" != *"Packages,"* ]]
    [ ! -e "$APP_CONFIGS_SELECTION_DIR" ]
}

@test "--dry-run without nix prints preview unavailable and still succeeds" {
    rm "$STUBS/nix"
    if PATH="$TPATH" command -v nix >/dev/null; then skip "a real nix is on the curated PATH"; fi
    inst --dry-run --profile work
    [ "$status" -eq 0 ]
    [[ "$output" == *"preview unavailable: nix not installed"* ]]
    [ ! -e "$APP_CONFIGS_SELECTION_DIR" ]
}

@test "a dry-run with no local selection survives a preview that cannot be evaluated" {
    export STUB_NIX_EVAL_FAIL=1
    inst --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"stub: evaluation failure"* ]]
    [[ "$output" == *"preview unavailable: the committed default could not be evaluated"* ]]
    [[ "$output" == *"home-manager switch -b hm-bak --flake $FAKE/nix#linux-desktop"* ]]
}

@test "a dry-run with no change shows only the present-state and pending blocks" {
    install_gen committed
    inst --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Present state"* ]]
    [[ "$output" == *"Packages, pending changes"* ]]
    [[ "$output" == *"Home Manager files and services, pending changes"* ]]
    [[ "$output" == *"chezmoi files"* ]]
    [[ "$output" != *"Preview (nothing applied)"* ]]
    [[ "$output" != *"Outcome by group"* ]]
    [[ "$output" != *"from your selection"* ]]
}

# ── AC7d: macOS ─────────────────────────────────────────────────────────────

@test "AC7d: macOS casks: adds marked, removed installed casks stay installed, unmanaged only counted" {
    with_brew
    printf 'rectangle\nlinearmouse\nsomeapp1\nsomeapp2\n' >"$BATS_TEST_TMPDIR/casks"
    export STUB_BREW_CASKS="$BATS_TEST_TMPDIR/casks"
    HP=macos inst --dry-run --profile work
    [ "$status" -eq 0 ]
    local s
    s="$(section 'macOS casks')"
    [[ "$s" == *"raycast: add (installed at the next switch)"* ]]
    [[ "$s" == *"linearmouse: stays installed (Homebrew cleanup = none); remove by hand: brew uninstall --cask linearmouse"* ]]
    [[ "$s" == *"unmanaged installed casks: 2"* ]]
    [[ "$s" != *"someapp1"* ]]
    [[ "$s" != *"rectangle"* ]]
    grep -q '^brew list --cask -1$' "$STUB_LOG"
}

@test "AC13: on macOS the prompt offers macInput, and n lists both input casks as staying installed" {
    with_brew
    printf 'rectangle\nkarabiner-elements\nlinearmouse\n' >"$BATS_TEST_TMPDIR/casks"
    export STUB_BREW_CASKS="$BATS_TEST_TMPDIR/casks"
    HP=macos inst_tty 'work\n\nn\n\n\na\n' --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"macInput"* ]]
    local s
    s="$(section 'macOS casks')"
    [[ "$s" == *"karabiner-elements: stays installed (Homebrew cleanup = none); remove by hand: brew uninstall --cask karabiner-elements"* ]]
    [[ "$s" == *"linearmouse: stays installed (Homebrew cleanup = none); remove by hand: brew uninstall --cask linearmouse"* ]]
    [[ "$output" == *"dry run: would write"* ]]
}

@test "S1: the macOS present-state row counts the input casks against brew" {
    with_brew
    printf 'rectangle\nkarabiner-elements\n' >"$BATS_TEST_TMPDIR/casks"
    export STUB_BREW_CASKS="$BATS_TEST_TMPDIR/casks"
    HP=macos inst --dry-run --profile work
    [ "$status" -eq 0 ]
    local row
    row="$(section 'Present state' | grep '^  macInput')"
    [[ "$row" == *"installed 1/2 karabiner-elements"* ]] || { echo "$row"; return 1; }
}

@test "S1: without brew the macOS present-state row names the casks and says the state is unknown" {
    HP=macos inst --dry-run --profile work
    [ "$status" -eq 0 ]
    local row
    row="$(section 'Present state' | grep '^  macInput')"
    [[ "$row" == *"karabiner-elements linearmouse"* ]] || { echo "$row"; return 1; }
    [[ "$row" == *"cask state unknown"* ]]
    [[ "$row" != *"0/0"* ]]
}

@test "S1: the macOS prompt label for macInput names the casks" {
    with_brew
    HP=macos inst_tty 'work\n\n\n\n\nq\n' --dry-run
    [[ "$output" == *"Install group macInput (karabiner-elements linearmouse)?"* ]] || { echo "$output"; return 1; }
}

@test "S1: the outcome row says deselected input casks stay installed" {
    with_brew
    printf 'rectangle\nkarabiner-elements\nlinearmouse\n' >"$BATS_TEST_TMPDIR/casks"
    export STUB_BREW_CASKS="$BATS_TEST_TMPDIR/casks"
    HP=macos inst_tty 'work\n\nn\n\n\na\n' --dry-run
    [ "$status" -eq 0 ]
    local row
    row="$(section 'Outcome by group' | grep '^  macInput')"
    [[ "$row" == *"stays installed 2: karabiner-elements linearmouse"* ]] || { echo "$row"; return 1; }
    [[ "$row" != *"no members"* ]]
}

@test "S1: the outcome row without brew names the casks and says the state is unknown" {
    HP=macos inst_tty 'work\n\nn\n\n\na\n' --dry-run
    local row
    row="$(section 'Outcome by group' | grep '^  macInput')"
    [[ "$row" == *"karabiner-elements linearmouse"* ]] || { echo "$row"; return 1; }
    [[ "$row" == *"cask state unknown"* ]]
}

@test "AC13: on Linux the prompt never offers macInput" {
    inst_tty 'work\n\n\n\na\n' --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"macInput"* ]]
}

@test "AC7d: macOS without brew says cask state unknown" {
    HP=macos inst --dry-run --profile work
    [ "$status" -eq 0 ]
    [[ "$(section 'macOS casks')" == *"cask state unknown"* ]]
}

@test "AC7d: Linux prints no cask section and never calls brew" {
    with_brew
    inst --dry-run --profile work
    [ "$status" -eq 0 ]
    [[ "$output" == *"Preview (nothing applied)"* ]]
    [[ "$output" != *"macOS casks"* ]]
    [ "$(calls '^brew')" -eq 0 ]
}

# ── AC7h: the preview is read-only ──────────────────────────────────────────

@test "AC7h: the preview runs only nix eval with IFD off, nix-store -q, chezmoi status and brew list" {
    with_brew
    install_gen committed
    local before after
    before="$(sha256sum "$FAKE/nix/flake.lock")"
    HP=macos inst --dry-run --profile work
    [ "$status" -eq 0 ]
    inst --dry-run --profile work
    [ "$status" -eq 0 ]
    local bad
    bad="$(awk '
      $1 == "nix" {
        if ($2 == "--version" || $2 == "show-config") next
        if ($2 == "eval" && ($0 ~ /--option allow-import-from-derivation false/ || $0 ~ / -f /)) next
        print; next }
      $1 == "nix-store" { if ($2 == "-q" && $3 == "--references") next; print; next }
      $1 == "chezmoi" { if ($2 ~ /^--source=/ && $3 == "status" && $4 == "--no-tty") next; print; next }
      $1 == "brew" { if ($2 == "list" && $3 == "--cask" && $4 == "-1") next; print; next }
      { print }' "$STUB_LOG")"
    [ -z "$bad" ] || { echo "unexpected calls:"; echo "$bad"; return 1; }
    grep -q '^nix-store -q --references' "$STUB_LOG"
    after="$(sha256sum "$FAKE/nix/flake.lock")"
    [ "$before" = "$after" ]
}

@test "AC7h: no result link, no selection file and no temp dir is left behind" {
    install_gen committed
    inst --dry-run --profile work
    [ "$status" -eq 0 ]
    inst_tty 'work\n\nn\n\na\n' --dry-run
    [ "$status" -eq 0 ]
    [ ! -e "$APP_CONFIGS_SELECTION_DIR" ]
    [ -z "$(find "$FAKE" "$BATS_TEST_TMPDIR" -maxdepth 2 -name 'result*' -type l)" ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "AC7h: a real apply leaves no temp dir either" {
    inst --profile work
    [ "$status" -eq 0 ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

# ── AC7g: only install.sh asks or previews ──────────────────────────────────

# prompt_callers <root>: every file under ops, scripts, home, nix and mise.toml,
# except install.sh and selection.sh, that names a prompt, preview or write
# function of the install selection.
prompt_callers() {
    (cd "$1" && grep -rEl 'selection_(preview|prompt|present|write|read|facts)' ops scripts home nix mise.toml 2>/dev/null \
        | grep -vE '^ops/(install\.sh|lib/selection\.sh)$' || true)
}

@test "AC7g: nothing but install.sh and selection.sh calls the preview, prompt or write functions" {
    run prompt_callers "$REPO_ROOT"
    [ -z "$output" ] || { echo "$output"; return 1; }
    grep -q 'selection_preview' "$REPO_ROOT/ops/install.sh"
}

@test "AC7g: seeded: a call from update-all.sh, bootstrap.sh or hm-switch.sh is caught" {
    local copy="$BATS_TEST_TMPDIR/seed"
    mkdir -p "$copy/ops/lib"
    cp "$REPO_ROOT/ops/install.sh" "$REPO_ROOT/ops/update-all.sh" "$copy/ops/"
    cp "$REPO_ROOT/ops/lib/selection.sh" "$REPO_ROOT/ops/lib/hm-switch.sh" "$copy/ops/lib/"
    run prompt_callers "$copy"
    [ -z "$output" ]
    printf '\nselection_preview\n' >>"$copy/ops/update-all.sh"
    printf '\nselection_write x work\n' >>"$copy/ops/lib/hm-switch.sh"
    run prompt_callers "$copy"
    [[ "$output" == *"ops/update-all.sh"* ]]
    [[ "$output" == *"ops/lib/hm-switch.sh"* ]]
}

@test "AC7g: sourcing selection.sh does not load the preview code" {
    run env -i PATH="$TPATH" bash -c 'source "$1/ops/lib/selection.sh"; declare -F package_delta render_package_delta nix_toplevel_packages' _ "$REPO_ROOT"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
    run env -i PATH="$TPATH" bash -c 'source "$1/ops/lib/hm-switch.sh"; declare -F render_package_delta' _ "$REPO_ROOT"
    [ "$status" -ne 0 ]
}

# ── selection_write, selection_hm_profile and special paths ─────────────────

@test "selection_write writes only deltas through a temp file and mv" {
    run env -i PATH="$TPATH" bash -c '
        set -euo pipefail
        source "$1/ops/lib/selection.sh"
        selection_write "$2/a b" work media=false go=true security=false
        cat "$2/a b/selection.toml"
        selection_write "$2/a b" personal
        printf "%s\n" ---; cat "$2/a b/selection.toml"
        ls -A "$2/a b"' _ "$REPO_ROOT" "$BATS_TEST_TMPDIR"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'profile = "work"\n\n[groups]\nmedia = false\nsecurity = false\n---\nprofile = "personal"\nselection.toml')" ]
}

@test "selection_write refuses an unknown profile or group and leaves an existing file alone" {
    mkdir -p "$APP_CONFIGS_SELECTION_DIR"; printf 'profile = "work"\n' >"$APP_CONFIGS_SELECTION_DIR/selection.toml"
    run env -i PATH="$TPATH" APP_CONFIGS_SELECTION_DIR="$APP_CONFIGS_SELECTION_DIR" bash -c '
        source "$1/ops/lib/selection.sh"
        selection_write "$APP_CONFIGS_SELECTION_DIR" bogus; echo "rc1=$?"
        selection_write "$APP_CONFIGS_SELECTION_DIR" work "x y=false"; echo "rc2=$?"
        selection_write "$APP_CONFIGS_SELECTION_DIR" work "media=maybe"; echo "rc3=$?"' _ "$REPO_ROOT"
    printf '%s\n' "$output" | grep -qx 'rc1=1'
    printf '%s\n' "$output" | grep -qx 'rc2=1'
    printf '%s\n' "$output" | grep -qx 'rc3=1'
    [ "$(sel_text)" = 'profile = "work"' ]
    [ "$(ls -A "$APP_CONFIGS_SELECTION_DIR")" = selection.toml ]
}

@test "selection_hm_profile mirrors update-all: the XDG state profile, else the per-user Nix profile" {
    run env -i PATH="$TPATH" HOME="$HOME_T" bash -c 'source "$1/ops/lib/selection.sh"; selection_hm_profile; echo "rc=$?"' _ "$REPO_ROOT"
    [[ "$output" == *"rc=1"* ]]
    mkdir -p "$HOME_T/.local/state/nix/profiles"
    run env -i PATH="$TPATH" HOME="$HOME_T" bash -c 'source "$1/ops/lib/selection.sh"; selection_hm_profile' _ "$REPO_ROOT"
    [ "$output" = "$HOME_T/.local/state/nix/profiles/home-manager" ]
    rm -r "$HOME_T/.local/state"
    mkdir -p "$BATS_TEST_TMPDIR/nixstate/profiles/per-user/zed"
    run env -i PATH="$TPATH" HOME="$HOME_T" USER=zed NIX_STATE_DIR="$BATS_TEST_TMPDIR/nixstate" bash -c 'source "$1/ops/lib/selection.sh"; selection_hm_profile' _ "$REPO_ROOT"
    [ "$output" = "$BATS_TEST_TMPDIR/nixstate/profiles/per-user/zed/home-manager" ]
}

@test "a selection directory with a space works end to end: write, then the switch arguments" {
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/my sel"
    inst --profile work
    [ "$status" -eq 0 ]
    [ "$(sel_text)" = 'profile = "work"' ]
    grep -q "^home-manager switch -b hm-bak --flake $FAKE/nix#linux-desktop --override-input selection path:$BATS_TEST_TMPDIR/my%20sel\$" "$STUB_LOG"
    : >"$STUB_LOG"
    inst
    [ "$status" -eq 0 ]
    grep -q "^nix eval .*--override-input selection path:$BATS_TEST_TMPDIR/my%20sel " "$STUB_LOG"
}

@test "the existing install.sh usage text documents --profile and --reconfigure" {
    run bash "$REPO_ROOT/ops/install.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--profile"* ]]
    [[ "$output" == *"--reconfigure"* ]]
}

# ── review round 1 ──────────────────────────────────────────────────────────

@test "the Nix error shown for an invalid selection is the end of a long error, with the key (plain run, dry run, --profile)" {
    write_sel 'bogus = 1\n'
    inst
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown key 'bogus'"* ]]
    inst --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown key 'bogus'"* ]]
    export STUB_NIX_FAIL_OVERRIDE=1
    inst --profile work
    [ "$status" -eq 1 ]
    [[ "$output" == *"stub: evaluating the proposed selection failed"* ]]
}

@test "N1: an empty --profile value is a usage error" {
    inst --profile ""
    [ "$status" -eq 2 ]
    [ ! -s "$STUB_LOG" ]
    inst --profile=
    [ "$status" -eq 2 ]
    [ ! -s "$STUB_LOG" ]
    no_sel_file
}

@test "N2: after a in a dry run the output says the real run then passes the override" {
    inst_tty 'work\n\n\n\na\n' --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"the real run then passes --override-input selection path:$APP_CONFIGS_SELECTION_DIR"* ]]
}

@test "N4: on a first install the selection comparison lists no removals of what was never installed" {
    inst --profile work --dry-run
    [ "$status" -eq 0 ]
    local s
    s="$(section 'Packages, from your selection')"
    [[ "$s" == *"nothing is installed yet"* ]]
    [[ "$s" != *"REMOVED"* ]]
    [[ "$s" != *"removed"* ]]
}

@test "N6: the Selection line shows the profile of single-quoted and empty files" {
    write_sel "profile = 'work'\n"
    inst
    [[ "$output" == *"Selection: $APP_CONFIGS_SELECTION_DIR/selection.toml (profile work)"* ]]
    write_sel ''
    inst
    [ "$status" -eq 0 ]
    [[ "$output" == *"selection.toml (profile default)"* ]]
    [[ "$output" != *"(profile )"* ]]
}

# The install-time selection code runs under /bin/bash 3.2 on a fresh Mac: the
# same flows with mapfile and readarray switched off (BASH_ENV runs in every
# bash child). HOST_PROFILE=macos for the prompt path, as on that machine.
no_mapfile() {
    printf 'enable -n mapfile readarray\n' >"$BATS_TEST_TMPDIR/no-mapfile.sh"
    export BASH_ENV="$BATS_TEST_TMPDIR/no-mapfile.sh"
}

@test "F2: --profile works with mapfile and readarray disabled (bash 3.2 simulation)" {
    no_mapfile
    install_gen committed
    inst --profile work --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Preview (nothing applied): profile personal -> work"* ]]
    [[ "$output" == *"personal apps"*"remove 7"* ]]
}

@test "F2: the prompt path works with mapfile and readarray disabled, on macOS" {
    no_mapfile
    with_brew
    printf 'rectangle\n' >"$BATS_TEST_TMPDIR/casks"; export STUB_BREW_CASKS="$BATS_TEST_TMPDIR/casks"
    HP=macos inst_tty 'work\n\n\nn\n\na\n' --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"dry run: would write"* ]]
    [[ "$output" == *"macOS casks"* ]]
}

@test "F2: an invalid-file reconfigure and a plain apply work with mapfile disabled" {
    no_mapfile
    write_sel 'profile = "work"\n'
    inst
    [ "$status" -eq 0 ]
    inst_tty '\n\n\n\na\n' --reconfigure
    [ "$status" -eq 0 ]
}
