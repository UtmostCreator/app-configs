#!/usr/bin/env bash
# Refresh the Nix release lock; --apply also activates a changed release.
set -euo pipefail
case "${1:-}" in
  '') apply=0 ;;
  --apply) apply=1 ;;
  *) echo "Usage: $0 [--apply]" >&2; exit 2 ;;
esac
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
release_lock="$repo_root/nix/packages/codebase-memory-mcp/release.json"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/codebase-memory-mcp-update"
mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
flock -n 9 || { echo 'Another Codebase Memory MCP update is running.'; exit 1; }
release="$(curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 120 \
  https://api.github.com/repos/DeusData/codebase-memory-mcp/releases/latest)"
jq -e '.draft == false and .prerelease == false' <<< "$release" >/dev/null
version="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | ltrimstr("v")' <<< "$release")"
archives='{}'
for pair in x86_64-linux:linux-amd64 aarch64-darwin:darwin-arm64; do
  system="${pair%:*}"; platform="${pair#*:}"
  name="codebase-memory-mcp-ui-${platform}.tar.gz"
  url="https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/${name}"
  digest="$(jq -er --arg name "$name" --arg url "$url" \
    '[.assets[] | select(.name == $name and .browser_download_url == $url)] |
     select(length == 1) | .[0].digest | select(test("^sha256:[0-9a-f]{64}$"))' <<< "$release")"
  archives="$(jq --arg system "$system" --arg url "$url" --arg hash "${digest#sha256:}" \
    '. + {($system): {url: $url, hash: $hash}}' <<< "$archives")"
done
candidate="$(mktemp "${release_lock}.XXXXXX")"
trap 'rm -f "$candidate"' EXIT
jq -n --arg version "$version" --argjson archives "$archives" \
  '{version: $version, archives: $archives}' > "$candidate"
if ! cmp -s "$candidate" "$release_lock"; then
  cp "$release_lock" "$state_dir/previous-release.json"
  chmod 644 "$candidate"
  mv "$candidate" "$release_lock"
fi
printf 'Codebase Memory MCP stable release: %s\n' "$version"
if [[ "$apply" == 1 ]]; then
  installed="$(codebase-memory-mcp --version)"
  if [[ "$installed" != "codebase-memory-mcp $version" ]]; then
    profile="$(bash "$repo_root/ops/detect-host.sh")"
    home-manager switch --flake "path:$repo_root/nix#$profile"
    systemctl --user restart codebase-memory-mcp-ui.service
    curl --fail --silent --show-error --retry 15 --retry-connrefused --retry-delay 1 \
      --max-time 30 http://127.0.0.1:9749/ --output /dev/null
  else
    echo 'Installed version is already current.'
  fi
fi
