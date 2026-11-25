#!/usr/bin/env bats
# Exercise the normal-user entry point without mounting a disk or querying host services.

setup() {
    [[ $(uname -s) == Linux ]] || skip 'linux-niri requires Linux'
    command -v bwrap >/dev/null || skip 'bubblewrap unavailable for the isolated mount namespace'
    [[ $EUID -ne 0 ]] || skip 'first-boot verification requires an ordinary user'
    bwrap --ro-bind / / true 2>/dev/null || skip 'user mount namespaces unavailable'
    verifier="$BATS_TEST_DIRNAME/../../ops/niri/verify-first-boot.sh"
    dir="$BATS_TEST_TMPDIR"
    system=/nix/store/example-nixos-system-linux-niri-26.11
    revision=0000000000000000000000000000000000000001
    mkdir -p "$dir"/{bin,etc/app-configs,sys/dev/block,sys/devices/virtual/block/dm-8,sys/fs/ext4/{dm-8,other}}
    mkdir -p "$dir/profiles" "$dir/varlib/app-configs" "$dir/ids" "$dir/home/.config/niri"
    echo 'input {}' > "$dir/home/.config/niri/config.kdl"
    export XDG_CONFIG_HOME="$dir/home/.config"
    ln -s "$system" "$dir/profiles/system-42-link"
    touch "$dir/etc/app-configs/linux-niri"
    ln -s ../../devices/virtual/block/dm-8 "$dir/sys/dev/block/254:8"
    echo 0 > "$dir/sys/fs/ext4/dm-8/errors_count"
    echo 17 > "$dir/sys/fs/ext4/other/errors_count"
    echo 'ext4 rw,relatime 254:8' > "$dir/root-mount"
    (umask 077; mkdir -p "$dir"/home/{Projects/app-configs,Documents,Downloads,Pictures/Screenshots,Scratch/{temp,logs,benchmarks,reports,screenshots},Archive/{projects,snapshots,imports}})
    cat > "$dir/bin/mock" <<'MOCK'
#!/usr/bin/env bash
case "${0##*/} $*" in
    'readlink -e /run/current-system') echo "${MOCK_ACTIVE:-${MOCK_BOOTED:-$EXPECTED_SYSTEM}}" ;;
    'readlink -e /dev/disk/by-id/virtio-fixture') echo "${MOCK_RECEIPT_DEVICE:-/dev/sdb}" ;;
    'stat -c %u %a /var/lib/app-configs') echo "${MOCK_RECEIPT_DIR:-0 755}" ;;
    'stat -c %u %a /var/lib/app-configs/install-disk-id') echo "${MOCK_RECEIPT_OWNER_MODE:-0 444}" ;;
    'lsblk -dnro TYPE /dev/mapper/linux-niri-root') echo "${MOCK_MAPPER:-crypt}" ;;
    'readlink -e /run/booted-system') echo "${MOCK_BOOTED:-$EXPECTED_SYSTEM}" ;;
    'readlink -e /nix/var/nix/profiles/system-42-link') echo "$EXPECTED_SYSTEM" ;;
    'stat -c %u /nix/var/nix/profiles/system-42-link') echo "${MOCK_OWNER:-0}" ;;
    'stat '*) exec "$REAL_STAT" "$@" ;;
    'readlink '*) exec "$REAL_READLINK" "$@" ;;
    'findmnt -nro FSTYPE,OPTIONS,MAJ:MIN -M /') cat "$MOUNT_INFO" ;;
    'findmnt -nro MAJ:MIN -M /'|'lsblk -dnro MAJ:MIN /dev/mapper/linux-niri-root') echo 254:8 ;;
    'findmnt -nro MAJ:MIN -M /boot'|'lsblk -dnro MAJ:MIN /dev/disk/by-partlabel/linux-niri-esp') echo 8:1 ;;
    'findmnt -nro FSTYPE -M /boot') echo vfat ;;
    'findmnt -nro SOURCE -M /') echo /dev/mapper/linux-niri-root ;;
    'findmnt -nro SOURCE -M /boot') echo /dev/sdb1 ;;
    'lsblk -snrpo NAME,TYPE /dev/mapper/linux-niri-root') echo '/dev/sdb disk' ;;
    'lsblk -snrpo NAME,TYPE /dev/sdb1') echo "${MOCK_ESP_DISK:-/dev/sdb} disk" ;;
    "git -C $HOME/Projects/app-configs rev-parse --show-toplevel") echo "$HOME/Projects/app-configs" ;;
    "git -C $HOME/Projects/app-configs -c core.fsmonitor=false -c core.hooksPath=/dev/null status --porcelain --untracked-files=normal") echo "${MOCK_CHANGES:-}"; exit "${MOCK_STATUS_RC:-0}" ;;
    "git -C $HOME/Projects/app-configs rev-parse HEAD") echo "${MOCK_HEAD:-$EXPECTED_REVISION}" ;;
    "git -C $HOME/Projects/app-configs merge-base --is-ancestor $EXPECTED_REVISION HEAD") exit "${MOCK_ANCESTRY_STATUS:-1}" ;;
    "git -C $HOME/Projects/app-configs merge-base --is-ancestor 000f889360c327bb65615cee3948f250141ba8b2 HEAD") exit "${MOCK_REWRITTEN_ANCESTRY:-1}" ;;
    'systemctl is-system-running') echo "${MOCK_STATE:-running}" ;;
    'systemctl list-units '*) echo "${MOCK_SYSTEM_FAILURES:-}" ;;
    'systemctl --user list-units '*) echo "${MOCK_USER_FAILURES:-}"; exit "${MOCK_USER_RC:-0}" ;;
    'nmcli -t -f TYPE,STATE device status') echo "${MOCK_DEVICES:-loopback:connected (externally)}" ;;
    'ip -4 route show default'|'ip -6 route show default') echo "${MOCK_ROUTE:-}" ;;
    'getent ahosts cache.nixos.org') echo diagnostic-output-must-stay-private; exit "${MOCK_DNS_RC:-0}" ;;
    'curl '*) exit "${MOCK_HTTPS_RC:-0}" ;;
    'nvidia-smi --query-gpu=driver_version --format=csv,noheader') exit "${MOCK_NVIDIA_RC:-0}" ;;
    'niri msg outputs') echo diagnostic-output-must-stay-private; exit "${MOCK_NIRI_RC:-0}" ;;
    'claude --version') echo diagnostic-output-must-stay-private >&2; exit "${MOCK_CLAUDE_RC:-0}" ;;
    'systemctl is-active --quiet NetworkManager.service'|"niri validate -c $XDG_CONFIG_HOME/niri/config.kdl"|'codex --version') ;;
    *) exit 1 ;;
