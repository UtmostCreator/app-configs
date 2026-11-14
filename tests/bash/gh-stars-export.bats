#!/usr/bin/env bats
# home/dot_local/bin/executable_gh-stars-export: back up GitHub stars (gh + jq).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TOOLS="$BATS_TEST_TMPDIR/tools"; mkdir -p "$TOOLS"
    cp "$REPO_ROOT/home/dot_local/bin/executable_gh-stars-export" "$TOOLS/gh-stars-export"
    chmod +x "$TOOLS/gh-stars-export"
    # gh stub: authenticated, two pages of starred repos
    cat >"$TOOLS/gh" <<'SH'
#!/bin/sh
case "$1" in
  auth) [ -n "${GH_STUB_NOAUTH:-}" ] && exit 1; exit 0 ;;
  api) [ -n "${GH_STUB_FAIL:-}" ] && exit 1
       echo '[[{"starred_at":"2026-01-01T00:00:00Z","repo":{"full_name":"a/one","html_url":"u1","stargazers_count":5}}],[{"starred_at":"2026-01-02T00:00:00Z","repo":{"full_name":"b/two","html_url":"u2","stargazers_count":7}}]]' ;;
esac
SH
    chmod +x "$TOOLS/gh"
    OUT="$BATS_TEST_TMPDIR/out"; mkdir -p "$OUT"; cd "$OUT"
}

ghs() { PATH="$TOOLS:$PATH" run gh-stars-export "$@"; }

@test "default writes compact metadata for every page" {
    ghs
    [ "$status" -eq 0 ]
    [ "$(jq -r '.[].full_name' github-stars.json | tr '\n' ' ')" = "a/one b/two " ]
    [ "$(jq -r '.[0].stars' github-stars.json)" = "5" ]
}

@test "--format both --out-dir writes both files" {
    ghs --format both --out-dir backups
    [ "$status" -eq 0 ]
    [ "$(jq length backups/github-stars.full.json)" = "2" ]
    [ "$(jq length backups/github-stars.json)" = "2" ]
    [ -z "$(ls backups | grep -v '^github-stars\(\.full\)\?\.json$')" ]   # no temp files left
}

@test "a failed fetch leaves no partial or temp files" {
    GH_STUB_FAIL=1 ghs --format both --out-dir backups
    [ "$status" -ne 0 ]
    [ -z "$(ls -A backups)" ]
}

@test "unauthenticated gh stops with the login hint" {
    GH_STUB_NOAUTH=1 ghs
    [ "$status" -eq 1 ]
    [[ "$output" == *"gh auth login"* ]]
}

@test "bad arguments exit 2" {
    ghs --format weird
    [ "$status" -eq 2 ]
    ghs --format both --out x.json
    [ "$status" -eq 2 ]
    ghs --bogus
    [ "$status" -eq 2 ]
}
