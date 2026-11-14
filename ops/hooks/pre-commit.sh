#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[hook] pre-commit checks"

staged_files="$(git diff --cached --name-only --diff-filter=ACM || true)"

if [[ -n "$staged_files" ]]; then
    # Real env files hold secrets; examples/templates are fine.
    env_files="$(grep -E '(^|/)\.env(\.[^/]+)?$' <<<"$staged_files" | grep -vE '\.(example|sample|template|tmpl)$' || true)"
    if [[ -n "$env_files" ]]; then
        echo "[hook] env file staged (use a .env.example instead):"
        echo "$env_files"
        exit 1
    fi

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        if git show ":$file" | rg -n '^(<<<<<<<|=======|>>>>>>>)' >/dev/null 2>&1; then
            echo "[hook] merge conflict markers found in staged blob: $file"
            exit 1
        fi
    done <<<"$staged_files"
fi

if command -v gitleaks >/dev/null 2>&1; then
    gitleaks protect --staged --redact --verbose
elif command -v trufflehog >/dev/null 2>&1; then
    trufflehog git file://. --since-commit HEAD --results=verified,unknown --fail
elif [[ "${APP_CONFIGS_ALLOW_MISSING_SCANNER:-}" == "1" ]]; then
    # Deliberate bootstrap escape hatch: the commit goes through, but loudly.
    {
        echo "[hook] ************************************************************"
        echo "[hook] WARNING: no secret scanner installed; staged changes were NOT scanned."
        echo "[hook] APP_CONFIGS_ALLOW_MISSING_SCANNER=1 is set, so this commit is allowed."
        echo "[hook] Use this only while bootstrapping; install gitleaks (sys-update) next."
        echo "[hook] ************************************************************"
    } >&2
else
    # Security gate: fail closed so a commit never looks scanned when it was not.
    {
        echo "[hook] no secret scanner found (need gitleaks or trufflehog); commit blocked."
        echo "[hook] Install: gitleaks is provided by nix/modules/home/dev.nix; run sys-update."
        echo "[hook] Bootstrap only: APP_CONFIGS_ALLOW_MISSING_SCANNER=1 git commit ... (skips the scan)"
    } >&2
    exit 1
fi

if [[ -n "$staged_files" ]]; then
    # Delegate the project health check to the scripts we actually ship.
    # ops/doctor.sh checks toolchain + tracked-file presence.
    # ops/validate-config.sh enforces the dotfiles-migration invariants.
    # If either script is missing (e.g. partial clone), only warn — never
    # block a commit on infrastructure that is not present.
    for script in ops/doctor.sh ops/validate-config.sh; do
        if [[ -x "$script" ]] || [[ -f "$script" ]]; then
            echo "[hook] running $script"
            bash "$script"
        else
            echo "[hook][warn] $script missing; skipping"
        fi
    done
fi

echo "[hook] pre-commit passed"
