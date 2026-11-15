#!/usr/bin/env bats
# sys-install remembers linux-desktop versus linux-cli per machine (T-0044 T2):
# the --host flag, the one question on a TTY, --reconfigure, the dry run and the
# no-TTY hint. The file itself is read by ops/detect-host.sh
# (tests/bash/detect-host.bats); only install.sh writes it.
#
# Same fixture pattern as install-selection.bats: a scratch copy of install.sh
# with stubbed nix, chezmoi and friends, a PATH of stubs, TTY flows under
# script(1). The host file is always pinned with APP_CONFIGS_HOST_FILE and the
# selection with a pre-written selection.toml, so only the host question is
# asked (except the --reconfigure test, which answers both).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIXD="$BATS_TEST_DIRNAME/fixtures/selection"
    UNAME=utmostcreator
    HOME_T="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME_T"
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/sel"
    HF="$BATS_TEST_TMPDIR/cfg/app-configs/host"
    export APP_CONFIGS_HOST_FILE="$HF"
    unset HOST_PROFILE HOST_PROFILE_DEFAULT XDG_CONFIG_HOME WSL_DISTRO_NAME NIX_CONFIG \
        WAYLAND_DISPLAY DISPLAY XDG_SESSION_TYPE STUB_NIX_FAIL_OVERRIDE STUB_NIX_EVAL_FAIL \
        STUB_NIX_STORE_FAIL STUB_CHEZMOI_STATUS STUB_CHEZMOI_STATUS_FAIL STUB_BREW_CASKS STUB_REFS_FILE
    export XDG_STATE_HOME="$HOME_T/.local/state"
    export DETECT_HOST_WSL_RUN="$BATS_TEST_TMPDIR/no-wsl-run" DETECT_HOST_WSL_INTEROP="$BATS_TEST_TMPDIR/no-wsl-interop"
    export DETECT_HOST_PROC_VERSION="$BATS_TEST_TMPDIR/proc-version" DETECT_HOST_OSRELEASE="$BATS_TEST_TMPDIR/osrelease"
    kernel 6.18.33
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
        mkdir tee tr rm cp mv chmod ls readlink basename sleep date wc cut id comm \
        mktemp ln script timeout sh touch diff sha256sum tty stty seq paste; do
        p="$(command -v "$t" 2>/dev/null)" || continue
        if [ -x "$p" ]; then ln -sf "$p" "$SYSBIN/$t"; fi
    done
    printf '#!/bin/sh\necho Linux\n' >"$STUBS/uname"; chmod +x "$STUBS/uname"
    # systemctl get-default answers STUB_DEFAULT_TARGET (empty: no answer, exit 1).
    printf '#!/bin/sh\n[ "$1" = get-default ] && [ -n "${STUB_DEFAULT_TARGET:-}" ] && echo "$STUB_DEFAULT_TARGET" && exit 0\nexit 1\n' >"$STUBS/systemctl"
    chmod +x "$STUBS/systemctl"
    TPATH="$STUBS:$SYSBIN"
    HENV=()
    make_fake
    write_sel 'profile = "work"\n'
}

kernel() { # kernel <release>
    echo "$1" >"$DETECT_HOST_OSRELEASE"
    echo "Linux version $1 (builder@host) (gcc) #1 SMP" >"$DETECT_HOST_PROC_VERSION"
}

