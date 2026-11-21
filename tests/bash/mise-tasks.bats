#!/usr/bin/env bats
# mise.toml task bodies (T-0020). Each test extracts one task's `run` script
# and runs it with bash in a scratch directory with stubbed tools, so no real
# mise, nix or chezmoi call happens.
#
# Run:  bats tests/bash/mise-tasks.bats

bats_require_minimum_version 1.5.0

setup() {
    command -v python3 >/dev/null || skip "python3 (tomllib) not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    S="$BATS_TEST_TMPDIR/bin"; mkdir -p "$S"
    LOG="$BATS_TEST_TMPDIR/calls.log"; : >"$LOG"
    export LOG
    W="$BATS_TEST_TMPDIR/work"; mkdir -p "$W"
    # keep the real ~/.config selection out of the selection_args calls
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/selection"
}

# task_body <name>: print the task's run script.
task_body() {
    python3 -I -c 'import sys, tomllib
print(tomllib.load(open(sys.argv[1], "rb"))["tasks"][sys.argv[2]]["run"])' \
        "$REPO_ROOT/mise.toml" "$1"
}

# logstub <name> [exit]: a tool that records its arguments and exits.
logstub() {
    printf '#!/usr/bin/env bash\necho "%s $*" >>"$LOG"\nexit %s\n' "$1" "${2:-0}" >"$S/$1"
    chmod +x "$S/$1"
}

# A git repo whose only change is a staged line with trailing whitespace.
staged_whitespace_repo() {
    cd "$W"
    git init -q .
    git -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
    printf 'clean\n' >f.txt
    git add f.txt
    git -c user.name=t -c user.email=t@example.invalid commit -q -m f
    printf 'trailing   \n' >f.txt
    git add f.txt
}

@test "lint:check catches whitespace errors in staged changes, not only unstaged ones" {
    staged_whitespace_repo
    run bash -c "$(task_body lint:check)"
    [ "$status" -ne 0 ]
    [[ "$output" == *"trailing whitespace"* ]]
}

@test "repo:check catches whitespace errors in staged changes before anything else" {
    staged_whitespace_repo
    run bash -c "$(task_body repo:check)"
    [ "$status" -ne 0 ]
    [[ "$output" == *"trailing whitespace"* ]]
}

@test "nix:check and repo:check never rewrite flake.lock" {
    logstub nix
    run env PATH="$S:$PATH" bash -c "$(task_body nix:check)"
    [ "$status" -eq 0 ]
    grep -q -- '^nix flake check .*--no-update-lock-file' "$LOG"
    task_body repo:check | grep -q -- 'nix flake check ./nix --no-update-lock-file'
}

@test "sync:dry-run fails when a tool it needs is missing, after printing the whole preview" {
    cp -R "$REPO_ROOT/ops" "$W/ops"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$W/ops/vscode-extensions.sh"
    for t in bash cat grep sed head cut wc dirname uname tr env; do ln -s "$(command -v "$t")" "$S/$t"; done
    cd "$W"
    HOST_PROFILE=linux-cli PATH="$S" run bash -c "$(task_body sync:dry-run)"
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing: chezmoi"* ]]
    [[ "$output" == *"missing: home-manager or nix/ flake"* ]]
    [[ "$output" == *"missing: mise"* ]]
    [[ "$output" == *"Would run: bash ops/install-git-hooks.sh"* ]]
    [[ "$output" == *"sync preview incomplete: 3 missing item(s)"* ]]
}

@test "sync:dry-run with every tool present succeeds" {
    cp -R "$REPO_ROOT/ops" "$W/ops"; mkdir -p "$W/nix"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$W/ops/vscode-extensions.sh"
    for t in chezmoi home-manager mise; do logstub "$t"; done
    cd "$W"
    HOST_PROFILE=linux-cli PATH="$S:$PATH" run bash -c "$(task_body sync:dry-run)"
    [ "$status" -eq 0 ]
    [[ "$output" != *"missing:"* ]]
    grep -q '^home-manager switch --flake ./nix#linux-cli .*--dry-run' "$LOG"
}

@test "sync:dry-run on macOS previews with a non-root nix build, never darwin-rebuild check" {
    cp -R "$REPO_ROOT/ops" "$W/ops"; mkdir -p "$W/nix"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$W/ops/vscode-extensions.sh"
    for t in chezmoi mise nix darwin-rebuild; do logstub "$t"; done
    cd "$W"
    HOST_PROFILE=macos PATH="$S:$PATH" run bash -c "$(task_body sync:dry-run)"
    [ "$status" -eq 0 ]
    run grep -q '^darwin-rebuild' "$LOG"
    [ "$status" -ne 0 ]
    grep -q '^nix build --no-link --dry-run --no-update-lock-file ./nix#darwinConfigurations.macos.system' "$LOG"
}
