#!/usr/bin/env bash
# Check that repository files are referenced at least once elsewhere in the repository.
# Helps surface orphaned docs, unused scripts, and unreferenced assets.
#
# Usage:
#   check-file-refs.sh [options] [path]
#
# Options:
#   --show-referenced   Also print files that ARE referenced (default: unreferenced only)
#   --format json       Emit JSON output instead of plain text
#   --include-dirs DIR  Comma-separated list of dirs to scan (default: all tracked)
#   path                Repository root (default: .)
#
# Exit codes:
#   0  All scannable files are referenced
#   1  One or more unreferenced files found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ai/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<'EOF'
Usage:
  check-file-refs.sh [--show-referenced] [--format json] [path]

Options:
  --show-referenced   Also print files that ARE referenced (default: unreferenced only)
  --format json       Emit JSON output instead of plain text
  path                Repository root (default: .)

Purpose:
  Lists files that are not referenced by any other file in the repository.
  Excludes common config dotfiles that are not expected to be referenced.
  Useful for finding orphaned docs, unused scripts, and dead assets.

Exit codes:
  0  All scannable files are referenced
  1  One or more unreferenced files found

Examples:
  bash scripts/ai/check-file-refs.sh
  bash scripts/ai/check-file-refs.sh --format json
  bash scripts/ai/check-file-refs.sh --show-referenced
EOF
}

# --- defaults ---
SHOW_REFERENCED=0
FORMAT="text"
ROOT="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        --show-referenced) SHOW_REFERENCED=1 ;;
        --format)
            FORMAT="${2:?format required}"
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 2
            ;;
        *) ROOT="$1" ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Exclusion lists
# ---------------------------------------------------------------------------

# Basenames excluded from the scan — config-only dotfiles or generated
# artifacts that are not expected to be explicitly referenced by name.
EXCLUDED_NAMES=(
    ".ai-install-manifest.json"
    ".editorconfig"
    ".eslintrc.json"
    ".gitattributes"
    ".gitignore"
    ".gitleaks.toml"
    ".gitleaksignore"
    ".lefthook.yml"
    ".markdownlint-cli2.yaml"
    ".phpunit.result.cache"
    ".prettierrc.json"
    ".repomixignore"
    ".shellcheckrc"
    ".stylelintrc.json"
    ".opencode"
    "composer.lock"
    "autoload.php"
)

# Directory prefixes excluded from the scan entirely.
    EXCLUDED_DIRS=(
        "vendor/"
        ".repomix-context/"
        ".ai-logs/"
        ".git/"
        ".husky/"
        "docs/generated/"
        "docs/ai/generated/"
    )

require_bins rg git

cd "$ROOT"

# ---------------------------------------------------------------------------
# Build file list
# ---------------------------------------------------------------------------

    # Collect tracked files (bash 3.2 compatible — no mapfile or declare -A).
    ALL_FILES=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && ALL_FILES+=("$line")
    done < <(git ls-files)

    # Exclusion helper: returns 0 if basename is in the excluded list.
    is_excluded_name() {
        local base="$1"
        local name
        for name in "${EXCLUDED_NAMES[@]}"; do
            [[ "$base" == "$name" ]] && return 0
        done
        return 1
    }

    SCAN_FILES=()
    for f in "${ALL_FILES[@]}"; do
    # Skip excluded directory prefixes.
    skip=0
    for d in "${EXCLUDED_DIRS[@]}"; do
        if [[ "$f" == "$d"* ]]; then
            skip=1
            break
        fi
    done
    [[ $skip -eq 1 ]] && continue

        # Skip excluded basenames.
        base="$(basename "$f")"
        if is_excluded_name "$base"; then
            continue
        fi

    SCAN_FILES+=("$f")
done

# ---------------------------------------------------------------------------
# Reference check
# ---------------------------------------------------------------------------
# For each file, check whether its basename (or relative path) appears in
# any tracked text file. We use rg --quiet which exits at the first match,
# making referenced-file checks very fast.

UNREFERENCED=()
REFERENCED=()

for f in "${SCAN_FILES[@]}"; do
    base="$(basename "$f")"

    # Primary check: basename referenced anywhere in the repo (including self
    # is acceptable — a README that mentions its own filename counts).
    if rg --quiet --fixed-strings \
        --glob '!.git' \
        --glob '!vendor' \
        -- "$base" . 2>/dev/null; then
        REFERENCED+=("$f")
        continue
    fi

    # Fallback: try the full relative path (catches cases where only the path
    # form is used, not the bare filename).
    if rg --quiet --fixed-strings \
        --glob '!.git' \
        --glob '!vendor' \
        -- "$f" . 2>/dev/null; then
        REFERENCED+=("$f")
        continue
    fi

    UNREFERENCED+=("$f")
done

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

unreferenced_count=${#UNREFERENCED[@]}
referenced_count=${#REFERENCED[@]}
total=${#SCAN_FILES[@]}

if [[ "$FORMAT" == "json" ]]; then
        if [[ ${#UNREFERENCED[@]} -gt 0 ]]; then
            unreferenced_json="$(printf '%s\n' "${UNREFERENCED[@]}" | jq -Rn '[inputs]')"
        else
            unreferenced_json="[]"
        fi
        if [[ ${#REFERENCED[@]} -gt 0 ]]; then
            referenced_json="$(printf '%s\n' "${REFERENCED[@]}" | jq -Rn '[inputs]')"
        else
            referenced_json="[]"
        fi
    jq -cn \
        --argjson unreferenced "$unreferenced_json" \
        --argjson referenced "$referenced_json" \
        --argjson total "$total" \
        '{
            total: $total,
            unreferenced_count: ($unreferenced | length),
            referenced_count: ($referenced | length),
            unreferenced: $unreferenced,
            referenced: $referenced
        }'
else
    echo "==> Scanned ${total} file(s)"
    echo "==> Referenced: ${referenced_count}  Unreferenced: ${unreferenced_count}"

    if [[ $unreferenced_count -gt 0 ]]; then
        echo ""
        echo "UNREFERENCED FILES:"
        for f in "${UNREFERENCED[@]}"; do
            echo "  $f"
        done
    fi

    if [[ $SHOW_REFERENCED -eq 1 && $referenced_count -gt 0 ]]; then
        echo ""
        echo "REFERENCED FILES:"
        for f in "${REFERENCED[@]}"; do
            echo "  $f"
        done
    fi
fi

[[ $unreferenced_count -eq 0 ]] && exit 0 || exit 1
