#!/usr/bin/env bats
#
# ops/system-setup.sh detection: which settings does the user's own
# configuration.nix already satisfy?  Only ACTIVE Nix text for the TARGET user
# may count. Tests run report mode only, against a fixture directory standing in
# for /etc/nixos (never the real one) — nothing is mutated.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FIX="$BATS_TEST_TMPDIR/nixos"
  mkdir -p "$FIX"
}

# run_setup <configuration.nix text>
run_setup() {
  printf '%s\n' "$1" > "$FIX/configuration.nix"
  SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" \
    USER_NAME=alice ENABLE_DOCKER="${SS_DOCKER:-0}" ENABLE_TAILSCALE="${SS_TAILSCALE:-0}" \
    SYSTEM_TIMEZONE=Europe/London \
    run bash "$REPO_ROOT/ops/system-setup.sh"
}

@test "report mode on a bare config proposes fish, trusted-users and gc" {
  run_setup '{ }'
  [ "$status" -eq 0 ]
  [[ "$output" == *"programs.fish.enable = true;"* ]]
  [[ "$output" == *"trusted-users"* ]]
  [[ "$output" == *"nix.gc ="* ]]
  [ ! -e "$FIX/app-configs-extra.nix" ]
}

@test "active settings for the target user suppress re-emitting them" {
  run_setup '{
  programs.fish.enable = true;
  nix.settings.trusted-users = [ "root" "alice" ];
  nix.gc.automatic = true;
}'
  [ "$status" -eq 0 ]
  [[ "$output" != *"programs.fish.enable = true;"* ]]
  [[ "$output" != *"trusted-users"* ]]
  [[ "$output" != *"nix.gc ="* ]]
}

@test "commented-out settings do not count as configured" {
  run_setup '{
  # programs.fish.enable = true;
  # nix.settings.trusted-users = [ "root" "alice" ];
  /* nix.gc.automatic = true; */
}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"programs.fish.enable = true;"* ]]
  [[ "$output" == *"trusted-users"* ]]
  [[ "$output" == *"nix.gc ="* ]]
}

@test "explicitly disabled settings are user-owned: noticed, never overridden" {
  run_setup '{
  programs.fish.enable = false;
  nix.gc.automatic = false;
}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"programs.fish disabled in configuration.nix; not overriding"* ]]
  [[ "$output" == *"nix.gc disabled in configuration.nix; not overriding"* ]]
  [[ "$output" != *"programs.fish.enable = true;"* ]]
  [[ "$output" != *"nix.gc ="* ]]
}

@test "nix.gc = { automatic = false; } block form is also user-owned" {
  run_setup '{ nix.gc = { automatic = false; dates = "weekly"; }; }'
  [[ "$output" == *"nix.gc disabled in configuration.nix; not overriding"* ]]
  [[ "$output" != *"nix.gc ="* ]]
}

@test "a glob inside a string is not a block comment" {
  run_setup '{ environment.etc."x".text = "/home/*/.cache";
  programs.fish.enable = true;
}'
  [[ "$output" != *"programs.fish.enable = true;"* ]]
}

