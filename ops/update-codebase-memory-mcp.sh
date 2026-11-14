#!/usr/bin/env bash
# Check the latest stable Codebase Memory MCP release.
#
#   update-codebase-memory-mcp.sh           report: print the release, change nothing
#   update-codebase-memory-mcp.sh --apply   refresh the Nix release lock, activate
#                                           the new release and commit the lock
#
# Runs weekly, unattended, from the codebase-memory-mcp-update user timer
# (nix/modules/home/dev.nix). Because it rewrites a tracked file, it follows the
# same contract as sys-update: a lock it changed is either committed (the
# release was applied and the file was clean at HEAD) or put back, never left
# modified, since a dirty worktree stops the next sys-update.
set -euo pipefail

usage() { echo "Usage: $0 [--apply]" >&2; exit 2; }
apply=0
case "$#" in
  0) ;;
  1) [[ "$1" == --apply ]] && apply=1 || usage ;;
  *) usage ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=ops/lib/hm-switch.sh
source "$repo_root/ops/lib/hm-switch.sh"
# shellcheck source=ops/lib/preflight.sh
source "$repo_root/ops/lib/preflight.sh"
# Test guard (ops/lib/preflight.sh): an apply run under bats must stay inside
# the test's scratch directory.
[[ "$apply" == 1 ]] && preflight_bats_guard update-codebase-memory-mcp "to apply" "$repo_root"
# shellcheck source=ops/lib/state-lock.sh
source "$repo_root/ops/lib/state-lock.sh"

release_rel="nix/packages/codebase-memory-mcp/release.json"
release_lock="$repo_root/$release_rel"
state_dir="$(sys_update_state_dir)"
# The lock sys-update takes: the two must never mutate the repo together.
acquire_state_lock "$state_dir" \
  || { echo 'Another sys-update or Codebase Memory MCP update is running.'; exit 1; }

# Scratch files live in the state dir, never inside the repository.
candidate="$(mktemp "$state_dir/codebase-memory-mcp-release.XXXXXX")"
previous="$state_dir/codebase-memory-mcp-previous-release.json"
restore_on_exit=0
cleanup() {
  rm -f "$candidate"
  if [[ "$restore_on_exit" == 1 && -f "$previous" ]]; then
    cp "$previous" "$release_lock"
    echo "Activation failed; restored previous release.json (the update did not complete)." >&2
  fi
}
trap cleanup EXIT

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
jq -n --arg version "$version" --argjson archives "$archives" \
  '{version: $version, archives: $archives}' > "$candidate"

changed=0
cmp -s "$candidate" "$release_lock" || changed=1
printf 'Codebase Memory MCP stable release: %s\n' "$version"

if [[ "$apply" != 1 ]]; then
  if [[ "$changed" == 1 ]]; then
    echo "The release lock would change (run with --apply)."
  else
    echo "The release lock is current."
  fi
  exit 0
fi

# Is the lock ours to commit? Only if it matched HEAD before we touched it.
in_repo=0; lock_was_clean=0
if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  in_repo=1
  if git -C "$repo_root" ls-files --error-unmatch "$release_rel" >/dev/null 2>&1 \
    && git -C "$repo_root" diff --quiet HEAD -- "$release_rel"; then
    lock_was_clean=1
  fi
fi

if [[ "$changed" == 1 ]]; then
  cp "$release_lock" "$previous"
  # cp onto the existing file keeps its mode; the mktemp candidate is 0600.
  cp "$candidate" "$release_lock"
  restore_on_exit=1
fi

installed="$(codebase-memory-mcp --version 2>/dev/null || true)"
if [[ "$installed" != "codebase-memory-mcp $version" ]]; then
  profile="$(bash "$repo_root/ops/detect-host.sh")"
  # Conflict check, then `home-manager switch -b hm-bak` (ops/lib/hm-switch.sh).
  hm_switch "path:$repo_root/nix" "$profile"
  restore_on_exit=0
  activated=1
else
  echo 'Installed version is already current.'
  restore_on_exit=0
  activated=0
fi

# The release is live: commit the lock now, before the restart and health
# check below, so a failure there cannot strand a modified tracked file.
if [[ "$changed" == 1 && "$in_repo" == 1 ]]; then
  if [[ "$lock_was_clean" != 1 ]]; then
    echo "Release lock not committed: it had local edits before the update." >&2
  elif git -C "$repo_root" commit --quiet --only \
    -m "chore(nix): update codebase-memory-mcp release to $version" -- "$release_rel"; then
    echo "Committed the release lock ($(git -C "$repo_root" rev-parse --short HEAD))."
  else
    echo "Release lock not committed (git commit failed); commit $release_rel before the next sys-update." >&2
  fi
fi

# The switch succeeded, so the new generation stays active whatever fails
# below; say so and how to go back.
post_switch_failed() {
  if [[ "$changed" == 1 ]]; then
    echo "Post-switch check failed: new generation (version $version) is still active and release.json records it." >&2
    echo "Recover: fix the service and rerun, or pick the previous generation from 'home-manager generations'." >&2
  else
    echo "Post-switch check failed; the lock was unchanged." >&2
  fi
  exit 1
}

if [[ "$activated" == 1 ]]; then
  # The dashboard service is a Linux systemd user unit only; macOS has none.
  if [[ "$(uname -s)" == Linux ]]; then
    systemctl --user restart codebase-memory-mcp-ui.service || post_switch_failed
    curl --fail --silent --show-error --retry 15 --retry-connrefused --retry-delay 1 \
      --max-time 30 http://127.0.0.1:9749/ --output /dev/null || post_switch_failed
  fi
  # HTTP 200 alone does not prove the right build is running.
  activated_version="$(codebase-memory-mcp --version 2>/dev/null || true)"
  if [[ "$activated_version" != "codebase-memory-mcp $version" ]]; then
    echo "Activated binary reports '$activated_version', expected $version." >&2
    post_switch_failed
  fi
fi