esac
MOCK
    chmod +x "$dir/bin/mock"
    local tool
    for tool in readlink stat findmnt lsblk git systemctl niri codex claude ip getent curl nvidia-smi nmcli; do
        ln -s mock "$dir/bin/$tool"
    done
}

verify() {
    local -a mounts=()
    if [[ -v MOCK_BOOTED ]]; then
        mounts+=(--overlay-src /nix/store --tmp-overlay /nix/store --dir "$system/specialisation"
            --dir "$MOCK_BOOTED" --symlink "$MOCK_BOOTED" "$system/specialisation/nvidia-open")
    fi
    if [[ -v MOCK_UNOWNED ]]; then mounts+=(--ro-bind /usr "$dir/home/Documents"); fi
    if [[ $# == 0 ]]; then set -- "$system" "$revision"; fi
    run bwrap --ro-bind / / --dev /dev --proc /proc \
        "${mounts[@]}" --ro-bind "$dir/varlib" /var/lib --ro-bind "$dir/ids" /dev/disk/by-id \
        --ro-bind "$dir/etc" /etc --ro-bind "$dir/sys" /sys --ro-bind "$dir/profiles" /nix/var/nix/profiles \
        --setenv HOME "$dir/home" --setenv PATH "${MOCK_PATH:-$dir/bin:$PATH}" \
        --setenv REAL_STAT "$(type -P stat)" --setenv REAL_READLINK "$(type -P readlink)" --setenv EXPECTED_SYSTEM "$system" \
        --setenv EXPECTED_REVISION "$revision" --setenv MOUNT_INFO "$dir/root-mount" \
        bash "$verifier" "$@"
}

@test 'first boot accepts a read-write EXT4 root and reads only its own error counter' {
    verify
    [ "$status" -eq 0 ]
    [[ $output == *'PASS  Root EXT4 recorded errors: 0'* ]]
}

@test 'first boot blocks read-only and emergency-read-only roots, even when rw is present' {
    for options in ro,relatime rw,relatime,emergency_ro rw,ro; do
        echo "ext4 $options 254:8" > "$dir/root-mount"
        verify
        [ "$status" -eq 1 ]
        [[ $output == *'FAIL  EXT4 root is '*read-only* ]]
    done
}

@test 'first boot fails for nonzero recorded root errors and an unexpected filesystem' {
    echo 2 > "$dir/sys/fs/ext4/dm-8/errors_count"
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Root EXT4 recorded errors: 2'* ]]
    echo 'xfs rw 254:8' > "$dir/root-mount"
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Expected an EXT4 root'* ]]
}

@test 'first boot reports missing or invalid mandatory evidence as unknown and exits unsuccessfully' {
    printf 'unavailable\n' > "$dir/sys/fs/ext4/dm-8/errors_count"
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'UNKNOWN  Root EXT4 error count unavailable'* ]]
    rm "$dir/sys/fs/ext4/dm-8/errors_count"
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'UNKNOWN  Root EXT4 error count unavailable'* ]]
    echo 'ext4 rw' > "$dir/root-mount"
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'UNKNOWN  Incomplete root mount information'* ]]
}

