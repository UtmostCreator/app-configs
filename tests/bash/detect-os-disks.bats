#!/usr/bin/env bats
# Tests for scripts/detect-os-disks.sh — the read-only NVMe/OS detector.
#
# These are deterministic: they inject canned `lsblk -J` JSON and a pinned
# current-disk via the script's testing seams, so they never touch real
# hardware and produce identical results on any host.
#
# Run:  bats tests/bash/detect-os-disks.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/scripts/detect-os-disks.sh"
    [ -f "$SCRIPT" ]
}

# --- Fixtures -------------------------------------------------------------

# Windows on nvme0n1 (EFI + MSR + NTFS), Linux on nvme1n1 (EFI + ext4 + swap).
fixture_separate_disks() {
    cat <<'JSON'
{"blockdevices":[
  {"name":"nvme0n1","size":"953.9G","type":"disk","children":[
    {"name":"nvme0n1p1","size":"200M","type":"part","fstype":"vfat","parttypename":"EFI System"},
    {"name":"nvme0n1p2","size":"16M","type":"part","fstype":null,"parttypename":"Microsoft reserved"},
    {"name":"nvme0n1p3","size":"952.9G","type":"part","fstype":"ntfs","parttypename":"Microsoft basic data"}
  ]},
  {"name":"nvme1n1","size":"931.5G","type":"disk","children":[
    {"name":"nvme1n1p1","size":"1G","type":"part","fstype":"vfat","parttypename":"EFI System","mountpoint":"/boot"},
    {"name":"nvme1n1p2","size":"896.9G","type":"part","fstype":"ext4","parttypename":"Linux filesystem","mountpoint":"/"},
    {"name":"nvme1n1p3","size":"33.6G","type":"part","fstype":"swap","parttypename":"Linux swap"}
  ]}
]}
JSON
}

# Windows + Linux share ONE disk (single ESP, roomy 1G), no second disk.
fixture_shared_disk() {
    cat <<'JSON'
{"blockdevices":[
  {"name":"nvme0n1","size":"953.9G","type":"disk","children":[
    {"name":"nvme0n1p1","size":"1G","type":"part","fstype":"vfat","parttypename":"EFI System","mountpoint":"/boot"},
    {"name":"nvme0n1p2","size":"16M","type":"part","fstype":null,"parttypename":"Microsoft reserved"},
    {"name":"nvme0n1p3","size":"400G","type":"part","fstype":"ntfs","parttypename":"Microsoft basic data"},
    {"name":"nvme0n1p4","size":"500G","type":"part","fstype":"ext4","parttypename":"Linux filesystem","mountpoint":"/"}
  ]}
]}
JSON
}

# Shared disk but the ESP is a tiny factory 100M (xbootldr hint expected).
fixture_shared_small_esp() {
    cat <<'JSON'
{"blockdevices":[
  {"name":"nvme0n1","size":"953.9G","type":"disk","children":[
    {"name":"nvme0n1p1","size":"100M","type":"part","fstype":"vfat","parttypename":"EFI System","mountpoint":"/boot"},
    {"name":"nvme0n1p2","size":"16M","type":"part","fstype":null,"parttypename":"Microsoft reserved"},
    {"name":"nvme0n1p3","size":"400G","type":"part","fstype":"ntfs","parttypename":"Microsoft basic data"},
    {"name":"nvme0n1p4","size":"500G","type":"part","fstype":"ext4","parttypename":"Linux filesystem","mountpoint":"/"}
  ]}
]}
JSON
}

# Linux only, no Windows anywhere.
fixture_no_windows() {
    cat <<'JSON'
{"blockdevices":[
  {"name":"nvme0n1","size":"931.5G","type":"disk","children":[
    {"name":"nvme0n1p1","size":"1G","type":"part","fstype":"vfat","parttypename":"EFI System","mountpoint":"/boot"},
    {"name":"nvme0n1p2","size":"900G","type":"part","fstype":"ext4","parttypename":"Linux filesystem","mountpoint":"/"}
  ]}
]}
JSON
}

run_json() { # $1 = fixture json, $2 = current disk
    DETECT_OS_DISKS_LSBLK_JSON="$1" \
        DETECT_OS_DISKS_CURRENT_DISK="$2" \
        AI_OUTPUT=json run bash "$SCRIPT"
}

