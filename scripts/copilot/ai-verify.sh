#!/usr/bin/env bash
# Project-aware verification gate for AI-driven changes.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

root="${1:-.}"
cd "$root"

run_step() {
    local label="$1"
    shift
    echo "==> $label"
    if ! "$@"; then
        echo "WARN: $label failed" >&2
    fi
}

echo "==> repository"
git status --short || true

if command -v shellcheck >/dev/null 2>&1; then
    while IFS= read -r script; do
        [[ -n "$script" ]] || continue
        run_step "shellcheck $script" shellcheck "$script"
    done < <(git ls-files '*.sh')
fi

if command -v shfmt >/dev/null 2>&1; then
    while IFS= read -r script; do
        [[ -n "$script" ]] || continue
        run_step "shfmt -d $script" shfmt -d "$script"
    done < <(git ls-files '*.sh')
fi

if command -v actionlint >/dev/null 2>&1; then
    run_step 'actionlint' actionlint
fi

if command -v lychee >/dev/null 2>&1; then
    run_step 'bash scripts/run-link-check.sh' bash scripts/run-link-check.sh
fi

if [[ -f composer.json ]]; then
    if [[ -x vendor/bin/pint ]]; then run_step 'vendor/bin/pint --test' vendor/bin/pint --test; fi
    if [[ -x vendor/bin/phpstan ]]; then run_step 'vendor/bin/phpstan analyse --memory-limit=1G' vendor/bin/phpstan analyse --memory-limit=1G; fi
    if [[ -x vendor/bin/psalm ]]; then run_step 'vendor/bin/psalm --no-cache' vendor/bin/psalm --no-cache; fi
    if [[ -x vendor/bin/phpunit ]]; then run_step 'vendor/bin/phpunit' vendor/bin/phpunit; fi
    if [[ -x vendor/bin/pest ]]; then run_step 'vendor/bin/pest' vendor/bin/pest; fi
    if command -v composer >/dev/null 2>&1; then
        run_step 'composer validate --strict' composer validate --strict
        run_step 'composer audit' composer audit
    fi
fi

if [[ -f package.json ]]; then
    if command -v pnpm >/dev/null 2>&1; then
        run_step 'pnpm exec tsc --noEmit' pnpm exec tsc --noEmit
        run_step 'pnpm exec eslint .' pnpm exec eslint .
        run_step 'pnpm exec biome check .' pnpm exec biome check .
        run_step 'pnpm exec knip' pnpm exec knip
        run_step 'pnpm test' pnpm test
    elif command -v npm >/dev/null 2>&1; then
        run_step 'npm run typecheck --if-present' npm run typecheck --if-present
        run_step 'npm run lint --if-present' npm run lint --if-present
        run_step 'npm test --if-present' npm test --if-present
    fi
fi

if command -v gitleaks >/dev/null 2>&1; then run_step 'gitleaks detect --source . --redact --no-banner' gitleaks detect --source . --redact --no-banner; fi
if command -v trivy >/dev/null 2>&1; then run_step 'trivy fs --scanners vuln,misconfig,secret .' trivy fs --scanners vuln,misconfig,secret .; fi
if command -v semgrep >/dev/null 2>&1; then run_step 'semgrep scan --config auto .' semgrep scan --config auto .; fi
if command -v osv-scanner >/dev/null 2>&1; then run_step 'osv-scanner scan --lockfile=.' osv-scanner scan --lockfile=.; fi

echo '==> done'