make_fake() {
    FAKE="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FAKE/ops" "$FAKE/nix/vars" "$FAKE/nix/profiles" "$FAKE/home/.chezmoidata" "$FAKE/.git"
    cp "$REPO_ROOT/ops/install.sh" "$REPO_ROOT/ops/detect-host.sh" "$REPO_ROOT/ops/update-version-report.sh" "$FAKE/ops/"
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

write_sel() {
    mkdir -p "$APP_CONFIGS_SELECTION_DIR"
    printf '%b' "$1" >"$APP_CONFIGS_SELECTION_DIR/selection.toml"
}

# hinst <args>: install.sh without a TTY and without HOST_PROFILE; HENV adds env.
hinst() {
    run env HOME="$HOME_T" PATH="$TPATH" USER="$UNAME" ${HENV[@]+"${HENV[@]}"} \
        bash "$FAKE/ops/install.sh" "$@" </dev/null
}

# hinst_tty <answers> <args>: stdin and stderr on a pty (see install-selection.bats).
hinst_tty() {
    local answers="$1"
    shift
    run env SHELL="$(command -v bash)" bash -c 'printf "%b" "$1" | timeout 60 script -qec "$2" /dev/null' _ "$answers" \
        "env HOME=$HOME_T PATH=$TPATH USER=$UNAME ${HENV[*]:-} bash $FAKE/ops/install.sh $*"
    output="${output//$'\r'/}"
}

no_host_file() { [ ! -e "$HF" ]; }
host_dir_clean() { # nothing but the host file (no temp file left behind)
    [ "$(ls -A "$(dirname "$HF")" 2>/dev/null)" = host ]
}
no_mutation() {
    if grep -Eq '^(chezmoi .*(apply|init)|home-manager|mise|lefthook)' "$STUB_LOG"; then
        grep -E '^(chezmoi|home-manager|mise|lefthook)' "$STUB_LOG"
        return 1
    fi
}

# -- the question, on a TTY ----------------------------------------------------

@test "TTY, no file, graphical session: asks once, Enter takes linux-desktop and writes it" {
    HENV=(WAYLAND_DISPLAY=wayland-1)
    hinst_tty '\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[linux-desktop]"* ]]
    [[ "$output" == *"no remembered host"* ]]
    [ "$(cat "$HF")" = linux-desktop ]
    host_dir_clean
    [[ "$output" == *"Host:  linux-desktop"* ]]
    [[ "$output" == *"Source: "* ]]
}

@test "the default comes from DISPLAY, and from XDG_SESSION_TYPE x11, wayland or mir" {
    local env
    for env in DISPLAY=:0 XDG_SESSION_TYPE=x11 XDG_SESSION_TYPE=wayland XDG_SESSION_TYPE=mir; do
        rm -rf "$(dirname "$HF")"
        HENV=("$env")
        hinst_tty '\n'
        [ "$status" -eq 0 ] || { echo "$env: status $status"; return 1; }
        [[ "$output" == *"[linux-desktop]"* ]] || { echo "$env: $output"; return 1; }
        [ "$(cat "$HF")" = linux-desktop ]
    done
}

@test "no display signal, no graphical target: default linux-cli; Enter writes it" {
    hinst_tty '\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[linux-cli]"* ]]
    [ "$(cat "$HF")" = linux-cli ]
    host_dir_clean
}

@test "XDG_SESSION_TYPE=tty is not a display signal" {
    HENV=(XDG_SESSION_TYPE=tty)
    hinst_tty '\n'
    [[ "$output" == *"[linux-cli]"* ]]
}

@test "no display signal but systemctl get-default is graphical.target: default linux-desktop" {
    HENV=(STUB_DEFAULT_TARGET=graphical.target)
    hinst_tty '\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[linux-desktop]"* ]]
    [ "$(cat "$HF")" = linux-desktop ]
}

@test "systemctl multi-user.target is not graphical" {
    HENV=(STUB_DEFAULT_TARGET=multi-user.target)
    hinst_tty '\n'
    [[ "$output" == *"[linux-cli]"* ]]
}

@test "an explicit answer beats the heuristic" {
    HENV=(WAYLAND_DISPLAY=wayland-1)
    hinst_tty 'linux-cli\n'
    [ "$status" -eq 0 ]
    [ "$(cat "$HF")" = linux-cli ]
    [[ "$output" == *"Host:  linux-cli"* ]]
}

@test "an invalid answer is asked again, not written" {
    hinst_tty 'wsl\nbogus\nlinux-desktop\n'
    [ "$status" -eq 0 ]
    [ "$(cat "$HF")" = linux-desktop ]
}

@test "q at the host prompt exits 1 before any mutation and writes nothing" {
    hinst_tty 'q\n'
    [ "$status" -eq 1 ]
    no_host_file
    no_mutation
    [[ "$output" != *"Nix"*"──"* ]]
}

@test "end of input at the host prompt exits 1 before any mutation and writes nothing" {
    hinst_tty ''
    [ "$status" -eq 1 ]
    no_host_file
    no_mutation
}

@test "an existing file is used silently on a TTY: no question, no write" {
    mkdir -p "$(dirname "$HF")"; echo linux-cli >"$HF"
    HENV=(WAYLAND_DISPLAY=wayland-1)
    hinst_tty ''
    [ "$status" -eq 0 ]
    [[ "$output" == *"Host:  linux-cli"* ]]
    [[ "$output" == *"Source: file"* ]]
    [[ "$output" != *"no remembered host"* ]]
    [ "$(cat "$HF")" = linux-cli ]
}

# -- no TTY ------------------------------------------------------------------------

@test "no TTY, no file: no question, no write, a hint, exit 0" {
    hinst
    [ "$status" -eq 0 ]
    no_host_file
    [[ "$output" == *"sys-install --host linux-cli"* ]]
    [[ "$output" == *"Host:  linux-desktop"* ]]
}

@test "no TTY, no file, dry run: also no write and the hint" {
    hinst --dry-run
    [ "$status" -eq 0 ]
    no_host_file
    [[ "$output" == *"sys-install --host linux-cli"* ]]
}

@test "no TTY with an existing file: no hint" {
    mkdir -p "$(dirname "$HF")"; echo linux-cli >"$HF"
    hinst
    [ "$status" -eq 0 ]
    [[ "$output" != *"sys-install --host linux-cli"* ]]
    [[ "$output" == *"Host:  linux-cli"* ]]
}

# -- --host ------------------------------------------------------------------------------

@test "--host linux-cli writes the file (parent created), uses it and asks nothing" {
    hinst --host linux-cli
    [ "$status" -eq 0 ]
    [ "$(cat "$HF")" = linux-cli ]
    [ "$(wc -l <"$HF")" -eq 1 ]
    host_dir_clean
    [[ "$output" == *"Host:  linux-cli"* ]]
}

@test "--host=linux-desktop on a TTY writes without a question" {
    hinst_tty '' --host=linux-desktop
    [ "$status" -eq 0 ]
    [ "$(cat "$HF")" = linux-desktop ]
    [[ "$output" != *"remembered host"* ]]
}

@test "--host overwrites an invalid file (the fix the error message names)" {
    mkdir -p "$(dirname "$HF")"; echo junk >"$HF"
    hinst --host linux-cli
    [ "$status" -eq 0 ]
    [ "$(cat "$HF")" = linux-cli ]
    host_dir_clean
}

@test "--host with a host file path that is a directory (or a symlink to one) fails and leaves nothing inside" {
    mkdir -p "$HF"
    hinst --host linux-cli
    [ "$status" -eq 1 ]
    [[ "$output" == *"$HF is a directory; remove it"* ]]
    [[ "$output" != *"wrote"* ]]
    [ -z "$(ls -A "$HF")" ]
    rmdir "$HF"
    mkdir -p "$BATS_TEST_TMPDIR/realdir"
    ln -s "$BATS_TEST_TMPDIR/realdir" "$HF"
    hinst --host linux-cli
    [ "$status" -eq 1 ]
    [[ "$output" == *"is a directory; remove it"* ]]
    [ -z "$(ls -A "$BATS_TEST_TMPDIR/realdir")" ]
}

@test "the host file's temp file is registered for cleanup right after mktemp" {
    grep -A1 'tmp="$(mktemp "$dir/.host.XXXXXX")"' "$REPO_ROOT/ops/install.sh" | grep -q 'CLEANUP+=("$tmp")'
}

@test "a valid HOST_PROFILE_DEFAULT is the prompt's default, and the reason line says so" {
    HENV=(HOST_PROFILE_DEFAULT=linux-cli WAYLAND_DISPLAY=wayland-1)
    hinst_tty '\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[linux-cli]"* ]]
    [[ "$output" == *"default from HOST_PROFILE_DEFAULT"* ]]
    [ "$(cat "$HF")" = linux-cli ]
}

@test "without HOST_PROFILE_DEFAULT the reason line does not claim it" {
    HENV=(WAYLAND_DISPLAY=wayland-1)
    hinst_tty '\n'
    [[ "$output" != *"HOST_PROFILE_DEFAULT"* ]]
}

@test "--host --dry-run writes nothing and says what it would write" {
    hinst --host linux-cli --dry-run
    [ "$status" -eq 0 ]
    no_host_file
    [[ "$output" == *"dry run: would write $HF (linux-cli)"* ]]
    [[ "$output" == *"Host:  linux-cli"* ]]
}

@test "--host with an unknown or empty value exits 2 before any step and writes nothing" {
    local v
    for v in wsl macos bogus ''; do
        hinst --host "$v"
        [ "$status" -eq 2 ] || { echo "[$v]: status $status"; return 1; }
        [[ "$output" == *"--host needs linux-desktop or linux-cli"* ]]
        [[ "$output" != *"Preflight"* ]]
        no_host_file
    done
    hinst --host
    [ "$status" -eq 2 ]
    [[ "$output" == *"--host needs linux-desktop or linux-cli"* ]]
    no_host_file
}

@test "--host with a conflicting HOST_PROFILE exits 2 and writes nothing" {
    HENV=(HOST_PROFILE=linux-desktop)
    hinst --host linux-cli
    [ "$status" -eq 2 ]
    [[ "$output" == *"--host linux-cli conflicts with HOST_PROFILE=linux-desktop"* ]]
    no_host_file
}

@test "--host on a detected WSL2 host exits 2 before any step and writes nothing" {
    kernel 6.6.87.2-microsoft-standard-WSL2
    hinst --host linux-cli
    [ "$status" -eq 2 ]
    [[ "$output" == *"plain Linux only"* ]]
    [[ "$output" != *"Preflight"* ]]
    no_host_file
}

@test "--host X with HOST_PROFILE=X is still refused on WSL2 and on macOS (the probe always runs)" {
    HENV=(HOST_PROFILE=linux-cli)
    kernel 6.6.87.2-microsoft-standard-WSL2
    hinst --host linux-cli
    [ "$status" -eq 2 ]
    [[ "$output" == *"plain Linux only"* ]]
    no_host_file
    kernel 6.18.33
    printf '#!/bin/sh\necho Darwin\n' >"$STUBS/uname"
    hinst --host linux-cli
    [ "$status" -eq 2 ]
    [[ "$output" == *"plain Linux only"* ]]
    no_host_file
}

@test "--host on a detected macOS host exits 2 and writes nothing" {
    printf '#!/bin/sh\necho Darwin\n' >"$STUBS/uname"
    hinst --host linux-cli
    [ "$status" -eq 2 ]
    [[ "$output" == *"plain Linux only"* ]]
    no_host_file
}

# -- HOST_PROFILE, WSL, macOS never ask -------------------------------------------

@test "HOST_PROFILE set: no question and no write, even on a TTY and with --reconfigure" {
    HENV=(HOST_PROFILE=linux-cli)
    hinst_tty '\n\n\n\na\n' --reconfigure
    [ "$status" -eq 0 ]
    [[ "$output" != *"remembered host"* ]]
    [[ "$output" != *"linux-desktop|linux-cli"* ]]
    [[ "$output" == *"Host:  linux-cli"* ]]
    no_host_file
}

@test "WSL2 never asks and never writes, with --reconfigure too" {
    kernel 6.6.87.2-microsoft-standard-WSL2
    hinst_tty '\n\n\n\na\n' --reconfigure --dry-run
    [[ "$output" != *"remembered host"* ]]
    [[ "$output" != *"linux-desktop|linux-cli"* ]]
    [[ "$output" == *"Host:  wsl"* ]]
    no_host_file
}

# -- --reconfigure ----------------------------------------------------------------------

@test "--reconfigure asks the host first, defaulting to the current file value, then the selection" {
    mkdir -p "$(dirname "$HF")"; echo linux-cli >"$HF"
    HENV=(WAYLAND_DISPLAY=wayland-1)
    hinst_tty '\n\n\n\n\na\n' --reconfigure
    [ "$status" -eq 0 ]
    [[ "$output" == *"--reconfigure"* ]]
    [[ "$output" == *"[linux-cli]"* ]]
    [ "$(cat "$HF")" = linux-cli ]
    # host question precedes the selection prompt
    local host_pos sel_pos
    host_pos="$(printf '%s' "$output" | grep -bo 'linux-desktop|linux-cli' | head -n1 | cut -d: -f1)"
    sel_pos="$(printf '%s' "$output" | grep -bo 'Profile (' | head -n1 | cut -d: -f1)"
    [ -n "$host_pos" ] && [ -n "$sel_pos" ] && [ "$host_pos" -lt "$sel_pos" ]
}

@test "--reconfigure can change the remembered host" {
    mkdir -p "$(dirname "$HF")"; echo linux-cli >"$HF"
    hinst_tty 'linux-desktop\n\n\n\n\na\n' --reconfigure
    [ "$status" -eq 0 ]
    [ "$(cat "$HF")" = linux-desktop ]
    host_dir_clean
}

@test "--reconfigure without a file asks with the heuristic default" {
    HENV=(DISPLAY=:0)
    hinst_tty '\n\n\n\n\na\n' --reconfigure
    [ "$status" -eq 0 ]
    [[ "$output" == *"[linux-desktop]"* ]]
    [ "$(cat "$HF")" = linux-desktop ]
}

@test "q at the --reconfigure host prompt exits 1 and leaves the file as it was" {
    mkdir -p "$(dirname "$HF")"; echo linux-cli >"$HF"
    hinst_tty 'q\n' --reconfigure
    [ "$status" -eq 1 ]
    [ "$(cat "$HF")" = linux-cli ]
    no_mutation
}

@test "--reconfigure --dry-run asks but writes nothing" {
    hinst_tty 'linux-cli\n\n\n\n\na\n' --reconfigure --dry-run
    [ "$status" -eq 0 ]
    no_host_file
    [[ "$output" == *"dry run: would write $HF (linux-cli)"* ]]
}

# -- an invalid file ---------------------------------------------------------------------

@test "an invalid host file stops the install with the detect-host message and is left alone" {
    mkdir -p "$(dirname "$HF")"; echo junk >"$HF"
    hinst
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid host file"* ]]
    [ "$(cat "$HF")" = junk ]
    no_mutation
}

# -- usage -------------------------------------------------------------------------------

@test "the install.sh usage text documents --host" {
    run bash "$REPO_ROOT/ops/install.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--host"* ]]
}

