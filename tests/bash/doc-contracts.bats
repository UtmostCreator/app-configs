#!/usr/bin/env bats
# Docs and config must not promise things the repo does not have.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    cd "$REPO_ROOT"
}

@test "every 'mise run <task>' named in docs, workflows and scripts is a real task" {
    tasks="$(sed -nE 's/^\[tasks\."?([^]"]+)"?\]$/\1/p' mise.toml | sort -u)"
    missing=""
    while IFS= read -r t; do
        grep -qxF "$t" <<<"$tasks" || missing+=" $t"
    done < <(git ls-files -- '*.md' '*.yml' '*.yaml' '*.sh' '*.fish' '*.tmpl' ':!docs/plans/**' ':!docs/research/**' |
        xargs grep -ohE 'mise run [a-z][a-z0-9:_-]*' 2>/dev/null | awk '{print $3}' | sort -u)
    [ -z "$missing" ] || { echo "named but not defined in mise.toml:$missing"; return 1; }
}

@test "private per-host chezmoi data files are gitignored" {
    for f in home/.chezmoidata/personal.yaml home/.chezmoidata/personal.local.yaml home/.chezmoidata/projects.yaml; do
        git check-ignore -q "$f" || { echo "not ignored: $f"; return 1; }
    done
}

@test "the pre-commit guard refuses staged private data files" {
    grep -q 'projects' .lefthook.yml || { echo ".lefthook.yml does not guard projects.yaml"; return 1; }
}

@test "the repo carries no PHP code (log-errors lives in restsift)" {
    run git ls-files -- '*.php' 'pint.json' 'ops/projects/logging/errors/*'
    [ -z "$output" ] || { echo "unexpected: $output"; return 1; }
}
