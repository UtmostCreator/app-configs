#!/usr/bin/env bash
# The checks a change must pass before it lands on main. Run by
# .github/workflows/ci.yml and runnable locally (`mise run ci`).
#
#   1. ops/validate-config.sh     repo invariants
#   2. ops/lint-shell.sh          bash -n on every script + ShellCheck
#   3. ops/run-bats.sh            the whole bats suite (scratch HOME)
#   4. nix flake check            formatting + flake outputs
#   5. nix eval of every host     linux-desktop, linux-cli, wsl, macos
#
# Every step runs; the script fails if any step failed, and prints a summary.
# Host closures are evaluated, not built: building them (android-studio,
# browsers) would take hours on a CI runner. sys-update builds the real host.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

results=()
step() { # step <name> <command...>
  local name="$1"; shift
  printf '\n== %s ==\n' "$name"
  if "$@"; then results+=("PASS  $name"); else results+=("FAIL  $name"); fi
}

eval_hosts() {
  local h ok=0
  for h in linux-desktop linux-cli wsl; do
    nix eval --raw "path:$ROOT/nix#homeConfigurations.$h.activationPackage.drvPath" >/dev/null || { echo "eval failed: $h"; ok=1; }
  done
  nix eval --raw "path:$ROOT/nix#darwinConfigurations.macos.config.system.build.toplevel.drvPath" >/dev/null || { echo "eval failed: macos"; ok=1; }
  return "$ok"
}

step "validate-config" bash ops/validate-config.sh
step "lint:shell" bash ops/lint-shell.sh
step "bats" bash ops/run-bats.sh
step "nix flake check" nix flake check "path:$ROOT/nix"
step "host evaluation" eval_hosts

printf '\n== summary ==\n'
printf '%s\n' "${results[@]}"
! printf '%s\n' "${results[@]}" | grep -q '^FAIL'