@test 'storage-only verifies root and ESP before a checkout or graphical session exists' {
    rmdir "$dir/home/Projects/app-configs"
    verify --storage-only
    [ "$status" -eq 0 ]
    [[ $output == *'PASS  Root and ESP use the same physical disk'* ]]
    [[ $output != *Checkout* ]]
    export MOCK_ESP_DISK=/dev/other
    verify --storage-only
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Root and ESP use the same physical disk'* ]]
}

@test 'registered generation accepts an advanced checkout only with install commit ancestry' {
    export MOCK_HEAD=0000000000000000000000000000000000000002 MOCK_ANCESTRY_STATUS=0
    verify --current-profile "$revision"
    [ "$status" -eq 0 ]
    [[ $output == *'PASS  Booted a registered linux-niri generation'* ]]
    [[ $output == *'INFO  Checkout advanced'* ]]
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Checkout uses the recorded commit'* ]]
    export MOCK_ANCESTRY_STATUS=1
    verify --current-profile "$revision"
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Checkout uses the recorded commit'* ]]
}

@test 'current-profile fails for missing or untrusted generation registration' {
    export MOCK_OWNER=1000
    verify --current-profile "$revision"
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Booted a registered linux-niri generation'* ]]
    unlink "$dir/profiles/system-42-link"
    unset MOCK_OWNER
    verify --current-profile "$revision"
    [ "$status" -eq 1 ]
}

@test 'offline and absent hardware do not invalidate required checks; JSON uses closed labels' {
    unset NIRI_SOCKET
    verify --json --online "$system" "$revision"
    [ "$status" -eq 0 ]
    jq -e '(.result == "Required checks passed") and
        (any(.checks[]; .status == "SKIP" and .required == false and (.check | startswith("Offline")))) and
        (any(.checks[]; .status == "SKIP" and (.check | startswith("NVIDIA"))))' <<< "$output"
    [[ $output != *diagnostic-output-must-stay-private* ]]
}

@test 'internet access is opt-in and a DNS or HTTPS failure does not fail an offline installation' {
    export MOCK_ROUTE=default MOCK_HTTPS_RC=1
    verify
    [ "$status" -eq 0 ]
    [[ $output == *'SKIP  External DNS and HTTPS'* ]]
    verify --online "$system" "$revision"
    [ "$status" -eq 0 ]
    [[ $output == *'WARN  Nix cache HTTPS request unavailable'* ]]
    [[ $output != *diagnostic-output-must-stay-private* ]]
    export MOCK_DNS_RC=1
    verify --online "$system" "$revision"
    [ "$status" -eq 0 ]
    [[ $output == *'WARN  Nix cache DNS lookup unavailable'* ]]
}

@test 'failed units, unavailable user manager, and missing commands block verification without leaking output' {
    export MOCK_SYSTEM_FAILURES=diagnostic-output-must-stay-private MOCK_USER_FAILURES=diagnostic-output-must-stay-private MOCK_CLAUDE_RC=127
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Failed system units present'* ]]
    [[ $output == *'FAIL  Failed user units present'* ]]
    [[ $output == *'FAIL  Claude CLI version available'* ]]
    [[ $output != *diagnostic-output-must-stay-private* ]]
    unset MOCK_SYSTEM_FAILURES MOCK_USER_FAILURES MOCK_CLAUDE_RC
    export MOCK_USER_RC=1
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'UNKNOWN  Could not query failed user units'* ]]
}

@test 'verified NVIDIA specialisation probes the live driver and active compositor' {
    bwrap --ro-bind / / --overlay-src /nix/store --tmp-overlay /nix/store true 2>/dev/null || skip 'bubblewrap overlay unavailable'
    export MOCK_BOOTED=/nix/store/fixture-nixos-system-linux-niri-26.11 NIRI_SOCKET=/example
    verify
    [ "$status" -eq 0 ]
    [[ $output == *'PASS  Booted the recorded NVIDIA specialisation'* ]]
    [[ $output == *'PASS  Selected NVIDIA driver responds'* ]]
    [[ $output == *'PASS  Niri session responds to output query'* ]]
    [[ $output != *diagnostic-output-must-stay-private* ]]
    export MOCK_NVIDIA_RC=1 MOCK_NIRI_RC=1
    verify --current-profile "$revision"
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Selected NVIDIA driver responds'* ]]
    [[ $output == *'FAIL  Niri session responds to output query'* ]]
}