run_plain() { # $1 = fixture json, $2 = current disk
    DETECT_OS_DISKS_LSBLK_JSON="$1" \
        DETECT_OS_DISKS_CURRENT_DISK="$2" \
        run bash "$SCRIPT"
}

# --- JSON-mode classification --------------------------------------------

@test "separate disks: linux/windows verdicts + windows_on_separate_disk true" {
    run_json "$(fixture_separate_disks)" "nvme1n1"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.linux_disk')" = "nvme1n1" ]
    [ "$(echo "$output" | jq -r '.windows_disk')" = "nvme0n1" ]
    [ "$(echo "$output" | jq -r '.windows_on_separate_disk')" = "true" ]
    [ "$(echo "$output" | jq -r '.current_disk')" = "nvme1n1" ]
    [ "$(echo "$output" | jq -r '.disks[] | select(.name=="nvme0n1") | .os')" = "windows" ]
    [ "$(echo "$output" | jq -r '.disks[] | select(.name=="nvme1n1") | .os')" = "linux" ]
}

@test "shared disk: single disk is both, windows_on_separate_disk false" {
    run_json "$(fixture_shared_disk)" "nvme0n1"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.windows_on_separate_disk')" = "false" ]
    # Disk has both ntfs and ext4; classifier prioritises windows markers.
    [ "$(echo "$output" | jq -r '.disks[] | select(.name=="nvme0n1") | .os')" = "windows" ]
    [ "$(echo "$output" | jq -r '.disks[] | select(.name=="nvme0n1") | .has_linux')" = "true" ]
}

@test "no windows: windows_disk empty, linux detected" {
    run_json "$(fixture_no_windows)" "nvme0n1"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.windows_disk')" = "" ]
    [ "$(echo "$output" | jq -r '.linux_disk')" = "nvme0n1" ]
    [ "$(echo "$output" | jq -r '.windows_on_separate_disk')" = "false" ]
}

# --- Plain-mode suggestion text ------------------------------------------

@test "separate disks: suggests windowsOnSeparateDisk = true" {
    run_plain "$(fixture_separate_disks)" "nvme1n1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"windowsOnSeparateDisk = true"* ]]
    [[ "$output" == *"map -c"* ]]
    [[ "$output" == *"[current OS booted here]"* ]]
}

@test "no windows: suggests plain enable, no separate-disk block" {
    run_plain "$(fixture_no_windows)" "nvme0n1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No Windows install detected"* ]]
    [[ "$output" == *"myConfig.dualBoot.enable = true;"* ]]
    [[ "$output" != *"windowsOnSeparateDisk = true"* ]]
}

@test "shared small ESP: emits XBOOTLDR hint" {
    run_plain "$(fixture_shared_small_esp)" "nvme0n1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"XBOOTLDR"* ]]
}

@test "shared roomy ESP: no XBOOTLDR hint" {
    run_plain "$(fixture_shared_disk)" "nvme0n1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"XBOOTLDR"* ]]
}

# --- Safety / contract ----------------------------------------------------

@test "script is read-only: no mutating boot commands are executed" {
    # Static guard: strip comments and the printed help heredocs/strings, then
    # assert no mutating command is actually invoked. (Comments and on-screen
    # reminders may legitimately mention efibootmgr/nixos-rebuild.)
    code="$(grep -vE '^[[:space:]]*#' "$SCRIPT" \
        | grep -vE "printf|cat <<|echo ")"
    ! echo "$code" | grep -Eq '(^|[;&|[:space:]])(efibootmgr|mkfs|nixos-rebuild)([[:space:]]|$)'
    ! echo "$code" | grep -Eq 'bootctl[[:space:]]+(install|update)'
    ! echo "$code" | grep -Eq '(^|[;&|[:space:]])mount[[:space:]]'
}

@test "missing jq dependency fails cleanly" {
    # Shim PATH that keeps coreutils available but hides jq, so the jq check
    # trips first with a clean message rather than a 'command not found' crash.
    shimdir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$shimdir"
    for t in bash printf grep basename readlink cat; do
        p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$shimdir/$t"
    done
    DETECT_OS_DISKS_LSBLK_JSON="$(fixture_no_windows)" \
        PATH="$shimdir" run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"required tool missing: jq"* ]]
}
