#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[hook] pre-commit checks"

blob=""
snap=""
staged_list=""
tmp_file=""
cr=$'\r' # CRLF files end markers with \r
trap 'rm -f "$blob" "$staged_list" "$tmp_file"; [[ -z "$snap" ]] || rm -rf "$snap"' EXIT

# NUL-separated so non-ASCII or odd names are not C-quoted by git.
staged_list="$(mktemp "${TMPDIR:-/tmp}/app-configs-staged-names.XXXXXX")"
git diff --cached --name-only -z --diff-filter=ACM >"$staged_list"

if [[ -s "$staged_list" ]]; then
    # Real env files hold secrets; examples/templates are fine.
    env_found=0
    while IFS= read -r -d '' file; do
        if [[ "$file" =~ (^|/)\.env(\.[^/]+)?$ && ! "$file" =~ \.(example|sample|template|tmpl)$ ]]; then
            [[ "$env_found" == 1 ]] || echo "[hook] env file staged (use a .env.example instead):"
            env_found=1
            printf '%s\n' "$file"
        fi
    done <"$staged_list"
    [[ "$env_found" == 0 ]] || exit 1

    # Only the <<<<<<< / >>>>>>> markers are checked: a lone ======= is also a
    # Markdown heading underline. Scan a temp copy of the staged blob with grep
    # (no pipe, so no SIGPIPE; grep is POSIX, so a missing rg cannot fail open).
    blob="$(mktemp "${TMPDIR:-/tmp}/app-configs-blob.XXXXXX")"
    while IFS= read -r -d '' file; do
        git show ":$file" >"$blob"
        if grep -aE "^(<{7}|>{7})( |${cr}?\$)" "$blob" >/dev/null; then
            echo "[hook] merge conflict markers found in staged blob: $file"
            exit 1
        fi
    done <"$staged_list"
fi

# Secrets are scanned when commits are pushed (ops/hooks/pre-push.sh), not
# here: a commit stays fast, and nothing leaves the machine unscanned.

if [[ -s "$staged_list" ]]; then
    # Delegate the project health check to the scripts we actually ship.
    # ops/doctor.sh checks toolchain + file presence.
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
