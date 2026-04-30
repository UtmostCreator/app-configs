#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

ROOT="${1:-.}"
shift || true

add_winget_paths() {
    local user_name="${USER:-${USERNAME:-}}"
    local base="/c/Users/${user_name}/AppData/Local/Microsoft/WinGet/Packages"
    [[ -d "$base" ]] || return 0
    local dir
    while IFS= read -r dir; do
        case ":$PATH:" in
        *":$dir:"*) ;;
        *) PATH="$PATH:$dir" ;;
        esac
    done < <(find "$base" -maxdepth 3 -type f -name '*.exe' -printf '%h\n' 2>/dev/null | sort -u)
}

add_winget_paths

(cd "$ROOT" && require_clean_secret_scan "$@")

die() {
    printf 'Error: %s\n' "$1" >&2
    exit "${2:-1}"
}

need_bin() {
    local name="$1"
    command -v "$name" >/dev/null 2>&1 || return 1
}

install_hint() {
    local name="$1"
    case "$name" in
    rg) printf '%s\n' 'Install ripgrep: winget install BurntSushi.ripgrep.MSVC | brew install ripgrep | apt install ripgrep' ;;
    scc) printf '%s\n' 'Install scc: winget install BenBoyter.scc | brew install scc | use release binary/Go install on Linux' ;;
    jq) printf '%s\n' 'Install jq: winget install jqlang.jq | brew install jq | apt install jq' ;;
    repomix) printf '%s\n' 'Install repomix: npm install -g repomix' ;;
    *) printf 'Install missing dependency: %s\n' "$name" ;;
    esac
}

required=(bash git rg scc jq repomix)
missing=()
for bin in "${required[@]}"; do
    if ! need_bin "$bin"; then
        missing+=("$bin")
    fi
done

if ((${#missing[@]} > 0)); then
    printf 'Missing required dependencies:\n' >&2
    for bin in "${missing[@]}"; do
        printf '  - %s\n' "$bin" >&2
        install_hint "$bin" >&2
    done
    exit 127
fi

TREE_SCRIPT="$SCRIPT_DIR/repomix-context-tree.sh"

[[ -x "$TREE_SCRIPT" || -f "$TREE_SCRIPT" ]] || die "missing tree script at $TREE_SCRIPT" 2

if ! bash "$TREE_SCRIPT" all "$ROOT" --compress --style xml "$@"; then
    die "context tree generation failed" 3
fi

OUTPUT_DIR="$ROOT/.repomix-context/tree-context"
INDEX_MD="$OUTPUT_DIR/index.md"
PLAN_JSON="$OUTPUT_DIR/tree-plan.json"
BUNDLES_DIR="$OUTPUT_DIR/bundles"

[[ -f "$INDEX_MD" ]] || die "missing generated index: $INDEX_MD" 4
[[ -f "$PLAN_JSON" ]] || die "missing generated plan: $PLAN_JSON" 4
[[ -d "$BUNDLES_DIR" ]] || die "missing generated bundles directory: $BUNDLES_DIR" 4

if ! jq . "$PLAN_JSON" >/dev/null 2>&1; then
    die "invalid JSON: $PLAN_JSON" 5
fi

if ! jq -e 'length > 0' "$PLAN_JSON" >/dev/null 2>&1; then
    die "no routes generated in $PLAN_JSON" 6
fi

cat <<EOF
Context package generated.

Open first:
  .repomix-context/tree-context/index.md

Machine plan:
  .repomix-context/tree-context/tree-plan.json

Bundles:
  .repomix-context/tree-context/bundles/

Wire into AI agents:
  - AGENTS.md
  - .github/copilot-instructions.md
  - docs/ai/copilot-tooling.md
  - docs/ai/context-packing.md
EOF
