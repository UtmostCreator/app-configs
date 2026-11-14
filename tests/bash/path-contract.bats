#!/usr/bin/env bats
# Every repo-relative path that code or docs name must exist (bug type 7,
# "stale references": docs and config pointing at removed scripts, paths or
# aliases). The scanner is tests/lib/find-missing-paths.py; its header lists
# exactly what it reads (shell, nix, mise.toml, markdown). Existence is judged
# against the tracked + untracked-not-ignored file set, so a local gitignored
# file cannot hide a reference that breaks in CI.
#
# Each seeded test copies the repository, injects one stale reference and
# asserts the scan reports it.

load ../lib/contract

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCAN="$REPO_ROOT/tests/lib/find-missing-paths.py"
    ALLOW="$BATS_TEST_TMPDIR/allow.txt"
    # source-glob | path-glob | reason. Keep this list minimal; each entry must
    # still match something (the scan runs with --check-allow-used).
    cat >"$ALLOW" <<'EOF'
# Gitignored per-host data. Docs name it, chezmoi reads it, the repo cannot
# contain it (lefthook refuses to commit it).
*              | home/.chezmoidata/*       | gitignored local data
# Historical records of the migration: they name files that were later removed
# (ops/check-source-of-truth.sh, ops/git-branch-origin.sh) or renamed
# (home/dot_bashrc is now dot_bashrc.tmpl) and say so.
repo-docs/migration-*.md | *               | historical record, kept as written
EOF
}

scan() { python3 -I "$SCAN" "$1" --allow "$ALLOW" --check-allow-used; }

@test "every repo path referenced by code and docs exists" {
    run scan "$REPO_ROOT"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "the scanner reads the sources it claims to (a scan of nothing would pass)" {
    run python3 -I "$SCAN" "$REPO_ROOT"
    # Only the allowlisted references are missing (docs naming gitignored data
    # and the historical migration records), so markdown was walked.
    [[ "$output" == *"(path)"* ]]
    [[ "$output" == *"repo-docs/migration-source-of-truth.md"* ]]
    [[ "$output" == *"home/.chezmoidata/personal.yaml"* ]]
}

@test "seeded: a bash call to a missing script is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\nbash ops/ghost-script.sh\n' >>"$copy/ops/doctor.sh"
    run scan "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ops/doctor.sh:"*"ops/ghost-script.sh (literal)"* ]]
}

@test "seeded: a missing \$ROOT-based path and a missing sourced sibling are caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\nROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"\nsource "$ROOT/ops/lib/ghost.sh"\nsource "${BASH_SOURCE[0]%%/*}/ghost2.sh"\n' >>"$copy/ops/cleanup.sh"
    run scan "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *'$ROOT/ops/lib/ghost.sh (var)'* ]]
}

@test "seeded: a missing script called from a template is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf 'function ghost\n    bash "$DOTFILES_DIR/ops/ghost-tmpl.sh" $argv\nend\n' >>"$copy/home/dot_config/fish/conf.d/dotfiles.fish.tmpl"
    run scan "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *'$DOTFILES_DIR/ops/ghost-tmpl.sh (var)'* ]]
}

@test "seeded: a mise task pointing at a missing script is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\n[tasks.ghost]\ndescription = "x"\nrun = "bash ops/ghost-task.sh"\n' >>"$copy/mise.toml"
    run scan "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *"mise.toml:"*"ops/ghost-task.sh (mise)"* ]]
}

@test "seeded: a missing nix path literal is caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\n# x\n  ghost = builtins.readFile ./scripts/ghost.sh;\n' >>"$copy/nix/modules/home/dev.nix"
    run scan "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nix/modules/home/dev.nix:"*"./scripts/ghost.sh (nix)"* ]]
}

@test "seeded: a dead markdown link and a dead backticked path are caught" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    printf '\nSee [gone](docs/guides/ghost.md) and `ops/ghost-doc.sh`.\n' >>"$copy/README.md"
    run scan "$copy"
    [ "$status" -ne 0 ]
    [[ "$output" == *"README.md:"*"docs/guides/ghost.md (link)"* ]]
    [[ "$output" == *"README.md:"*"ops/ghost-doc.sh (path)"* ]]
}

@test "seeded: docs/plans and docs/research are not scanned" {
    local copy="$BATS_TEST_TMPDIR/repo"; repo_copy "$copy"
    mkdir -p "$copy/docs/plans"
    printf 'old plan: `ops/ghost-plan.sh`\n' >"$copy/docs/plans/old.md"
    run scan "$copy"
    [[ "$output" != *ghost-plan* ]]
}

@test "an allowlist entry that matches nothing fails the scan" {
    printf '*|ops/never-referenced.sh|stale\n' >>"$ALLOW"
    run scan "$REPO_ROOT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"unused allowlist entry"*"ops/never-referenced.sh"* ]]
}
