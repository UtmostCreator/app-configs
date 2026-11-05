#!/usr/bin/env bash
# Refresh the official stable Brave binary lock. Nix verifies the downloaded
# archive against GitHub's SHA-256 digest before building it.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
release_lock="$repo_root/nix/packages/brave/release.json"
release="$(curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 120 \
  https://api.github.com/repos/brave/brave-browser/releases/latest)"
version="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | ltrimstr("v")' <<< "$release")"
jq -e '.draft == false and .prerelease == false' <<< "$release" >/dev/null

archives='{}'
for pair in x86_64-linux:amd64 aarch64-linux:arm64; do
  system="${pair%:*}"; arch="${pair#*:}"
  name="brave-browser_${version}_${arch}.deb"
  url="https://github.com/brave/brave-browser/releases/download/v${version}/${name}"
  digest="$(jq -er --arg name "$name" --arg url "$url" \
    '.assets[] | select(.name == $name and .browser_download_url == $url) |
     .digest | select(test("^sha256:[0-9a-f]{64}$"))' <<< "$release")"
  archives="$(jq --arg system "$system" --arg url "$url" --arg hash "${digest#sha256:}" \
    '. + {($system): {url: $url, hash: $hash}}' <<< "$archives")"
done
candidate="$(mktemp "${release_lock}.XXXXXX")"
trap 'rm -f "$candidate"' EXIT
jq -n --arg version "$version" --argjson archives "$archives" \
  '{version: $version, archives: $archives}' > "$candidate"
if ! cmp -s "$candidate" "$release_lock"; then
  chmod 644 "$candidate"
  mv "$candidate" "$release_lock"
fi
printf 'Brave stable %s\n' "$version"
