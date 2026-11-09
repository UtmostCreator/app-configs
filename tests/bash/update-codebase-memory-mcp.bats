#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FAKE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FAKE/ops" "$FAKE/nix/packages/codebase-memory-mcp" "$BATS_TEST_TMPDIR/bin"
  cp "$REPO_ROOT/ops/update-codebase-memory-mcp.sh" "$FAKE/ops/"
  cp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$FAKE/nix/packages/codebase-memory-mcp/"
  export RELEASE_FIXTURE="$BATS_TEST_TMPDIR/release.json"
  jq '{tag_name: ("v" + .version), draft: false, prerelease: false,
       assets: [.archives[] | {name: (.url | split("/") | last),
         browser_download_url: .url, digest: ("sha256:" + .hash)}]}' \
    "$FAKE/nix/packages/codebase-memory-mcp/release.json" > "$RELEASE_FIXTURE"
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
[[ "${FAIL_CURL:-0}" == 1 ]] && exit 22
cat "$RELEASE_FIXTURE"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "official stable metadata refreshes the Codebase Memory MCP lock idempotently" {
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -eq 0 ]
  cmp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$FAKE/nix/packages/codebase-memory-mcp/release.json"
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -eq 0 ]
}

@test "missing checksum leaves the existing release lock untouched" {
  jq 'del(.assets[0].digest)' "$RELEASE_FIXTURE" > "$RELEASE_FIXTURE.tmp"
  mv "$RELEASE_FIXTURE.tmp" "$RELEASE_FIXTURE"
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -ne 0 ]
  cmp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$FAKE/nix/packages/codebase-memory-mcp/release.json"
}

@test "untrusted download URL leaves the release lock untouched" {
  jq '.assets[0].browser_download_url = "https://example.invalid/cbm.tar.gz"' "$RELEASE_FIXTURE" > "$RELEASE_FIXTURE.tmp"
  mv "$RELEASE_FIXTURE.tmp" "$RELEASE_FIXTURE"
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -ne 0 ]
  cmp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$FAKE/nix/packages/codebase-memory-mcp/release.json"
}

@test "network failure leaves the release lock untouched" {
  export FAIL_CURL=1
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh"
  [ "$status" -ne 0 ]
  cmp "$REPO_ROOT/nix/packages/codebase-memory-mcp/release.json" "$FAKE/nix/packages/codebase-memory-mcp/release.json"
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

@test "apply activates a changed release and restarts the dashboard" {
  cp "$REPO_ROOT/ops/detect-host.sh" "$FAKE/ops/"
  export HOST_PROFILE=linux-desktop
  export CALL_LOG="$BATS_TEST_TMPDIR/calls"
  cat > "$BATS_TEST_TMPDIR/bin/codebase-memory-mcp" <<'STUB'
#!/usr/bin/env bash
echo 'codebase-memory-mcp 0.0.1'
STUB
  cat > "$BATS_TEST_TMPDIR/bin/home-manager" <<'STUB'
#!/usr/bin/env bash
printf 'home-manager %s\n' "$*" >> "$CALL_LOG"
exit "${FAIL_SWITCH:-0}"
STUB
  cat > "$BATS_TEST_TMPDIR/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$CALL_LOG"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/"{codebase-memory-mcp,home-manager,systemctl}
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -eq 0 ]
  rg -F "home-manager switch --flake path:$FAKE/nix#linux-desktop" "$CALL_LOG"
  rg -F 'systemctl --user restart codebase-memory-mcp-ui.service' "$CALL_LOG"
  : > "$CALL_LOG"
  export FAIL_SWITCH=1
  run bash "$FAKE/ops/update-codebase-memory-mcp.sh" --apply
  [ "$status" -ne 0 ]
  ! rg -q systemctl "$CALL_LOG"
}
