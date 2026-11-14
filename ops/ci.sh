#!/usr/bin/env bash
# The checks a change must pass before it lands on main. Run by
# .github/workflows/ci.yml and runnable locally (`mise run ci`).
#
#   1. ops/validate-config.sh     repo invariants
#   2. ops/lint-shell.sh          bash -n on every script + ShellCheck
#   3. ops/run-bats.sh            the whole bats suite (scratch HOME)
#   4. nix flake check            native: formatting + this system's checks
#   5. nix flake check            --all-systems --no-build: evaluates every
#                                 system's checks (incl. aarch64-darwin)
#   6. nix build, Linux only      activationPackage of CI_BUILD_PROFILES
#
# Levels: 4 builds the check derivations, which are evaluation sentinels (see
# the CHECK LEVELS comment in nix/flake.nix); 5 only evaluates, and covers
# every home-* and darwin-macos check, so no separate per-host eval step; 6 is
# the one real closure build. CI_BUILD_PROFILES (space-separated, default
# "linux-cli wsl") leaves out linux-desktop: its closure (android-studio,
# browsers, the OpenClaw pin) would take hours on a CI runner, and sys-update
# builds it. The variable only takes effect when running this script directly
# (`mise run ci`); ops/ci-local.sh clears the environment, so CI always uses
# the default. An empty value skips step 6 and reports SKIP.
#
# Every step runs; the script fails if any step failed, and prints a summary.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

results=()
step() { # step <name> <command...>
  local name="$1"; shift
  printf '\n== %s ==\n' "$name"
  if "$@"; then results+=("PASS  $name"); else results+=("FAIL  $name"); fi
}

build_homes() {
  local h ok=0
  # shellcheck disable=SC2086 # word-splitting the profile list is intended
  for h in ${CI_BUILD_PROFILES-linux-cli wsl}; do
    nix build --no-link "path:$ROOT/nix#homeConfigurations.$h.activationPackage" || { echo "build failed: $h"; ok=1; }
  done
  return "$ok"
}

step "validate-config" bash ops/validate-config.sh
step "lint:shell" bash ops/lint-shell.sh
step "bats" bash ops/run-bats.sh
step "nix flake check" nix flake check "path:$ROOT/nix"
step "nix flake check --all-systems --no-build" nix flake check "path:$ROOT/nix" --all-systems --no-build
if [[ "$(uname -s)" != Linux ]]; then
  results+=("SKIP  linux activation build (not Linux)")
elif [[ -z "${CI_BUILD_PROFILES-linux-cli wsl}" ]]; then
  results+=("SKIP  linux activation build (CI_BUILD_PROFILES is empty)")
else
  step "linux activation build" build_homes
fi

printf '\n== summary ==\n'
printf '%s\n' "${results[@]}"
! printf '%s\n' "${results[@]}" | grep -q '^FAIL'
