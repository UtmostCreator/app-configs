#!/usr/bin/env bats
# Disk identities and mount topology here are synthetic. An unexpected
# privileged operation is a test failure even if the installer handles it.
bats_require_minimum_version 1.5.0

setup() {
    installer_script="$BATS_TEST_DIRNAME/../../ops/niri/install.sh"
    export FORBIDDEN="$BATS_TEST_TMPDIR/unexpected-operation"
    mkdir "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/forbidden" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${0##*/}" >> "$FORBIDDEN"
exit 99
SH
    chmod 755 "$BATS_TEST_TMPDIR/bin/forbidden"
    for tool in sudo wipefs mkfs cryptsetup mount umount nixos-install nixos-enter poweroff; do
        ln -s forbidden "$BATS_TEST_TMPDIR/bin/$tool"
    done
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

teardown() {
    [ ! -e "$FORBIDDEN" ]
}

load_installer() {
    source "$installer_script"
    scratch="$BATS_TEST_TMPDIR"
    log="$scratch/install.log"
    phase=fixture
    : > "$log"
}

disk_fixture() {
    installer=/dev/example-live
    disk=/dev/example-target
    target=/dev/disk/by-id/usb-example-complete-id
    selected_identity='8:9 12345 disk usb 0 serial-example'
    media_disk() { echo "$installer"; }
    disk_identity() { echo "${observed_identity:-$selected_identity}"; }
    readlink() {
        [[ "$1" == -e && "$2" == "$target" ]] || return 1
        echo "$disk"
    }
    lsblk() {
        [[ "$*" == *NAME,TYPE* ]] || return 1
        printf '%s disk\n' "$installer" "$disk"
        if [[ -n ${extra_disk:-} ]]; then printf '%s disk\n' "$extra_disk"; fi
    }
    swapon() { printf '%s' "${fixture_swap:-}"; }
}

@test "isolated media and target pass; a protected disk or changed identity blocks the installer" {
    load_installer
    disk_fixture
    run guard_isolation
    [ "$status" -eq 0 ]
    extra_disk=/dev/example-existing-system
    run guard_isolation
    [ "$status" -ne 0 ]
    unset extra_disk
    fixture_swap=/dev/zram0
    run guard_isolation
    [ "$status" -eq 0 ]
    fixture_swap=/dev/example-target1
    run guard_isolation
    [ "$status" -ne 0 ]
    unset fixture_swap
    observed_identity='8:9 12345 disk usb 0 another-serial'
    run guard_isolation
    [ "$status" -ne 0 ]
}

mount_fixture() {
    disk=/dev/example-target
    selected_identity='example target'
    disk_identity() { echo "$selected_identity"; }
    readlink() {
        [[ "$1" == -e ]] || return 1
        case "$2" in
            /dev/mapper/linux-niri-root) echo /dev/example-crypt ;;
            /dev/disk/by-partlabel/linux-niri-esp) echo /dev/example-esp ;;
            /dev/example-crypt|/dev/example-esp) echo "$2" ;;
            *) return 1 ;;
        esac
    }
    lsblk() { printf '%s disk\n' "$disk"; }
    findmnt() {
        case "$*" in
            *FSTYPE*'/mnt/boot') echo vfat ;;
            *FSTYPE*'/mnt') echo ext4 ;;
            *SOURCE*'/mnt/boot') echo /dev/example-esp ;;
            *SOURCE*'/mnt') echo /dev/example-crypt ;;
            *OPTIONS*'/mnt/boot') echo rw,relatime ;;
            *OPTIONS*'/mnt') echo "$root_options" ;;
            *) return 1 ;;
        esac
    }
}

@test "verified target mounts reject both read-only ext4 and emergency_ro alongside rw" {
    load_installer
    mount_fixture
    root_options=rw,relatime
    run verify_mounts
    [ "$status" -eq 0 ]
    for options in ro,relatime rw,relatime,emergency_ro; do
        root_options=$options
        run verify_mounts
        [ "$status" -ne 0 ]
    done
}

@test "installer rejects incomplete explicit installation request before probing a disk" {
    run bash "$installer_script" --install
    [ "$status" -eq 2 ]
}

@test "logged command failure retains its exit status" {
    load_installer
    command_failure() { echo 'fixture diagnostic'; return 23; }
    run run_logged 'Fixture copy' command_failure
    [ "$status" -eq 23 ]
    grep -Fq 'fixture diagnostic' "$log"
    grep -Fq 'command_exit=23 logger_exit=0' "$log"
}

@test "a logger failure prevents reporting a successful stage" {
    load_installer
    tee() { cat >/dev/null; return 17; }
    run run_logged 'Fixture copy' true
    [ "$status" -eq 17 ]
    grep -Fq 'command_exit=0 logger_exit=17' "$log"
    command_failure() { return 23; }
    run run_logged 'Fixture copy' command_failure
    [ "$status" -eq 23 ]
    grep -Fq 'command_exit=23 logger_exit=17' "$log"
}

