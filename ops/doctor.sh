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

echo "== app-configs doctor =="

echo "-- Required binaries --"
for bin in bash git rg; do
    check_required_bin "$bin"
done

echo "-- Optional binaries --"
# These are developer conveniences, not bootstrap prerequisites. The dotfiles
# bootstrap does not install or pin them (mise.toml pins no runtime), so a
# missing one is a warning, never a failure.
for bin in php just code repomix scc bats actionlint shellcheck shfmt lychee jq yq; do
    check_optional_bin "$bin"
done

# Core files — repo-owned only. doctor.sh must never require files this repo
# does not own (e.g. the AI Workflow Kit: AGENTS.md, .opencode/**, docs/ai/**,
# PLACEHOLDERS.md), since those are installed by an external project and may be
# absent. AI-kit presence is reported as optional below.
echo "-- Core files --"
for file in \
    README.md \
    repo-docs/software-and-cli-tools.md \
    repo-docs/vscode-extensions.md \
    .lefthook.yml \
    ops/hooks/pre-commit.sh \
    ops/hooks/commit-msg.sh; do
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
    repo-docs/install-dev-tools.sh; do
    check_optional_file "$file"
done

echo "-- AI Workflow Kit (external, optional) --"
# Installed/governed by awesome-ai-utmostcreator, not this repo. Reported only;
# its absence is never a doctor failure.
for file in \
    AGENTS.md \
    .opencode/opencode.json \
    .github/copilot-instructions.md; do
    check_optional_file "$file"
done

cd "$ROOT_DIR"

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