@test 'diagnostic-only missing executable is named without failing required checks on older hosts' {
    export MOCK_PATH="$dir/bin" MOCK_DEVICES='wifi:connected'
    local tool
    for tool in bash cat timeout awk df jq; do ln -s "$(type -P "$tool")" "$dir/bin/$tool"; done
    verify
    [ "$status" -eq 0 ]
    [[ $output == *'WARN  Diagnostic command unavailable: lspci'* ]]
    [[ $output == *'PASS  NetworkManager reports a connected interface'* ]]
}

@test 'receipt identifies the mounted whole disk, including on storage-only checks' {
    verify --storage-only
    [ "$status" -eq 0 ]
    [[ $output == *'UNKNOWN  Installation has no recorded disk identity'* ]]
    ln -s /dev/sdb "$dir/ids/virtio-fixture"
    echo virtio-fixture > "$dir/varlib/app-configs/install-disk-id"
    verify --storage-only
    [ "$status" -eq 0 ]
    [[ $output == *'PASS  Boot disk matches the recorded persistent identity'* ]]
    [[ $output != *virtio-fixture* ]]
    export MOCK_RECEIPT_DEVICE=/dev/other
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Boot disk identity changed or unavailable'* ]]
    unset MOCK_RECEIPT_DEVICE
    unlink "$dir/ids/virtio-fixture"
    verify --storage-only
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Boot disk identity changed or unavailable'* ]]
}

@test 'malformed disk identity receipts, partition IDs and unsafe receipt permissions fail closed' {
    for id in ../path virtio-fixture-part1 $'one\ntwo' ''; do
        echo "$id" > "$dir/varlib/app-configs/install-disk-id"
        verify --storage-only
        [ "$status" -eq 1 ]
        [[ $output == *'FAIL  Installation disk identity receipt is invalid'* ]]
    done
    echo virtio-fixture > "$dir/varlib/app-configs/install-disk-id"
    export MOCK_RECEIPT_OWNER_MODE='0 666'
    verify --storage-only
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Installation disk identity receipt is invalid'* ]]
    unset MOCK_RECEIPT_OWNER_MODE
    printf 'virtio-fixture\0ignored\n' > "$dir/varlib/app-configs/install-disk-id"
    verify --storage-only
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Installation disk identity receipt is invalid'* ]]
    export MOCK_RECEIPT_DIR='0 777'
    verify --storage-only
    [ "$status" -eq 1 ]
    [[ $output == *'UNKNOWN  Cannot inspect the installation disk identity receipt'* ]]
}

@test 'a named mapper without crypt type fails the storage gate' {
    export MOCK_MAPPER=lvm
    verify --storage-only
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Root mapper is an encrypted device'* ]]
}

@test 'live switches and dirty checkouts fail exact handoff and warn in registered profile mode' {
    export MOCK_ACTIVE=/nix/store/other-nixos-system-linux-niri-26.11 MOCK_CHANGES=' M untracked-personal-name'
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Active system does not match'* && $output == *'FAIL  Checkout contains local changes'* ]]
    verify --current-profile "$revision"
    [ "$status" -eq 0 ]
    [[ $output == *'WARN  Active system differs'* && $output == *'WARN  Checkout contains local changes'* ]]
    [[ $output != *untracked-personal-name* ]]
}

@test 'owned folders and an explicit readable Niri user config are required for handoff' {
    export MOCK_UNOWNED=yes XDG_CONFIG_HOME="$dir/home/alternative"
    verify
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Installed Niri configuration unavailable'* ]]
    [[ $output == *'FAIL  Documents is an owned directory'* ]]
    unset MOCK_UNOWNED
    mkdir -p "$XDG_CONFIG_HOME/niri"
    cp "$dir/home/.config/niri/config.kdl" "$XDG_CONFIG_HOME/niri/config.kdl"
    verify
    [ "$status" -eq 0 ]
}

@test 'only the known installation receipt can follow its rewritten commit in routine readiness' {
    local deployed=26f3bbdc116a474d175d2d8c2ff09145cf64e889
    export MOCK_HEAD=0000000000000000000000000000000000000002 MOCK_REWRITTEN_ANCESTRY=0
    verify --current-profile "$deployed"
    [ "$status" -eq 0 ]
    [[ $output == *'INFO  Checkout includes the verified replacement for the install commit'* ]]
    verify "$system" "$deployed"
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Checkout uses the recorded commit'* ]]
    verify --current-profile "$revision"
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Checkout uses the recorded commit'* ]]
    export MOCK_REWRITTEN_ANCESTRY=1
    verify --current-profile "$deployed"
    [ "$status" -eq 1 ]
    [[ $output == *'FAIL  Checkout uses the recorded commit'* ]]
}