@test "fresh-install target must have neither partitions nor a whole-disk signature" {
    load_installer
    disk_fixture
    topology=disk
    lsblk() {
        [[ "$*" == "-nr -o TYPE $disk" ]] || return 1
        printf '%s\n' "$topology"
    }
    sudo() {
        if [[ "$*" != "-n wipefs --noheadings --output TYPE -- $target" ]]; then
            echo "unexpected command" >> "$FORBIDDEN"
            return 99
        fi
        printf '%s' "${signature:-}"
        return "${probe_status:-0}"
    }
    run blank_target
    [ "$status" -eq 0 ]
    signature=crypto_LUKS
    run blank_target
    [ "$status" -ne 0 ]
    unset signature
    topology=$'disk\npart'
    run blank_target
    [ "$status" -ne 0 ]
    topology=disk
    probe_status=5
    run blank_target
    [ "$status" -ne 0 ]
}

@test "partial identity, an empty response and EOF cancel before erase confirmation" {
    load_installer
    disk_fixture
    guard_fresh_target() { return 0; }
    lsblk() { echo fixture; }
    fail() { exit "$1"; }
    revision=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    for response in ERASE-570AD ''; do
        run confirm_erase <<< "$response"
        [ "$status" -eq 2 ]
    done
    run confirm_erase < /dev/null
    [ "$status" -eq 2 ]
    run confirm_erase <<< "$target"
    [ "$status" -eq 0 ]
}

@test "default invocation stops after the disk scan" {
    load_installer
    preflight() { installer=/dev/example-live; }
    mktemp() { command mktemp -d "$BATS_TEST_TMPDIR/live.XXXXXXXX"; }
    inventory() { echo 'fixture inventory displayed'; }
    select_disk() { echo selection >> "$FORBIDDEN"; exit 99; }
    run main
    [ "$status" -eq 0 ]
    [[ "$output" == *'fixture inventory displayed'* ]]
}

@test "an unwritable stage log fails even when the installer command succeeds" {
    load_installer
    log="$BATS_TEST_TMPDIR/nonexistent/install.log"
    run run_logged 'Fixture copy' true
    [ "$status" -ne 0 ]
    [[ "$output" == *"$log"* ]]
}

@test "interrupted disk preparation reports uncertain writes and does not retry" {
    load_installer
    prepare=/fixture/disko-format-mount
    preparation=unstarted
    copy_state=unstarted
    target_mounted=false
    guard_fresh_target() { return 0; }
    sudo() {
        [[ "$*" == *'timeout --foreground '* && "${!#}" == "$prepare" ]] || return 99
        echo attempted >> "$scratch/attempts"
        return 130
    }
    run prepare_disk
    [ "$status" -eq 130 ]
    [ "$(wc -l < "$scratch/attempts")" -eq 1 ]
    [[ "$output" == *'changes unknown'* ]]
    [[ "$output" == *'First boot: unverified'* ]]
}

@test "a failed exit-record write cannot hide the command's own failure" {
    load_installer
    log="$scratch/no-such-directory/install.log"
    command_failure() { return 23; }
    run run_logged 'Fixture copy' command_failure
    [ "$status" -eq 23 ]
    [[ "$output" == *'command_exit=23'* ]]
}

@test "after verified mounts the copy reaches both logs and target logger failures remain visible" {
    load_installer
    persisted_log="$scratch/target-install.log"
    verify_mounts() { return "${mount_status:-0}"; }
    sudo() {
        [[ "$*" == "-n tee -a -- $persisted_log" ]] || {
            echo 'unexpected privileged operation' >> "$FORBIDDEN"
            return 99
        }
        cat >> "$persisted_log"
        return "${target_log_status:-0}"
    }
    command_copy() {
        echo invoked >> "$scratch/copy-attempts"
        echo 'copy fixture output'
    }
    run run_logged system-copy command_copy
    [ "$status" -eq 0 ]
    grep -Fxq 'copy fixture output' "$persisted_log"
    grep -Fxq 'copy fixture output' "$log"
    target_log_status=29
    run run_logged system-copy command_copy
    [ "$status" -eq 29 ]
    grep -Fq 'command_exit=0 logger_exit=0 target_logger_exit=29' "$log"

    mount_status=1
    run run_logged system-copy command_copy
    [ "$status" -ne 0 ]
    [ "$(wc -l < "$scratch/copy-attempts")" -eq 2 ]
}

@test "a complete install request still requires an interactive normal-user console" {
    run bash "$installer_script" --install --target /dev/disk/by-id/usb-example \
        --revision aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
        --system /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-nixos-system-linux-niri-fixture </dev/null
    [ "$status" -eq 2 ]
    [[ "$output" == *interactive* ]]
}
