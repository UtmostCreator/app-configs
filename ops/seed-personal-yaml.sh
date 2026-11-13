#!/usr/bin/env bash
# Seed home/.chezmoidata/personal.yaml from the example on first install.
#
# The example is written for one host type, so a plain copy gave every new
# machine its hostProfile and gui values (a new Mac rendered as headless WSL
# and lost its Ghostty/Karabiner configs). This copies the example and sets
# hostProfile and gui from the detected host profile. Comments and all other
# keys are kept. An existing destination is never touched.
#
# Usage: seed-personal-yaml.sh <example> <dest> <host-profile>
set -euo pipefail

example="${1:?usage: seed-personal-yaml.sh <example> <dest> <host-profile>}"
dest="${2:?missing dest}"
profile="${3:?missing host profile}"

case "$profile" in
  macos | linux-desktop) gui=true ;;
  linux-cli | wsl) gui=false ;;
  *)
    printf 'seed-personal-yaml: unsupported host profile: %s\n' "$profile" >&2
    exit 2
    ;;
esac

[[ -e "$dest" ]] && exit 0
[[ -f "$example" ]] || {
  printf 'seed-personal-yaml: example not found: %s\n' "$example" >&2
  exit 1
}

mkdir -p "$(dirname "$dest")"
tmp="$(mktemp "$dest.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
sed -E \
  -e "s/^hostProfile:.*/hostProfile: \"$profile\"/" \
  -e "s/^gui:.*/gui: $gui/" \
  "$example" >"$tmp"
if ! grep -q "^hostProfile: \"$profile\"$" "$tmp" || ! grep -q "^gui: $gui$" "$tmp"; then
  printf 'seed-personal-yaml: example lacks hostProfile/gui keys\n' >&2
  exit 1
fi
mv "$tmp" "$dest"
trap - EXIT
