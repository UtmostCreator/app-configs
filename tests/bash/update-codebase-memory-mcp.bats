#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FAKE="$BATS_TEST_TMPDIR/repo"
  LOCK="$FAKE/nix/packages/codebase-memory-mcp/release.json"
  mkdir -p "$FAKE/ops" "$FAKE/nix/packages/codebase-memory-mcp" "$BATS_TEST_TMPDIR/bin"
  cp "$REPO_ROOT/ops/update-codebase-memory-mcp.sh" "$FAKE/ops/"
  cp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$LOCK"
  export RELEASE_FIXTURE="$BATS_TEST_TMPDIR/release.json"
  jq '{tag_name: ("v" + .version), draft: false, prerelease: false,
       assets: [.archives[] | {name: (.url | split("/") | last),
         browser_download_url: .url, digest: ("sha256:" + .hash)}]}' \
    "$LOCK" > "$RELEASE_FIXTURE"
  export CURL_LOG="$BATS_TEST_TMPDIR/curl-calls"
  # Dispatch on the requested URL: only the release API serves the fixture;
  # the dashboard answers with DASHBOARD_EXIT; anything else is a test error.
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
url=''
for arg in "$@"; do [[ "$arg" == http* ]] && url="$arg"; done
printf '%s\n' "$url" >> "$CURL_LOG"
case "$url" in
  https://api.github.com/repos/DeusData/codebase-memory-mcp/releases/latest)
    [[ "${FAIL_CURL:-0}" == 1 ]] && exit 22
    cat "$RELEASE_FIXTURE" ;;
  http://127.0.0.1:9749/)
    exit "${DASHBOARD_EXIT:-0}" ;;
  *) echo "unexpected URL: $url" >&2; exit 99 ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# Turn the fixture into release 9.9.9 with checksums that differ from the lock.
new_release_fixture() {
  jq '.tag_name = "v9.9.9"
      | .assets |= (to_entries | map(
          .value.browser_download_url |= sub("/v[0-9.]+/"; "/v9.9.9/")
          | .value.digest = "sha256:" + ((if .key == 0 then "a" else "b" end) * 64)
          | .value))' \
    "$RELEASE_FIXTURE" > "$RELEASE_FIXTURE.tmp"
  mv "$RELEASE_FIXTURE.tmp" "$RELEASE_FIXTURE"
}

@test "official stable metadata refreshes the lock to a genuinely different release" {
  new_release_fixture
  old_version="$(jq -r .version "$LOCK")"
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -eq 0 ]
  [ "$(jq -r .version "$LOCK")" = 9.9.9 ]
  [ "$(jq -r .version "$LOCK")" != "$old_version" ]
  jq -e '[.archives[] | .url | contains("/v9.9.9/")] | all' "$LOCK"
  [ "$(jq -r '.archives."x86_64-linux".hash' "$LOCK")" = "$(printf 'a%.0s' {1..64})" ]
  [ "$(jq -r '.archives."aarch64-darwin".hash' "$LOCK")" = "$(printf 'b%.0s' {1..64})" ]
  [ "$(jq -r .version "$XDG_STATE_HOME/codebase-memory-mcp-update/previous-release.json")" = "$old_version" ]
  cp "$LOCK" "$BATS_TEST_TMPDIR/after-first"
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -eq 0 ]
  cmp "$LOCK" "$BATS_TEST_TMPDIR/after-first"
  run ! rg -q '127.0.0.1' "$CURL_LOG"
}

@test "refreshing the unchanged installed release keeps the lock identical" {
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -eq 0 ]
  cmp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$LOCK"
}

@test "missing checksum leaves the existing release lock untouched" {
  jq 'del(.assets[0].digest)' "$RELEASE_FIXTURE" > "$RELEASE_FIXTURE.tmp"
  mv "$RELEASE_FIXTURE.tmp" "$RELEASE_FIXTURE"
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -ne 0 ]
  cmp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$LOCK"
}

