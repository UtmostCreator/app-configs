#!/usr/bin/env bash
# Install the repo's narrowly scoped Tailscale NixOS module and rebuild.
# Default is report-only; --apply requires root.
set -euo pipefail

mode=report
case "${1:-}" in
  "") ;;
  --apply) mode=apply ;;
  -h|--help)
    sed -n '2,5p' "$0"
    exit 0
    ;;
  *) printf 'tailscale-setup: unknown argument: %s\n' "$1" >&2; exit 2 ;;
esac

target_module=/etc/nixos/app-configs-tailscale.nix
system_config=/etc/nixos/configuration.nix
system_flake=/etc/nixos/flake.nix
# Pin only Tailscale to the repo's reviewed nixpkgs revision. This supplies the
# dashboard-required security release without upgrading every NixOS package.
tailscale_nixpkgs_rev=9b9402b959a2276982ddd5ad3652a38b97f7c40b
if [[ -n "${USER_NAME:-}" ]]; then
  user_name="$USER_NAME"
elif [[ -n "${SUDO_USER:-}" ]]; then
  user_name="$SUDO_USER"
elif [[ -n "${PKEXEC_UID:-}" ]]; then
  user_name="$(getent passwd "$PKEXEC_UID" | cut -d: -f1)"
elif [[ "$(id -u)" -ne 0 ]]; then
  user_name="$USER"
else
  printf 'tailscale-setup: set USER_NAME when invoking directly as root\n' >&2
  exit 1
fi
[[ -n "$user_name" ]] || { printf 'tailscale-setup: could not resolve target user\n' >&2; exit 1; }

[[ -f /etc/NIXOS ]] || { printf 'tailscale-setup: NixOS only\n' >&2; exit 1; }
[[ -f "$system_config" ]] || { printf 'tailscale-setup: missing %s\n' "$system_config" >&2; exit 1; }

printf '[tailscale-setup:%s] Enable tailscaled, grant operator rights to %s, and enable user lingering.\n' \
  "$mode" "$user_name"
printf '[tailscale-setup:%s] No Tailscale SSH, Funnel, exit-node, subnet-router, or firewall exposure.\n' "$mode"

if [[ "$mode" == report ]]; then
  printf '[tailscale-setup:report] Re-run with: sudo bash ops/tailscale-setup.sh --apply\n'
  exit 0
fi
[[ "$(id -u)" -eq 0 ]] || { printf 'tailscale-setup: --apply requires root\n' >&2; exit 1; }

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
override_module=/etc/nixos/app-configs-tailscale-host.nix
tmp_module="$(mktemp)"
tmp_override="$(mktemp)"
trap 'rm -f "$tmp_module" "$tmp_override"' EXIT
{
  printf '{ config, lib, pkgs, ... }:\n'
  printf 'let\n'
  printf '  cfg = config.myConfig.tailscale;\n'
  # The package-set interpolation belongs to Nix; the revision is a shell value.
  # shellcheck disable=SC2016
  printf '  tailscalePkgs = (builtins.getFlake "github:NixOS/nixpkgs/%s").legacyPackages.${pkgs.stdenv.hostPlatform.system};\n' "$tailscale_nixpkgs_rev"
  printf 'in\n'
  printf '{\n'
  printf '  options.myConfig.tailscale = {\n'
  printf '    enable = lib.mkEnableOption "private Tailscale access";\n'
  printf '    user = lib.mkOption { type = lib.types.str; default = ""; };\n'
  printf '  };\n'
  printf '  config = lib.mkIf cfg.enable {\n'
  printf '    assertions = [{\n'
  printf '      assertion = cfg.user != "";\n'
  printf '      message = "myConfig.tailscale.user must be set";\n'
  printf '    }];\n'
  printf '    services.tailscale.enable = true;\n'
  printf '    services.tailscale.package = tailscalePkgs.tailscale;\n'
  # These are intentionally Nix interpolations, not shell variables.
  # shellcheck disable=SC2016
  printf '    services.tailscale.extraSetFlags = [ "--operator=${cfg.user}" ];\n'
  # shellcheck disable=SC2016
  printf '    users.users.${cfg.user}.linger = true;\n'
  printf '  };\n'
  printf '}\n'
} >"$tmp_module"
install -m 0644 "$tmp_module" "$target_module"

{
  printf '{ ... }:\n'
  printf '{\n'
  printf '  imports = [ ./app-configs-tailscale.nix ];\n'
  printf '  myConfig.tailscale.enable = true;\n'
  printf '  myConfig.tailscale.user = "%s";\n' "$user_name"
  printf '}\n'
} >"$tmp_override"
install -m 0644 "$tmp_override" "$override_module"

wired=0
if [[ -f "$system_flake" ]]; then
  if grep -q 'app-configs-tailscale-host.nix' "$system_flake"; then
    wired=1
  elif grep -qE 'modules[[:space:]]*=[[:space:]]*\[' "$system_flake"; then
    cp -a "$system_flake" "${system_flake}.bak-${stamp}"
    awk '
      done == 0 && /modules[[:space:]]*=[[:space:]]*\[/ {
        print
        print "        ./app-configs-tailscale-host.nix"
        done=1
        next
      }
      { print }
    ' "$system_flake" >"${system_flake}.tmp"
    mv "${system_flake}.tmp" "$system_flake"
    wired=1
  fi
fi

if (( wired == 0 )); then
  if grep -q 'app-configs-tailscale-host.nix' "$system_config"; then
    wired=1
  else
    cp -a "$system_config" "${system_config}.bak-${stamp}"
    awk '
      done == 0 && seen == 1 && /\[/ {
        sub(/\[/, "[ ./app-configs-tailscale-host.nix")
        done=1
        seen=0
        print
        next
      }
      /imports[[:space:]]*=/ { seen=1 }
      { print }
    ' "$system_config" >"${system_config}.tmp"
    mv "${system_config}.tmp" "$system_config"
    grep -q 'app-configs-tailscale-host.nix' "$system_config" && wired=1
  fi
fi

(( wired == 1 )) || {
  printf 'tailscale-setup: could not add the host module to the NixOS imports list\n' >&2
  exit 1
}

printf '[tailscale-setup:apply] Rebuilding NixOS...\n'
if [[ -f "$system_flake" ]]; then
  nixos-rebuild switch --flake /etc/nixos#nixos
else
  nixos-rebuild switch
fi
printf '[tailscale-setup:apply] Tailscale system layer is ready.\n'
