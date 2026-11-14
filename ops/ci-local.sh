#!/usr/bin/env bash
# Run ops/ci.sh the way a fresh CI runner sees the repo: tools only from the
# flake-pinned nixpkgs (ops/ci-packages.txt), PATH limited to the Nix store
# plus nix itself, an empty HOME, and no inherited environment. Anything the
# tests silently take from this machine (~/.nix-profile, /run/current-system,
# your HOME) shows up as a failure here. Extra args run instead of ci.sh,
# e.g. `bash ops/ci-local.sh bats tests/bash/clipcopy.bats`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mapfile -t pkgs < <(grep -vE '^\s*(#|$)' ops/ci-packages.txt)
installables=()
for p in "${pkgs[@]}"; do installables+=("nixpkgs#$p"); done

NIXBIN="$(dirname "$(readlink -f "$(command -v nix)")")"
CI_HOME="$(mktemp -d)"
trap 'rm -rf "$CI_HOME"' EXIT
export NIXBIN CI_HOME

if (($#)); then cmd=("$@"); else cmd=(bash ops/ci.sh); fi

# shellcheck disable=SC2016 # expanded by the inner bash, on purpose
nix shell --inputs-from ./nix "${installables[@]}" --command bash -c '
  p="$(printf %s "$PATH" | tr : "\n" | grep "^/nix/store" | paste -sd:):$NIXBIN"
  exec env -i HOME="$CI_HOME" TERM=dumb PATH="$p" CI=true \
    NIX_CONFIG="experimental-features = nix-command flakes" "$@"' ci-local "${cmd[@]}"
