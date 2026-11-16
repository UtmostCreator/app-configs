#!/usr/bin/env bats
# The codebase-memory-mcp UI user unit (nix/modules/home/dev.nix). The binary
# rejects a CBM_ALLOWED_ROOT that does not exist ("daemon session context was
# rejected", exit 1), and Restart=always then loops the unit in `activating`
# forever on a fresh home, so the wrapper must create the root first. The
# wrapper is read from the evaluated flake; nothing is activated.

bats_require_minimum_version 1.5.0

@test "cbm ui wrapper: creates CBM_ALLOWED_ROOT with mkdir -p before it runs the binary" {
    [ "$(uname -s)" = Linux ] || skip "the unit is Linux-only"
    command -v nix >/dev/null || skip "nix not installed"
    REPO_NIX="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/nix" run --separate-stderr nix eval --raw --impure --expr '
      let hm = (builtins.getFlake "path:${builtins.getEnv "REPO_NIX"}").homeConfigurations.linux-cli.config;
      in builtins.readFile (builtins.head hm.systemd.user.services.codebase-memory-mcp-ui.Service.ExecStart)'
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    local mk bin
    mk="$(grep -n '/bin/mkdir -p "\$CBM_ALLOWED_ROOT"' <<<"$output" | head -1 | cut -d: -f1)"
    bin="$(grep -n 'bin/codebase-memory-mcp ' <<<"$output" | head -1 | cut -d: -f1)"
    [ -n "$mk" ]
    [ -n "$bin" ]
    [ "$mk" -lt "$bin" ]
    # export comes first so the mkdir argument is the exported root
    [ "$(grep -n 'export CBM_ALLOWED_ROOT=' <<<"$output" | head -1 | cut -d: -f1)" -lt "$mk" ]
}
