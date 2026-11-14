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

@test "--apply is refused when a test seam is set" {
  printf '{ }\n' > "$FIX/configuration.nix"
  SYSTEM_SETUP_ASSUME_NIXOS=1 SYSTEM_SETUP_NIXOS_DIR="$FIX" USER_NAME=alice \
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