@test "untrusted download URL leaves the release lock untouched" {
  jq '.assets[0].browser_download_url = "https://example.invalid/cbm.tar.gz"' "$RELEASE_FIXTURE" > "$RELEASE_FIXTURE.tmp"
  mv "$RELEASE_FIXTURE.tmp" "$RELEASE_FIXTURE"
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -ne 0 ]
  cmp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$LOCK"
}

@test "network failure leaves the release lock untouched" {
  export FAIL_CURL=1
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -ne 0 ]
  cmp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$LOCK"
}

@test "prereleases are rejected" {
  jq '.prerelease = true' "$RELEASE_FIXTURE" > "$RELEASE_FIXTURE.tmp"
  mv "$RELEASE_FIXTURE.tmp" "$RELEASE_FIXTURE"
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -ne 0 ]
}

@test "apply skips activation when the installed release is current" {
  cat > "$BATS_TEST_TMPDIR/bin/codebase-memory-mcp" <<'STUB'
#!/usr/bin/env bash
jq -r '"codebase-memory-mcp " + (.tag_name | ltrimstr("v"))' "$RELEASE_FIXTURE"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/codebase-memory-mcp"
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"already current"* ]]
}

# Installed 0.0.1, release 9.9.9; the home-manager stub "installs" SWITCH_INSTALLS.
setup_activation() {
  cp "$REPO_ROOT/ops/detect-host.sh" "$FAKE/ops/"
  export HOST_PROFILE=linux-desktop
  export CALL_LOG="$BATS_TEST_TMPDIR/calls"
  export INSTALLED_FILE="$BATS_TEST_TMPDIR/installed-version"
  echo 0.0.1 > "$INSTALLED_FILE"
  new_release_fixture
  cat > "$BATS_TEST_TMPDIR/bin/codebase-memory-mcp" <<'STUB'
#!/usr/bin/env bash
echo "codebase-memory-mcp $(cat "$INSTALLED_FILE")"
STUB
  cat > "$BATS_TEST_TMPDIR/bin/home-manager" <<'STUB'
#!/usr/bin/env bash
printf 'home-manager %s\n' "$*" >> "$CALL_LOG"
[[ "${FAIL_SWITCH:-0}" == 0 ]] || exit "$FAIL_SWITCH"
echo "${SWITCH_INSTALLS:-9.9.9}" > "$INSTALLED_FILE"
STUB
  cat > "$BATS_TEST_TMPDIR/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$CALL_LOG"
exit "${FAIL_SYSTEMCTL:-0}"
STUB
  cat > "$BATS_TEST_TMPDIR/bin/uname" <<'STUB'
#!/usr/bin/env bash
echo "${UNAME_OUT:-Linux}"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/"{codebase-memory-mcp,home-manager,systemctl,uname}
  cp "$LOCK" "$BATS_TEST_TMPDIR/original-lock"
  old_version="$(jq -r .version "$BATS_TEST_TMPDIR/original-lock")"
}

@test "apply on Linux activates a changed release, restarts and probes the dashboard" {
  setup_activation
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -eq 0 ]
  rg -F "home-manager switch --flake path:$FAKE/nix#linux-desktop" "$CALL_LOG"
  rg -F 'systemctl --user restart codebase-memory-mcp-ui.service' "$CALL_LOG"
  rg -Fx 'http://127.0.0.1:9749/' "$CURL_LOG"
  [ "$(jq -r .version "$LOCK")" = 9.9.9 ]
}

@test "apply on macOS switches Home Manager without systemd or the Linux dashboard probe" {
  setup_activation
  export UNAME_OUT=Darwin
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -eq 0 ]
  rg -F 'home-manager switch' "$CALL_LOG"
  run ! rg -q systemctl "$CALL_LOG"
  run ! rg -q '127.0.0.1' "$CURL_LOG"
}