@test "under bats a host file outside the test scratch directory is refused (exit 3), nothing written" {
    local outside="$BATS_RUN_TMPDIR/outside-host-$BATS_TEST_NUMBER"
    HENV=(APP_CONFIGS_HOST_FILE="$outside")
    hinst --host linux-cli
    [ "$status" -eq 3 ]
    [[ "$output" == *"refusing to write the host file"* ]]
    [ ! -e "$outside" ]
}

# -- drift between the host file and personal.yaml (T-0044 T3) -----------------------
# chezmoi renders from home/.chezmoidata/personal.yaml (hostProfile, gui), not
# from the host file. When the host comes from the host file and personal.yaml
# disagrees, a warning says so BEFORE any chezmoi apply. It never edits the file.
# The check reads only the ^hostProfile: and ^gui: keys, here from fixtures.

pyaml() { # pyaml <hostProfile-line> <gui-line>: a fixture personal.yaml in $FAKE
    {
        printf 'name: Sentinel Name\nemail: sentinel@example.invalid\n# hostProfile: "ignored-comment"\n'
        [ -z "$1" ] || printf '%s\n' "$1"
        [ -z "$2" ] || printf '%s\n' "$2"
        printf 'signingKey: SENTINEL-KEY-VALUE\n'
    } >"$FAKE/home/.chezmoidata/personal.yaml"
}

