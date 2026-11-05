#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FAKE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FAKE/ops" "$FAKE/nix/packages/brave" "$BATS_TEST_TMPDIR/bin"
  cp "$REPO_ROOT/ops/update-brave.sh" "$FAKE/ops/"
  cp "$REPO_ROOT/nix/packages/brave/release.json" "$FAKE/nix/packages/brave/"
  export RELEASE_FIXTURE="$BATS_TEST_TMPDIR/release.json"
  jq '{tag_name: ("v" + .version), draft: false, prerelease: false,
       assets: [.archives[] | {name: (.url | split("/") | last),
         browser_download_url: .url, digest: ("sha256:" + .hash)}]}' \
    "$FAKE/nix/packages/brave/release.json" > "$RELEASE_FIXTURE"
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
[[ "${FAIL_CURL:-0}" == 1 ]] && exit 22
cat "$RELEASE_FIXTURE"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "official stable metadata refreshes the browser lock idempotently" {
  run bash "$FAKE/ops/update-brave.sh"
  [ "$status" -eq 0 ]
  cmp "$REPO_ROOT/nix/packages/brave/release.json" "$FAKE/nix/packages/brave/release.json"
  run bash "$FAKE/ops/update-brave.sh"
  [ "$status" -eq 0 ]
}

@test "missing checksum leaves the existing release lock untouched" {
  jq 'del(.assets[0].digest)' "$RELEASE_FIXTURE" > "$RELEASE_FIXTURE.tmp"
  mv "$RELEASE_FIXTURE.tmp" "$RELEASE_FIXTURE"
  run bash "$FAKE/ops/update-brave.sh"
  [ "$status" -ne 0 ]
  cmp "$REPO_ROOT/nix/packages/brave/release.json" "$FAKE/nix/packages/brave/release.json"
}

@test "untrusted download URL leaves the release lock untouched" {
  jq '.assets[0].browser_download_url = "https://example.invalid/browser.deb"' "$RELEASE_FIXTURE" > "$RELEASE_FIXTURE.tmp"
  mv "$RELEASE_FIXTURE.tmp" "$RELEASE_FIXTURE"
  run bash "$FAKE/ops/update-brave.sh"
  [ "$status" -ne 0 ]
  cmp "$REPO_ROOT/nix/packages/brave/release.json" "$FAKE/nix/packages/brave/release.json"
}

@test "network failure leaves the release lock untouched" {
  export FAIL_CURL=1
  run bash "$FAKE/ops/update-brave.sh"
  [ "$status" -ne 0 ]
  cmp "$REPO_ROOT/nix/packages/brave/release.json" "$FAKE/nix/packages/brave/release.json"
}

@test "prereleases are rejected" {
  jq '.prerelease = true' "$RELEASE_FIXTURE" > "$RELEASE_FIXTURE.tmp"
  mv "$RELEASE_FIXTURE.tmp" "$RELEASE_FIXTURE"
  run bash "$FAKE/ops/update-brave.sh"
  [ "$status" -ne 0 ]
}
