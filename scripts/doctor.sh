#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[WARN] %s\n" "$1"; }
fail() {
    printf "[ERROR] %s\n" "$1"
    ERRORS=1
}

check_required_bin() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        ok "binary '$name' found"
    else
        fail "binary '$name' missing"
    fi
}

check_optional_bin() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        ok "binary '$name' found"
    else
        warn "binary '$name' missing"
    fi
}

check_file() {
    local rel="$1"
    if [[ -f "$ROOT_DIR/$rel" ]]; then
        ok "file '$rel' present"
    else
        fail "file '$rel' missing"
    fi
}

check_optional_file() {
    local rel="$1"
    if [[ -f "$ROOT_DIR/$rel" ]]; then
        ok "file '$rel' present"
    else
        warn "file '$rel' missing"
    fi
}

run_required() {
    local label="$1"
    shift

    if "$@"; then
        ok "$label"
    else
        fail "$label failed"
    fi
}

echo "== app-configs doctor =="

echo "-- Required binaries --"
for bin in bash git rg; do
    check_required_bin "$bin"
done

echo "-- Optional binaries --"
# php is optional at the host level. The dotfiles bootstrap does NOT install
# php (mise.toml intentionally does not pin a runtime). When php is absent
# the AI workflow validators below are skipped with a warning, not a fail.
for bin in php just code repomix scc bats actionlint shellcheck shfmt lychee jq yq; do
    check_optional_bin "$bin"
done

echo "-- Core files --"
for file in \
    README.md \
    AGENTS.md \
    docs/ai/project-context.md \
    docs/ai/workflow.md \
    repo-docs/software-and-cli-tools.md \
    repo-docs/vscode-extensions.md \
    .lefthook.yml \
    scripts/hooks/pre-commit.sh \
    scripts/hooks/commit-msg.sh; do
    check_file "$file"
done

echo "-- Dotfiles migration core --"
for file in \
    .chezmoiroot \
    home/personal.yaml.example \
    home/.chezmoiignore \
    home/dot_zshrc.tmpl \
    home/dot_gitconfig.tmpl \
    repo-docs/migration-source-of-truth.md \
    repo-docs/migration-package-ownership.md \
    repo-docs/migration-decisions.md; do
    check_file "$file"
done

echo "-- Optional workflow files --"
for file in \
    justfile \
    Justfile \
    .github/copilot-instructions.md \
    repo-docs/install-dev-tools.sh; do
    check_optional_file "$file"
done

echo "-- AI workflow validation --"
cd "$ROOT_DIR"
if command -v php >/dev/null 2>&1; then
    run_required "AI config validation" php tools/ai/validate-ai-config.php
    run_required "AI catalog validation" php tools/ai/validate-ai-catalog.php
    run_required "AI catalog generated files are current" php tools/ai/generate-ai-catalog.php --check
else
    warn "php missing; AI workflow validators skipped"
    warn "  install php (system pkg, or pin in home/dot_config/mise/config.toml.tmpl)"
    warn "  to run: php tools/ai/validate-ai-config.php"
    warn "         php tools/ai/validate-ai-catalog.php"
    warn "         php tools/ai/generate-ai-catalog.php --check"
fi

echo "-- Secret scanner availability --"
if command -v gitleaks >/dev/null 2>&1; then
    ok "gitleaks found"
elif command -v trufflehog >/dev/null 2>&1; then
    ok "trufflehog found"
else
    warn "no secret scanner found (install gitleaks or trufflehog)"
fi

if [[ "$ERRORS" -ne 0 ]]; then
    exit 1
fi

echo "== doctor finished =="
