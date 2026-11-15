#!/usr/bin/env bash
# Refuse a commit that stages private per-host data. Called by .lefthook.yml
# (pre-commit) as `bash ops/hooks/no-personal-yaml.sh`; it lives in a file
# because lefthook on Windows breaks a multi-line inline script (T-0051).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

# Fail closed: a guard that cannot read the index must not let the commit through.
command -v git >/dev/null 2>&1 || { echo "no-personal-yaml: git not found; refusing the commit" >&2; exit 1; }
names="$(git diff --cached --name-only)" || { echo "no-personal-yaml: git failed; refusing the commit" >&2; exit 1; }
staged="$(printf '%s\n' "$names" | grep -E '^home/\.chezmoidata/(personal|personal\.local|projects)\.yaml$' || true)"
if [[ -n "$staged" ]]; then
    echo "ERROR: private per-host data is staged: $staged"
    echo "It contains real identity, hosts or paths and must never be committed."
    echo "Run: git restore --staged $staged"
    exit 1
fi