@test "a /* inside an indented-string script is not a block comment" {
  run_setup "{
  system.activationScripts.x = ''
    rm -rf /var/tmp/*
  '';
  programs.fish.enable = true;
}"
  [[ "$output" != *"programs.fish.enable = true;"* ]]
}

@test "a # inside a string (URL fragment) does not hide later settings" {
  run_setup '{ x = "http://cache.example.org/#frag"; programs.fish.enable = true; }'
  [[ "$output" != *"programs.fish.enable = true;"* ]]
}

@test "nix.optimise.automatic = false does not disable nix.gc detection" {
  run_setup '{
  nix.gc.automatic = true;
  nix.optimise.automatic = false;
}'
  [[ "$output" != *"nix.gc ="* ]]
  [[ "$output" != *"nix.gc disabled"* ]]
}

@test "multi-line trusted-users list naming the target user is recognised" {
  run_setup '{
  nix.settings.trusted-users = [
    "root"
    "alice"
  ];
}'
  [[ "$output" != *"trusted-users"* ]]
}

@test "non-literal assignments (mkForce false, config refs) are user-owned" {
  SS_DOCKER=1 SS_TAILSCALE=1 run_setup '{
  programs.fish.enable = lib.mkForce false;
  services.tailscale.enable = config.my.ts;
  virtualisation.docker.enable = lib.mkDefault false;
}'
  [ "$status" -eq 0 ]
  [[ "$output" != *"programs.fish.enable = true;"* ]]
  [[ "$output" != *"users.users.\"alice\".shell"* ]]
  [[ "$output" != *"services.tailscale.enable = true;"* ]]
  [[ "$output" != *"myConfig.docker.enable = true;"* ]]
}

@test "user-defined nix.optimise.automatic is not overridden when gc is emitted" {
  run_setup '{ nix.optimise.automatic = false; }'
  [[ "$output" == *"nix.gc ="* ]]
  [[ "$output" != *"nix.optimise.automatic = true;"* ]]
}

@test "--apply is refused when a test seam is set (outside bats, or a dir outside the bats temp dir)" {
  printf '{ }\n' > "$FIX/configuration.nix"
  # Not under bats: the seam directory never counts.
  env -u BATS_TEST_TMPDIR SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" USER_NAME=alice \
    bash "$REPO_ROOT/ops/system-setup.sh" --apply > "$BATS_TEST_TMPDIR/out.txt" 2>&1 && return 1
  grep -q "report-mode only" "$BATS_TEST_TMPDIR/out.txt"
  # Under bats, but the fixture dir is outside the bats temp dir.
  SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR=/nonexistent-nixos-fixture USER_NAME=alice \
    run bash "$REPO_ROOT/ops/system-setup.sh" --apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"report-mode only"* ]]
  # A ".." segment cannot climb out of the bats temp dir.
  SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX/../../x" USER_NAME=alice \
    run bash "$REPO_ROOT/ops/system-setup.sh" --apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"report-mode only"* ]]
  [ ! -e "$FIX/app-configs-extra.nix" ]
}

@test "trusted-users naming only another user does not satisfy the target user" {
  run_setup '{ nix.settings.trusted-users = [ "root" "bob" ]; }'
  [ "$status" -eq 0 ]
  [[ "$output" == *"trusted-users = [ \"root\" \"alice\" ]"* ]]
}

@test "trusted-users with @wheel satisfies the target user" {
  run_setup '{ nix.settings.trusted-users = [ "root" "@wheel" ]; }'
  [ "$status" -eq 0 ]
  [[ "$output" != *"trusted-users"* ]]
}

# -- NixOS-WSL (HOST_PROFILE=wsl) and the desktop path ------------------------

# The stock NixOS-WSL /etc/nixos/configuration.nix (channel form).
WSL_STOCK='{ config, lib, pkgs, ... }:
{
  imports = [
    # include NixOS-WSL modules
    <nixos-wsl/modules>
  ];

  wsl.enable = true;
  wsl.defaultUser = "nixos";

  system.stateVersion = "24.05";
}'

# run_wsl [ENV=value ...]: report mode against the stock NixOS-WSL fixture.
run_wsl() {
  printf '%s\n' "${WSL_CFG:-$WSL_STOCK}" > "$FIX/configuration.nix"
  run env HOST_PROFILE=wsl SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" \
    USER_NAME=alice SYSTEM_TIMEZONE=Europe/London \
    SYSTEM_SETUP_DOCKER_DESKTOP_DIR="$BATS_TEST_TMPDIR/no-docker-desktop" "$@" \
    bash "$REPO_ROOT/ops/system-setup.sh"
}

@test "desktop: the default report is byte for byte the pre-WSL snippet" {
  printf '{ }\n' > "$FIX/configuration.nix"
  run env HOST_PROFILE=linux-desktop SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" \
    USER_NAME=alice SYSTEM_TIMEZONE=Europe/London bash "$REPO_ROOT/ops/system-setup.sh"
  [ "$status" -eq 0 ]
  sed -n '/Would add the following/,/Report only/p' <<<"$output" | sed '1d;$d' | sed 's/[[:space:]]*$//' > "$BATS_TEST_TMPDIR/got.txt"
  diff "$BATS_TEST_TMPDIR/got.txt" "$BATS_TEST_DIRNAME/fixtures/system-setup-desktop-snippet.golden"
  [[ "$output" == *"Rebuild cmd: nixos-rebuild switch (non-flake)"* ]]
}

@test "desktop: the wsl branches are inert (no wsl import, no wsl guard, DOCKER_ROOTLESS ignored)" {
  printf '{ }\n' > "$FIX/configuration.nix"
  run env HOST_PROFILE=linux-desktop SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" \
    USER_NAME=alice DOCKER_ROOTLESS=1 DOCKER_GROUP=0 SYSTEM_TIMEZONE=Europe/London \
    bash "$REPO_ROOT/ops/system-setup.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"app-configs-wsl.nix"* ]]
  [[ "$output" != *"rootless"* ]]
  [[ "$output" == *'myConfig.docker.user = "alice";'* ]]
}

@test "wsl guard: a configuration.nix that is not NixOS-WSL is refused" {
  WSL_CFG='{ }' run_wsl
  [ "$status" -ne 0 ]
  [[ "$output" == *"NixOS-WSL"* ]]
  [[ "$output" != *"Would add"* ]]
  # A mention in a comment, or wsl.enable = false, is not NixOS-WSL.
  WSL_CFG='{
  # nixos-wsl wsl.enable = true;
}' run_wsl
  [ "$status" -ne 0 ]
  WSL_CFG='{ imports = [ <nixos-wsl/modules> ]; wsl.enable = false; }' run_wsl
  [ "$status" -ne 0 ]
}

@test "wsl report: wsl module imported, no docker, no tailscale, no dual-boot or browser policies" {
  run_wsl
  [ "$status" -eq 0 ]
  [[ "$output" == *"imports = [ ./app-configs-wsl.nix ];"* ]]
  [[ "$output" != *"docker"* ]]
  [[ "$output" != *"tailscale"* ]]
  [[ "$output" != *"linger"* ]]
  [[ "$output" != *"dual-boot"* ]]
  [[ "$output" != *"browser"* ]]
  [[ "$output" == *"programs.fish.enable = true;"* ]]
  [[ "$output" == *"programs.nix-ld.enable = true;"* ]]
  [[ "$output" == *"Rebuild cmd: nixos-rebuild boot (non-flake)"* ]]
  [ ! -e "$FIX/app-configs-wsl.nix" ]
}

@test "wsl report: a nix-ld assignment in configuration.nix is user-owned; desktop never emits nix-ld" {
  WSL_CFG="${WSL_STOCK%\}}  programs.nix-ld.enable = true;
}" run_wsl
  [ "$status" -eq 0 ]
  [[ "$output" != *"programs.nix-ld.enable = true;"* ]]
  printf '{ }\n' > "$FIX/configuration.nix"
  run env HOST_PROFILE=linux-desktop SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" \
    USER_NAME=alice bash "$REPO_ROOT/ops/system-setup.sh"
  [[ "$output" != *"nix-ld"* ]]
}

@test "wsl report: ENABLE_DOCKER=1 gives ONE combined imports list and user = null" {
  run_wsl ENABLE_DOCKER=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"imports = [ ./app-configs-docker.nix ./app-configs-wsl.nix ];"* ]]
  [ "$(grep -c 'imports =' <<<"$output")" -eq 1 ]
  [[ "$output" == *"myConfig.docker.enable = true;"* ]]
  [[ "$output" == *"myConfig.docker.user = null;"* ]]
  [[ "$output" != *"rootless"* ]]
}

@test "wsl report: DOCKER_GROUP=1 keeps the docker group user; DOCKER_ROOTLESS=1 sets rootless" {
  run_wsl ENABLE_DOCKER=1 DOCKER_GROUP=1
  [ "$status" -eq 0 ]
  [[ "$output" == *'myConfig.docker.user = "alice";'* ]]
  run_wsl ENABLE_DOCKER=1 DOCKER_ROOTLESS=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"myConfig.docker.rootless = true;"* ]]
  [[ "$output" == *"myConfig.docker.user = null;"* ]]
}

@test "wsl report: Docker is refused next to Docker Desktop integration" {
  mkdir -p "$BATS_TEST_TMPDIR/dd"
  run_wsl ENABLE_DOCKER=1 SYSTEM_SETUP_DOCKER_DESKTOP_DIR="$BATS_TEST_TMPDIR/dd"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Docker Desktop"* ]]
  WSL_CFG="${WSL_STOCK%\}}  wsl.docker-desktop.enable = true;
}" run_wsl ENABLE_DOCKER=1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Docker Desktop"* ]]
  # Without Docker the integration is not our business.
  run_wsl ENABLE_DOCKER=0 SYSTEM_SETUP_DOCKER_DESKTOP_DIR="$BATS_TEST_TMPDIR/dd"
  [ "$status" -eq 0 ]
}

@test "wsl report: the Docker Desktop directory seam is ignored outside bats" {
  [ ! -d /mnt/wsl/docker-desktop ] || skip "this host really has /mnt/wsl/docker-desktop"
  printf '%s\n' "$WSL_STOCK" > "$FIX/configuration.nix"
  mkdir -p "$BATS_TEST_TMPDIR/dd"
  # Without BATS_TEST_TMPDIR the real /mnt/wsl/docker-desktop decides, not the seam.
  run env -u BATS_TEST_TMPDIR HOST_PROFILE=wsl SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" \
    USER_NAME=alice ENABLE_DOCKER=1 SYSTEM_SETUP_DOCKER_DESKTOP_DIR="$BATS_TEST_TMPDIR/dd" \
    bash "$REPO_ROOT/ops/system-setup.sh"
  [ "$status" -eq 0 ]
}

# -- apply mode against a fixture (test seam: only under bats, only in its temp dir)

# apply_setup: a repo copy, a scratch HOME and a stub nixos-rebuild on PATH.
apply_setup() {
  R="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$R/ops/lib" "$R/nix/modules/nixos" "$BATS_TEST_TMPDIR/home" "$BATS_TEST_TMPDIR/stubs"
  cp "$REPO_ROOT/ops/system-setup.sh" "$REPO_ROOT/ops/detect-host.sh" "$REPO_ROOT/ops/detect-timezone.sh" "$R/ops/"
  cp "$REPO_ROOT/ops/lib/preflight.sh" "$R/ops/lib/"
  cp "$REPO_ROOT/nix/modules/nixos/docker.nix" "$REPO_ROOT/nix/modules/nixos/wsl.nix" "$R/nix/modules/nixos/"
  REBUILD_LOG="$BATS_TEST_TMPDIR/rebuild.log"; : > "$REBUILD_LOG"
  cat > "$BATS_TEST_TMPDIR/stubs/nixos-rebuild" <<'STUB'
#!/bin/sh
echo "$*" >> "$REBUILD_LOG"
# Like `nixos-rebuild --flake`: write a lock file, then fail when asked to.
if [ "$1" = dry-build ] && [ -n "${STUB_LOCK_FILE:-}" ]; then echo '{"locked":true}' > "$STUB_LOCK_FILE"; fi
if [ "$1" = dry-build ] && [ -n "${STUB_FAIL_DRY:-}" ]; then echo 'stub: dry-build failed' >&2; exit 1; fi
if [ "$1" != dry-build ] && [ -n "${STUB_FAIL_REAL:-}" ]; then echo 'stub: rebuild failed' >&2; exit 1; fi
exit 0
STUB
  chmod +x "$BATS_TEST_TMPDIR/stubs/nixos-rebuild"
  export REBUILD_LOG
}

# run_apply [ENV=value ...]: apply against $FIX with the repo copy.
run_apply() {
  run env HOME="$BATS_TEST_TMPDIR/home" PATH="$BATS_TEST_TMPDIR/stubs:$PATH" REBUILD_LOG="$REBUILD_LOG" \
    SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" SYSTEM_TIMEZONE=Europe/London \
    SYSTEM_SETUP_DOCKER_DESKTOP_DIR="$BATS_TEST_TMPDIR/no-docker-desktop" "$@" \
    bash "$R/ops/system-setup.sh" --apply
}

# state <dir>: every entry with type, mode, owner, symlink target and content hash.
state() {
  ( cd "$1" && find . -mindepth 1 -printf '%p\t%y\t%m\t%u:%g\t%l\n' | sort
    find . -type f -exec sha256sum {} + | sort -k2 )
}

@test "apply seam: refused when the stub nixos-rebuild is not the one on PATH" {
  apply_setup
  printf '%s\n' "$WSL_STOCK" > "$FIX/configuration.nix"
  run env HOME="$BATS_TEST_TMPDIR/home" SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" \
    HOST_PROFILE=wsl USER_NAME=alice PATH="/nonexistent-bin:$(dirname "$(command -v bash)"):$(dirname "$(command -v mktemp)")" \
    "$(command -v bash)" "$R/ops/system-setup.sh" --apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"stub nixos-rebuild"* ]]
  [ ! -e "$FIX/app-configs-extra.nix" ]
}

@test "wsl apply: user missing runs dry-build then boot; wsl.* lines untouched; files in place" {
  apply_setup
  printf '%s\n' "$WSL_STOCK" > "$FIX/configuration.nix"
  run_apply HOST_PROFILE=wsl USER_NAME=no-such-user-for-bats
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(sed -n 1p "$REBUILD_LOG")" = "dry-build" ]
  [ "$(sed -n 2p "$REBUILD_LOG")" = "boot" ]
  [ "$(wc -l < "$REBUILD_LOG")" -eq 2 ]
  cmp "$FIX/app-configs-wsl.nix" "$REPO_ROOT/nix/modules/nixos/wsl.nix"
  [ ! -e "$FIX/app-configs-docker.nix" ]
  grep -q 'imports = \[ ./app-configs-wsl.nix \];' "$FIX/app-configs-extra.nix"
  # configuration.nix: only the import was added; every wsl.* line is as it was.
  # The same-line `imports = [` form is wired on that line.
  grep -q 'imports = \[ ./app-configs-extra.nix$' "$FIX/configuration.nix"
  diff <(printf '%s\n' "$WSL_STOCK" | grep 'wsl\.') <(grep 'wsl\.' "$FIX/configuration.nix")
  [ "$(diff <(printf '%s\n' "$WSL_STOCK") "$FIX/configuration.nix" | grep -c '^>')" -eq 1 ]
  grep -q 'wsl.enable = true;' "$FIX/configuration.nix"
}

@test "wsl apply: an existing user runs dry-build then switch" {
  apply_setup
  printf '%s\n' "$WSL_STOCK" > "$FIX/configuration.nix"
  run_apply HOST_PROFILE=wsl USER_NAME="$(id -un)"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(sed -n 1p "$REBUILD_LOG")" = "dry-build" ]
  [ "$(sed -n 2p "$REBUILD_LOG")" = "switch" ]
}

@test "wsl apply: ENABLE_DOCKER=1 writes both copies and one combined imports list" {
  apply_setup
  printf '%s\n' "$WSL_STOCK" > "$FIX/configuration.nix"
  run_apply HOST_PROFILE=wsl USER_NAME="$(id -un)" ENABLE_DOCKER=1
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  cmp "$FIX/app-configs-docker.nix" "$REPO_ROOT/nix/modules/nixos/docker.nix"
  cmp "$FIX/app-configs-wsl.nix" "$REPO_ROOT/nix/modules/nixos/wsl.nix"
  [ "$(grep -c 'imports =' "$FIX/app-configs-extra.nix")" -eq 1 ]
  grep -q 'imports = \[ ./app-configs-docker.nix ./app-configs-wsl.nix \];' "$FIX/app-configs-extra.nix"
}

@test "wsl apply: a configuration.nix that is not NixOS-WSL writes nothing and builds nothing" {
  apply_setup
  printf '{ }\n' > "$FIX/configuration.nix"
  before="$(state "$FIX")"
  run_apply HOST_PROFILE=wsl USER_NAME=alice
  [ "$status" -ne 0 ]
  [ "$(state "$FIX")" = "$before" ]
  [ ! -s "$REBUILD_LOG" ]
}

@test "desktop apply: dry-build then switch, docker copy written, no wsl module" {
  apply_setup
  # Multi-line form: `imports =` then the list on the next line.
  printf '{ pkgs, ... }:\n{\n  imports =\n    [ ./hardware-configuration.nix ];\n  environment.systemPackages = with pkgs; [ vim ];\n}\n' > "$FIX/configuration.nix"
  run_apply HOST_PROFILE=linux-desktop USER_NAME=alice
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(sed -n 1p "$REBUILD_LOG")" = "dry-build" ]
  [ "$(sed -n 2p "$REBUILD_LOG")" = "switch" ]
  cmp "$FIX/app-configs-docker.nix" "$REPO_ROOT/nix/modules/nixos/docker.nix"
  [ ! -e "$FIX/app-configs-wsl.nix" ]
  grep -q 'imports = \[ ./app-configs-docker.nix \];' "$FIX/app-configs-extra.nix"
  # Wired into the imports list, not into the systemPackages list.
  grep -q '\[ ./app-configs-extra.nix ./hardware-configuration.nix' "$FIX/configuration.nix"
  grep -q 'with pkgs; \[ vim \];' "$FIX/configuration.nix"
}

# prepare_existing <profile>: a populated fixture dir so a restore has real
# state to preserve: modes, a symlinked docker copy or none, an old extra module,
# a flake.nix with a modules list and no flake.lock.
prepare_existing() {
  printf '%s\n' "$WSL_STOCK" > "$FIX/configuration.nix"; chmod 640 "$FIX/configuration.nix"
  printf '{\n  outputs = { ... }: {\n    nixosConfigurations.nixos = x {\n      modules = [\n        ./configuration.nix\n      ];\n    };\n  };\n}\n' > "$FIX/flake.nix"
  chmod 644 "$FIX/flake.nix"
  printf '# old extra module\n{ }\n' > "$FIX/app-configs-extra.nix"; chmod 600 "$FIX/app-configs-extra.nix"
  if [ "$1" = with-docker ]; then
    mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
    printf '# old docker copy\n{ }\n' > "$BATS_TEST_TMPDIR/elsewhere/docker-old.nix"
    ln -s "$BATS_TEST_TMPDIR/elsewhere/docker-old.nix" "$FIX/app-configs-docker.nix"
  fi
  printf '# stray\n' > "$FIX/hardware-configuration.nix"
}

@test "B2: a dry-build failure restores every file exactly (existing docker copy is a symlink, ENABLE_DOCKER=0)" {
  apply_setup
  prepare_existing with-docker
  before="$(state "$FIX")"; target_before="$(cat "$BATS_TEST_TMPDIR/elsewhere/docker-old.nix")"
  run_apply HOST_PROFILE=wsl USER_NAME=alice STUB_FAIL_DRY=1 STUB_LOCK_FILE="$FIX/flake.lock"
  [ "$status" -ne 0 ]
  [[ "$output" == *"stub: dry-build failed"* ]]
  [ "$(state "$FIX")" = "$before" ]
  [ -L "$FIX/app-configs-docker.nix" ]
  [ "$(cat "$BATS_TEST_TMPDIR/elsewhere/docker-old.nix")" = "$target_before" ]
  [ ! -e "$FIX/flake.lock" ]
  [ "$(cat "$REBUILD_LOG")" = "dry-build --flake $FIX#nixos" ]
  [[ "$output" != *"--rollback"* ]]
}

@test "B2: a dry-build failure restores every file exactly (no docker copy existed, ENABLE_DOCKER=1)" {
  apply_setup
  prepare_existing no-docker
  before="$(state "$FIX")"
  run_apply HOST_PROFILE=wsl USER_NAME=alice ENABLE_DOCKER=1 STUB_FAIL_DRY=1 STUB_LOCK_FILE="$FIX/flake.lock"
  [ "$status" -ne 0 ]
  [ "$(state "$FIX")" = "$before" ]
  [ ! -e "$FIX/app-configs-docker.nix" ]
  [ ! -e "$FIX/app-configs-wsl.nix" ]
  [ ! -e "$FIX/flake.lock" ]
}

@test "B2: a failed real rebuild restores every file, then prints the switch rollback command" {
  apply_setup
  prepare_existing with-docker
  before="$(state "$FIX")"
  run_apply HOST_PROFILE=wsl USER_NAME="$(id -un)" STUB_FAIL_REAL=1
  [ "$status" -ne 0 ]
  [[ "$output" == *"sudo nixos-rebuild switch --rollback"* ]]
  [ "$(state "$FIX")" = "$before" ]
  [ "$(sed -n 2p "$REBUILD_LOG")" = "switch --flake $FIX#nixos" ]
}

@test "B2: a successful run leaves a stamped backup dir holding the originals" {
  apply_setup
  prepare_existing with-docker
  run_apply HOST_PROFILE=wsl USER_NAME=alice
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  backup="$(ls -d "$FIX".app-configs-backup-* | head -n1)"
  [ -n "$backup" ]
  [ "$(cat "$backup/files/configuration.nix" | head -n1)" = "$(printf '%s\n' "$WSL_STOCK" | head -n1)" ]
  grep -q 'app-configs-docker.nix	symlink' "$backup/manifest.tsv"
  grep -q 'flake.lock	absent' "$backup/manifest.tsv"
}

@test "F1: a commented imports line above the real list is left alone and the real list is wired" {
  apply_setup
  printf '{ pkgs, ... }:\n{\n  # imports = [ ./old.nix ];\n  imports = [ ./hardware-configuration.nix ];\n}\n' > "$FIX/configuration.nix"
  run_apply HOST_PROFILE=linux-desktop USER_NAME=alice
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -qxF '  # imports = [ ./old.nix ];' "$FIX/configuration.nix"
  grep -qF 'imports = [ ./app-configs-extra.nix ./hardware-configuration.nix ];' "$FIX/configuration.nix"
  [ "$(grep -c 'app-configs-extra.nix' "$FIX/configuration.nix")" -eq 1 ]
}

@test "T1: a symlinked docker copy is replaced, never written through (ENABLE_DOCKER=1)" {
  apply_setup
  printf '{ imports = [ ]; }\n' > "$FIX/configuration.nix"
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  printf '# user file behind the link\n' > "$BATS_TEST_TMPDIR/elsewhere/docker-user.nix"
  ln -s "$BATS_TEST_TMPDIR/elsewhere/docker-user.nix" "$FIX/app-configs-docker.nix"
  ln -s "$BATS_TEST_TMPDIR/elsewhere/docker-user.nix" "$FIX/app-configs-extra.nix"
  run_apply HOST_PROFILE=linux-desktop USER_NAME=alice
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(cat "$BATS_TEST_TMPDIR/elsewhere/docker-user.nix")" = "# user file behind the link" ]
  [ ! -L "$FIX/app-configs-docker.nix" ]
  [ ! -L "$FIX/app-configs-extra.nix" ]
  cmp "$FIX/app-configs-docker.nix" "$REPO_ROOT/nix/modules/nixos/docker.nix"
}

@test "F2: --help prints the whole header, up to the exit-status line" {
  run bash "$REPO_ROOT/ops/system-setup.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exit non-zero on failure. NixOS only."* ]]
  [[ "$output" == *"DOCKER_ROOTLESS=1"* ]]
}

@test "F3: the restore message names the nixos dir" {
  apply_setup
  prepare_existing with-docker
  run_apply HOST_PROFILE=wsl USER_NAME=alice STUB_FAIL_DRY=1
  [ "$status" -ne 0 ]
  [[ "$output" == *"restored every touched file under $FIX to its recorded state"* ]]
}

@test "F4: a failed boot restores and prints the boot rollback hint, not the switch one" {
  apply_setup
  prepare_existing no-docker
  run_apply HOST_PROFILE=wsl USER_NAME=no-such-user-for-bats STUB_FAIL_REAL=1
  [ "$status" -ne 0 ]
  [[ "$output" == *"sudo nixos-rebuild boot --rollback"* ]]
  [[ "$output" != *"switch --rollback"* ]]
  [ "$(sed -n 2p "$REBUILD_LOG")" = "boot --flake $FIX#nixos" ]
}

# -- bare NixOS-WSL needs system tools before Home Manager exists ---------------
# ops/install.sh:312 (git, fatal), ops/doctor.sh:73 (bash git curl, run by install
# and the pre-commit hook), ops/update-all.sh:817 (git nix chezmoi). A stock
# NixOS-WSL has no git; the desktop gets it from its own /etc/nixos.

@test "wsl report: git and curl are system packages, and flakes are enabled" {
  run_wsl
  [ "$status" -eq 0 ]
  [[ "$output" == *"environment.systemPackages = with pkgs; [ git curl ];"* ]]
  [[ "$output" == *'nix.settings.experimental-features = [ "nix-command" "flakes" ];'* ]]
}

@test "wsl report: an experimental-features setting in configuration.nix is user-owned" {
  WSL_CFG="${WSL_STOCK%\}}  nix.settings.experimental-features = [ \"nix-command\" \"flakes\" \"ca-derivations\" ];
}" run_wsl
  [ "$status" -eq 0 ]
  [[ "$output" != *"experimental-features"* ]]
  [[ "$output" == *"environment.systemPackages = with pkgs; [ git curl ];"* ]]
}

@test "desktop report: no git or curl package and no experimental-features line" {
  printf '{ }\n' > "$FIX/configuration.nix"
  run env HOST_PROFILE=linux-desktop SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" \
    USER_NAME=alice SYSTEM_TIMEZONE=Europe/London bash "$REPO_ROOT/ops/system-setup.sh"
  [[ "$output" != *"systemPackages"* ]]
  [[ "$output" != *"experimental-features"* ]]
}

@test "wsl apply: the tools are written, and a second run finds everything already present" {
  apply_setup
  printf '%s\n' "$WSL_STOCK" > "$FIX/configuration.nix"
  run_apply HOST_PROFILE=wsl USER_NAME="$(id -un)"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -qF 'environment.systemPackages = with pkgs; [ git curl ];' "$FIX/app-configs-extra.nix"
  : > "$REBUILD_LOG"
  run_apply HOST_PROFILE=wsl USER_NAME="$(id -un)"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"All recommended system settings already present."* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"Would add"* ]]
}

@test "wsl apply: a module written before the tools were added is rewritten" {
  apply_setup
  printf '%s\n' "$WSL_STOCK" > "$FIX/configuration.nix"
  run_apply HOST_PROFILE=wsl USER_NAME="$(id -un)"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  # What the previous version wrote: same module, no tools.
  grep -vE 'systemPackages|experimental-features|# git and curl|# Flakes' "$FIX/app-configs-extra.nix" > "$BATS_TEST_TMPDIR/old-extra.nix"
  cp "$BATS_TEST_TMPDIR/old-extra.nix" "$FIX/app-configs-extra.nix"
  run_apply HOST_PROFILE=wsl USER_NAME="$(id -un)"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"Would add"* ]]
  grep -qF 'environment.systemPackages = with pkgs; [ git curl ];' "$FIX/app-configs-extra.nix"
}

@test "SYSTEM_TIMEZONE overrides the Europe/London default and is validated" {
  run_wsl SYSTEM_TIMEZONE=America/Los_Angeles
  [ "$status" -eq 0 ]
  [[ "$output" == *'time.timeZone = lib.mkForce "America/Los_Angeles";'* ]]
  run_wsl SYSTEM_TIMEZONE=UTC
  [[ "$output" == *'time.timeZone = lib.mkForce "UTC";'* ]]
  local bad
  for bad in 'Europe/London"; boot.x = 1; "' 'a b' '../etc' '/Europe/London' 'Europe//London'; do
    run_wsl SYSTEM_TIMEZONE="$bad"
    [ "$status" -ne 0 ] || { echo "accepted: '$bad'"; return 1; }
    [[ "$output" == *"invalid SYSTEM_TIMEZONE"* ]] || { echo "no message for '$bad': $output"; return 1; }
    [[ "$output" != *"Would add"* ]]
  done
}

@test "SYSTEM_TIMEZONE default stays Europe/London when unset" {
  printf '%s\n' "$WSL_STOCK" > "$FIX/configuration.nix"
  run env -u SYSTEM_TIMEZONE HOST_PROFILE=wsl SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" USER_NAME=alice \
    bash "$REPO_ROOT/ops/system-setup.sh"
  [[ "$output" == *'time.timeZone = lib.mkForce "Europe/London";'* ]]
}
