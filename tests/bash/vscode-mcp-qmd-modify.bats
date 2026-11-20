#!/usr/bin/env bats

setup() {
    command -v chezmoi >/dev/null || skip "chezmoi not installed"
    command -v jq >/dev/null || skip "jq not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    LINUX_TMPL="$REPO_ROOT/home/dot_config/Code/User/modify_mcp.json.tmpl"
    MAC_TMPL="$REPO_ROOT/home/Library/Application Support/Code/User/modify_mcp.json.tmpl"
    QMD_TMPL="$REPO_ROOT/home/dot_config/qmd/modify_index.yml.tmpl"
    printf '{}\n' >"$BATS_TEST_TMPDIR/chezmoi.json"
    render "$LINUX_TMPL" >"$BATS_TEST_TMPDIR/mcp.sh"
    render "$QMD_TMPL" >"$BATS_TEST_TMPDIR/qmd.sh"
}

render() {
    chezmoi --config "$BATS_TEST_TMPDIR/chezmoi.json" \
        --persistent-state "$BATS_TEST_TMPDIR/state.boltdb" \
        --source "$REPO_ROOT/home" execute-template <"$1"
}

mcp() { bash "$BATS_TEST_TMPDIR/mcp.sh"; }
qmd() { bash "$BATS_TEST_TMPDIR/qmd.sh"; }

@test "mcp: Linux and macOS render the same script, and it passes bash -n" {
    [ "$(render "$MAC_TMPL")" = "$(cat "$BATS_TEST_TMPDIR/mcp.sh")" ]
    bash -n "$BATS_TEST_TMPDIR/mcp.sh"
    bash -n "$BATS_TEST_TMPDIR/qmd.sh"
}

@test "mcp: no file yet writes both repo servers" {
    run mcp </dev/null
    [ "$status" -eq 0 ]
    [ "$(jq -c '.servers | keys' <<<"$output")" = '["codebase-memory-mcp","io.github.ChromeDevTools/chrome-devtools-mcp"]' ]
}

@test "mcp: the template carries no env block, token or secret" {
    run mcp </dev/null
    ! grep -q -i -E '"env"|token|secret|password|apikey' <<<"$output"
}

@test "mcp: a server that already exists keeps its live definition" {
    cur='{"servers":{"codebase-memory-mcp":{"type":"stdio","command":"/opt/custom/cbm"}}}'
    run mcp <<<"$cur"
    [ "$(jq -r '.servers["codebase-memory-mcp"].command' <<<"$output")" = /opt/custom/cbm ]
    [ "$(jq '.servers | length' <<<"$output")" -eq 2 ]
}

@test "mcp: user servers are kept" {
    run mcp <<<'{"servers":{"mine":{"command":"x"}}}'
    [ "$(jq -r '.servers.mine.command' <<<"$output")" = x ]
}

@test "mcp: nothing to add is byte-for-byte the input, and a rerun is stable" {
    mcp </dev/null >"$BATS_TEST_TMPDIR/full.json"
    jq --indent 4 '.servers.mine = {"command":"x"}' "$BATS_TEST_TMPDIR/full.json" | tr -d '\n' >"$BATS_TEST_TMPDIR/in.json"
    mcp <"$BATS_TEST_TMPDIR/in.json" >"$BATS_TEST_TMPDIR/out.json"
    cmp "$BATS_TEST_TMPDIR/in.json" "$BATS_TEST_TMPDIR/out.json"
}

@test "mcp: invalid input is returned unchanged with a warning" {
    run mcp <<<'not json'
    [ "$status" -eq 0 ]
    [[ "$output" == *"left unchanged"* ]]
    [[ "$output" == *"not json"* ]]
}

@test "qmd: no file writes only the models block" {
    run qmd </dev/null
    [ "$status" -eq 0 ]
    [ "$(grep -c '^  ' <<<"$output")" -eq 3 ]
    ! grep -q -E 'path:|/Users/' <<<"$output"
}

@test "qmd: collections are kept and models are appended once" {
    run qmd <<<'collections: {}'
    [[ "$output" == collections* ]]
    [ "$(grep -c '^models:' <<<"$output")" -eq 1 ]
    qmd <<<'collections: {}' >"$BATS_TEST_TMPDIR/one.yml"
    qmd <"$BATS_TEST_TMPDIR/one.yml" >"$BATS_TEST_TMPDIR/two.yml"
    cmp "$BATS_TEST_TMPDIR/one.yml" "$BATS_TEST_TMPDIR/two.yml"
}

@test "qmd: a file with its own models block is returned byte-for-byte" {
    printf 'models:\n  embed: hf:custom/model.gguf\ncollections: {}\n' >"$BATS_TEST_TMPDIR/in.yml"
    qmd <"$BATS_TEST_TMPDIR/in.yml" >"$BATS_TEST_TMPDIR/out.yml"
    cmp "$BATS_TEST_TMPDIR/in.yml" "$BATS_TEST_TMPDIR/out.yml"
}
