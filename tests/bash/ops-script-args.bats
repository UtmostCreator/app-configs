#!/usr/bin/env bats
# readiness.sh, doctor.sh, ci.sh and detect-host.sh used to ignore their
# arguments and run the full checks for `--help` or a typo. They now print
# usage for -h/--help and exit 2 for anything unknown, before doing any work.
#
# The scripts run from a scratch copy of ops/ whose heavy dependencies
# (validate-config, lint-shell, run-bats, doctor, ...) are marker-writing
# stubs, so even the pre-fix behaviour cannot recurse into the real suite.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    unset TMUX
    COPY="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$COPY/ops"
    local s
    for s in readiness doctor ci detect-host; do
        cp "$REPO_ROOT/ops/$s.sh" "$COPY/ops/$s.sh"
    done
    MARK="$BATS_TEST_TMPDIR/ran"; : >"$MARK"
    for s in validate-config lint-shell run-bats detect-timezone wsl-check; do
        printf '#!/usr/bin/env bash\necho "%s $*" >>"%s"\n' "$s" "$MARK" >"$COPY/ops/$s.sh"
    done
    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    for s in nix chezmoi systemctl mise git; do
        printf '#!/bin/sh\necho "%s $*" >>"%s"\nexit 1\n' "$s" "$MARK" >"$STUBS/$s"
        chmod +x "$STUBS/$s"
    done
}

SCRIPTS=(readiness doctor ci detect-host)

@test "--help and -h print usage, exit 0 and run nothing" {
    local s a
    for s in "${SCRIPTS[@]}"; do
        for a in --help -h; do
            run env PATH="$STUBS:$PATH" bash "$COPY/ops/$s.sh" "$a"
            [ "$status" -eq 0 ] || { echo "$s $a: status $status"; return 1; }
            [[ "$output" == *"Usage"* ]] || { echo "$s $a: no usage"; return 1; }
            [ ! -s "$MARK" ] || { echo "$s $a ran: $(cat "$MARK")"; return 1; }
        done
    done
}

@test "unknown arguments exit 2 or 64 and run nothing" {
    local s
    for s in "${SCRIPTS[@]}"; do
        run env PATH="$STUBS:$PATH" bash "$COPY/ops/$s.sh" --bogus
        # 2 (usage) or 64 (EX_USAGE, doctor and readiness) both mean "refused".
        [ "$status" -eq 2 ] || [ "$status" -eq 64 ] || { echo "$s: status $status"; return 1; }
        [ ! -s "$MARK" ] || { echo "$s ran: $(cat "$MARK")"; return 1; }
    done
}

@test "detect-host still accepts --wsl-version" {
    run bash "$COPY/ops/detect-host.sh" --wsl-version
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(1|2|none)$ ]]
}

@test "readiness: an unset USER does not produce 'unbound variable'" {
    [ -f /etc/NIXOS ] || skip "NixOS-only section"
    printf '#!/bin/sh\necho "x:x:1000:1000::/home/x:/run/current-system/sw/bin/fish"\n' >"$STUBS/getent"
    chmod +x "$STUBS/getent"
    run env -u USER PATH="$STUBS:$PATH" bash "$COPY/ops/readiness.sh"
    [[ "$output" != *"unbound variable"* ]]
}
