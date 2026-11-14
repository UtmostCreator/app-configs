#!/usr/bin/env bash
# doctor.sh: repo health check.
#
# Usage:
#   bash ops/doctor.sh              # repo/developer health check
#   bash ops/doctor.sh --preflight  # only what must exist BEFORE installation:
#                                   # bash, git, curl and the repo structure.
#                                   # Needs no Home-Manager-provided tool.
#
# Installed-state checks (nix, chezmoi, mise, home-manager, lefthook, jq, yq,
# secret scanner) belong to ops/readiness.sh, not here. Scanner presence is
# enforced by readiness.sh; doctor only advises.
# Exit 0 = ok, 1 = errors found (counted on stderr), 64 = bad arguments (usage).

set -euo pipefail

PREFLIGHT=0
for arg in "$@"; do
    case "$arg" in
        --preflight) PREFLIGHT=1 ;;
        -h | --help)
            echo "Usage: bash ops/doctor.sh [--preflight] [-h|--help]"
            echo "Read-only toolchain and file check; --preflight checks only installation prerequisites."
            exit 0
            ;;
        *)
            echo "doctor.sh: unknown argument: $arg (usage: doctor.sh [--preflight])" >&2
            exit 64
            ;;
    esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[WARN] %s\n" "$1"; }
fail() {
    printf "[ERROR] %s\n" "$1" >&2
    ERRORS=$((ERRORS + 1))
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

echo "== app-configs doctor =="

echo "-- Required binaries --"
for bin in bash git curl; do
    check_required_bin "$bin"
done

if [[ "$PREFLIGHT" -eq 0 ]]; then
    echo "-- Optional binaries --"
    # Developer conveniences, not bootstrap prerequisites. rg, jq, yq and the
    # secret scanner come from Home Manager and are checked by readiness.sh.
    for bin in php code repomix scc bats actionlint shellcheck shfmt lychee; do
        check_optional_bin "$bin"
    done
fi

# Core files owned by this repository.
echo "-- Core files --"
for file in \
    README.md \
    repo-docs/software-and-cli-tools.md \
    repo-docs/vscode-extensions.md \
    .lefthook.yml \
    ops/hooks/pre-commit.sh \
    ops/hooks/commit-msg.sh \
    ops/syncthing-obsidian-stignore.sh \
    reference/syncthing/obsidian.stignore; do
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

cd "$ROOT_DIR"

if [[ "$PREFLIGHT" -eq 0 ]]; then
    echo "-- Optional workflow files --"
    if [[ -f "$ROOT_DIR/repo-docs/install-dev-tools.sh" ]]; then
        ok "file 'repo-docs/install-dev-tools.sh' present"
    else
        warn "file 'repo-docs/install-dev-tools.sh' missing"
    fi

    echo "-- Secret scanner availability --"
    # Advisory here; ops/readiness.sh enforces it, as the pre-commit hook does.
    if command -v gitleaks >/dev/null 2>&1; then
        ok "gitleaks found"
    elif command -v trufflehog >/dev/null 2>&1; then
        ok "trufflehog found"
    else
        warn "no secret scanner found (install gitleaks or trufflehog)"
    fi
fi

if [[ "$ERRORS" -ne 0 ]]; then
    echo "doctor: $ERRORS error(s)" >&2
    exit 1
fi

echo "== doctor finished =="