@test "broken dashboard fails apply and restores the previous release lock" {
  setup_activation
  export DASHBOARD_EXIT=7
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -ne 0 ]
  cmp "$LOCK" "$BATS_TEST_TMPDIR/original-lock"
  [[ "$output" == *"new generation (version 9.9.9) is still active, lock restored to version $old_version"* ]]
  [[ "$output" == *"home-manager switch --flake path:$FAKE/nix#linux-desktop"* ]]
  [[ "$output" == *"home-manager generations"* ]]
  [[ "$output" != *"Activation failed; restored previous release.json"* ]]
}

@test "failed systemctl restart reports the active new generation and restores the lock" {
  setup_activation
  export FAIL_SYSTEMCTL=1
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -ne 0 ]
  cmp "$LOCK" "$BATS_TEST_TMPDIR/original-lock"
  [[ "$output" == *"new generation (version 9.9.9) is still active, lock restored to version $old_version"* ]]
  [[ "$output" == *"home-manager switch --flake path:$FAKE/nix#linux-desktop"* ]]
  [[ "$output" == *"home-manager generations"* ]]
  [[ "$output" != *"Activation failed; restored previous release.json"* ]]
  # `run !` replaces $output, so keep it after the output assertions.
  run ! rg -q '127.0.0.1' "$CURL_LOG"
}

@test "failed home-manager switch skips systemd and restores the previous release lock" {
  setup_activation
  export FAIL_SWITCH=1
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -ne 0 ]
  cmp "$LOCK" "$BATS_TEST_TMPDIR/original-lock"
  [[ "$output" == *"restored previous release.json"* ]]
  [[ "$output" != *"new generation"* ]]
  run ! rg -q systemctl "$CALL_LOG"
}

@test "apply fails and restores the lock when the activated binary is the wrong version" {
  setup_activation
  export SWITCH_INSTALLS=0.0.2
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -ne 0 ]
  cmp "$LOCK" "$BATS_TEST_TMPDIR/original-lock"
  [[ "$output" == *"reports 'codebase-memory-mcp 0.0.2', expected 9.9.9"* ]]
  [[ "$output" == *"new generation (version 9.9.9) is still active, lock restored to version $old_version"* ]]
  [[ "$output" == *"home-manager switch --flake path:$FAKE/nix#linux-desktop"* ]]
  [[ "$output" == *"home-manager generations"* ]]
  [[ "$output" != *"Activation failed; restored previous release.json"* ]]
}

@test "failed activation without a lock change leaves the lock alone" {
  setup_activation
  jq '{tag_name: ("v" + .version), draft: false, prerelease: false,
       assets: [.archives[] | {name: (.url | split("/") | last),
         browser_download_url: .url, digest: ("sha256:" + .hash)}]}' "$LOCK" > "$RELEASE_FIXTURE"
  # A stale backup from an earlier run must never be copied over an unchanged lock.
  mkdir -p "$XDG_STATE_HOME/codebase-memory-mcp-update"
  jq '.version = "0.0.5"' "$LOCK" > "$XDG_STATE_HOME/codebase-memory-mcp-update/previous-release.json"
  export FAIL_SWITCH=1
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -ne 0 ]
  cmp "$LOCK" "$BATS_TEST_TMPDIR/original-lock"
  [[ "$output" != *"restored previous release.json"* ]]
}

@test "post-switch failure with an unchanged lock reports it and leaves the lock alone" {
  setup_activation
  jq '{tag_name: ("v" + .version), draft: false, prerelease: false,
       assets: [.archives[] | {name: (.url | split("/") | last),
         browser_download_url: .url, digest: ("sha256:" + .hash)}]}' "$LOCK" > "$RELEASE_FIXTURE"
  export SWITCH_INSTALLS=0.0.2
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -ne 0 ]
  cmp "$LOCK" "$BATS_TEST_TMPDIR/original-lock"
  [[ "$output" == *"Post-switch check failed; the lock was unchanged."* ]]
  [[ "$output" != *"restored"* ]]
}
