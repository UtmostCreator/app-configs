#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[hook] pre-commit checks"

staged_files="$(git diff --cached --name-only --diff-filter=ACM || true)"

# 1) Fast file sanity checks (staged files only)
if [[ -n "$staged_files" ]] && command -v rg >/dev/null 2>&1; then
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    if rg -n '(<<<<<<<|=======|>>>>>>>)' "$file" >/dev/null 2>&1; then
      echo "[hook] merge conflict markers found in $file"
      exit 1
    fi
  done <<< "$staged_files"
fi

# 2) PHP formatting/lint (best-effort)
if [[ -x ./vendor/bin/pint ]]; then
  ./vendor/bin/pint --test
else
  echo "[hook] vendor/bin/pint not found (skip)"
fi

if command -v php >/dev/null 2>&1; then
  changed_php=$(git diff --cached --name-only --diff-filter=ACM | rg '\.php$' || true)
  if [[ -n "$changed_php" ]]; then
    while IFS= read -r file; do
      [[ -f "$file" ]] && php -l "$file" >/dev/null
    done <<< "$changed_php"
  fi
else
  echo "[hook] php binary not found (skip lint)"
fi

# 3) Secret scanning (pick one tool)
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks protect --staged --redact --verbose
elif command -v trufflehog >/dev/null 2>&1; then
  trufflehog git file://. --since-commit HEAD~1 --results=verified,unknown --fail
else
  echo "[hook] neither gitleaks nor trufflehog found (skip secret scan)"
fi

echo "[hook] pre-commit passed"