drift() { # drift <repo> <profile>: run the library function, capture its lines
    run bash -c 'source "$1/ops/lib/preflight.sh"; preflight_host_data_drift "$2" "$3"' _ "$REPO_ROOT" "$FAKE" "$2"
}

@test "drift: consistent linux-cli prints nothing and returns 0" {
    pyaml 'hostProfile: "linux-cli"' 'gui: false'
    drift x linux-cli
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "drift: consistent linux-desktop prints nothing" {
    pyaml 'hostProfile: "linux-desktop"' 'gui: true'
    drift x linux-desktop
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "drift: a missing hostProfile counts as linux-desktop (the chezmoiignore default)" {
    pyaml '' 'gui: true'
    drift x linux-desktop
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    drift x linux-cli
    [ "$status" -eq 1 ]
    [[ "$output" == *'hostProfile: "linux-desktop"'* ]]
}

@test "drift: the warning shows the detected host, the configured values and the corrective action" {
    pyaml 'hostProfile: "linux-desktop"' 'gui: true'
    drift x linux-cli
    [ "$status" -eq 1 ]
    [[ "$output" == *"detected host: linux-cli"* ]]
    [[ "$output" == *'hostProfile: "linux-desktop"'* ]]
    [[ "$output" == *"gui: true"* ]]
    [[ "$output" == *'set hostProfile: "linux-cli" and gui: false'* ]]
    [[ "$output" == *"chezmoi apply"* ]]
    [[ "$output" == *"personal.yaml"* ]]
}

@test "drift: a gui mismatch alone is reported, with the value linux-desktop needs" {
    pyaml 'hostProfile: "linux-desktop"' 'gui: false'
    drift x linux-desktop
    [ "$status" -eq 1 ]
    [[ "$output" == *"gui: false"* ]]
    [[ "$output" == *'set hostProfile: "linux-desktop" and gui: true'* ]]
}

@test "drift: a missing gui counts as false" {
    pyaml 'hostProfile: "linux-desktop"' ''
    drift x linux-desktop
    [ "$status" -eq 1 ]
    [[ "$output" == *"gui: false"* ]]
}

@test "drift: reads only hostProfile and gui, never prints other keys, never edits the file" {
    pyaml 'hostProfile: "linux-desktop"' 'gui: true'
    local before; before="$(sha256sum "$FAKE/home/.chezmoidata/personal.yaml")"
    drift x linux-cli
    [[ "$output" != *Sentinel* && "$output" != *SENTINEL* && "$output" != *ignored-comment* ]]
    [ "$(sha256sum "$FAKE/home/.chezmoidata/personal.yaml")" = "$before" ]
}

@test "drift: unquoted values and trailing comments are read" {
    pyaml 'hostProfile: linux-cli   # note' 'gui: false # none'
    drift x linux-cli
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "drift: no personal.yaml means nothing to compare" {
    rm -f "$FAKE/home/.chezmoidata/personal.yaml"
    drift x linux-cli
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "install: a host file that disagrees with personal.yaml warns before chezmoi runs and edits nothing" {
    mkdir -p "$(dirname "$HF")"; echo linux-cli >"$HF"
    pyaml 'hostProfile: "linux-desktop"' 'gui: true'
    local before; before="$(sha256sum "$FAKE/home/.chezmoidata/personal.yaml")"
    hinst
    [ "$status" -eq 0 ]
    [[ "$output" == *"detected host: linux-cli"* ]]
    [[ "$output" == *'set hostProfile: "linux-cli" and gui: false'* ]]
    local warn_pos chezmoi_pos
    warn_pos="$(printf '%s' "$output" | grep -bo 'detected host: linux-cli' | head -n1 | cut -d: -f1)"
    chezmoi_pos="$(printf '%s' "$output" | grep -bo 'chezmoi (init' | head -n1 | cut -d: -f1)"
    [ "$warn_pos" -lt "$chezmoi_pos" ]
    [ "$(sha256sum "$FAKE/home/.chezmoidata/personal.yaml")" = "$before" ]
    # the chezmoi apply stub ran only after the warning, never with a changed file
    grep -q '^chezmoi' "$STUB_LOG"
}

@test "install: --host that disagrees with personal.yaml warns too (the file is now the source)" {
    pyaml 'hostProfile: "linux-desktop"' 'gui: true'
    hinst --host linux-cli --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"detected host: linux-cli"* ]]
}

@test "install: no warning when personal.yaml agrees, or when the host did not come from the file" {
    mkdir -p "$(dirname "$HF")"; echo linux-cli >"$HF"
    pyaml 'hostProfile: "linux-cli"' 'gui: false'
    hinst
    [[ "$output" != *"detected host"* ]]
    rm -f "$HF"
    pyaml 'hostProfile: "linux-cli"' 'gui: false'
    hinst
    [[ "$output" != *"detected host"* ]]
    HENV=(HOST_PROFILE=linux-desktop)
    mkdir -p "$(dirname "$HF")"; echo linux-cli >"$HF"
    hinst
    [[ "$output" != *"detected host"* ]]
}
