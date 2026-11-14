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
lock_changed=0
if ! cmp -s "$candidate" "$release_lock"; then
  lock_changed=1
  cp "$release_lock" "$state_dir/previous-release.json"
  chmod 644 "$candidate"
  mv "$candidate" "$release_lock"
fi
printf 'Codebase Memory MCP stable release: %s\n' "$version"
if [[ "$apply" == 1 ]]; then
  installed="$(codebase-memory-mcp --version)"
  if [[ "$installed" != "codebase-memory-mcp $version" ]]; then
    profile="$(bash "$repo_root/ops/detect-host.sh")"
    # A lock that was never built and is not live must not stay in the worktree
    # (it would block the next sys-update); restore the previous lock.
    restore_lock() {
      [[ "$lock_changed" == 1 ]] && cp "$state_dir/previous-release.json" "$release_lock"
      return 0
    }
    # The switch itself failed: no new generation was activated.
    switch_failed() {
      if [[ "$lock_changed" == 1 ]]; then
        restore_lock
        echo "Activation failed; restored previous release.json." >&2
      fi
      exit 1
    }
    # The switch succeeded, so the new generation stays active even though the
    # lock is restored; say so and how to recover.
    post_switch_failed() {
      if [[ "$lock_changed" == 1 ]]; then
        local previous
        restore_lock
        previous="$(jq -r .version "$release_lock")"
        echo "Post-switch check failed: new generation (version $version) is still active, lock restored to version $previous." >&2
        echo "Recover: run 'home-manager switch --flake path:$repo_root/nix#$profile' with the restored lock, or pick the previous one from 'home-manager generations'." >&2
      else
        echo "Post-switch check failed; the lock was unchanged." >&2
      fi
      exit 1
    }
    home-manager switch --flake "path:$repo_root/nix#$profile" || switch_failed
    # The dashboard service is a Linux systemd user unit only; macOS has none.
    if [[ "$(uname -s)" == Linux ]]; then
      systemctl --user restart codebase-memory-mcp-ui.service || post_switch_failed
      curl --fail --silent --show-error --retry 15 --retry-connrefused --retry-delay 1 \
        --max-time 30 http://127.0.0.1:9749/ --output /dev/null || post_switch_failed
    fi
    # HTTP 200 alone does not prove the right build is running.
    activated="$(codebase-memory-mcp --version || true)"
    if [[ "$activated" != "codebase-memory-mcp $version" ]]; then
      echo "Activated binary reports '$activated', expected $version." >&2
      post_switch_failed
    fi
  else
    echo 'Installed version is already current.'
  fi
fi
