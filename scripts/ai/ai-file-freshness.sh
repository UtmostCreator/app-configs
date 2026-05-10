#!/usr/bin/env bash
set -euo pipefail

# ai-file-freshness.sh — Check AI workflow files for staleness
# Reports files that haven't been modified recently relative to active code changes.
# Usage: bash scripts/ai/ai-file-freshness.sh [--days N] [--json]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DAYS=90
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --days=*) DAYS="${1#*=}"; shift ;;
    --json) JSON_MODE=true; shift ;;
    -h|--help)
      echo "Usage: bash scripts/ai/ai-file-freshness.sh [--days N] [--json]"
      echo ""
      echo "Check AI workflow files for staleness."
      echo "Reports files not modified in the last N days (default: 90)."
      echo ""
      echo "Options:"
      echo "  --days N   Staleness threshold in days (default: 90)"
      echo "  --json     Output as JSON"
      echo "  -h, --help Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

cd "$REPO_ROOT"

CUTOFF_EPOCH=$(date -v-"${DAYS}"d +%s 2>/dev/null || date -d "${DAYS} days ago" +%s 2>/dev/null)

AI_PATHS=(
  "AGENTS.md"
  "CLAUDE.md"
  ".github/copilot-instructions.md"
  ".github/instructions"
  ".github/agents"
  ".github/prompts"
  ".github/skills"
  ".opencode"
  "docs/ai"
  "scripts/ai"
  "tools/ai"
  "packages/ai-universal-rules"
  "policies/copilot"
)

stale_files=()
fresh_files=()
missing_files=()

check_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    return
  fi

  local last_modified
  last_modified=$(git log -1 --format="%at" -- "$file" 2>/dev/null || echo "0")

  if [[ "$last_modified" == "0" || -z "$last_modified" ]]; then
    missing_files+=("$file")
    return
  fi

  local last_date
  last_date=$(git log -1 --format="%ai" -- "$file" 2>/dev/null | cut -d' ' -f1)
  local days_ago=$(( ($(date +%s) - last_modified) / 86400 ))

  if [[ "$last_modified" -lt "$CUTOFF_EPOCH" ]]; then
    stale_files+=("${days_ago}d|${file}|${last_date}")
  else
    fresh_files+=("${days_ago}d|${file}|${last_date}")
  fi
}

for ai_path in "${AI_PATHS[@]}"; do
  if [[ -f "$ai_path" ]]; then
    check_file "$ai_path"
  elif [[ -d "$ai_path" ]]; then
    while IFS= read -r -d '' file; do
      check_file "$file"
    done < <(find "$ai_path" -type f -name '*.md' -o -name '*.sh' -o -name '*.php' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.jsonc' | tr '\n' '\0')
  fi
done

# Sort stale files by days (most stale first)
IFS=$'\n' sorted_stale=($(printf '%s\n' "${stale_files[@]}" | sort -t'|' -k1 -rn)); unset IFS

if $JSON_MODE; then
  echo "{"
  echo "  \"threshold_days\": $DAYS,"
  echo "  \"stale_count\": ${#sorted_stale[@]},"
  echo "  \"fresh_count\": ${#fresh_files[@]},"
  echo "  \"untracked_count\": ${#missing_files[@]},"
  echo "  \"stale_files\": ["
  first=true
  for entry in "${sorted_stale[@]}"; do
    IFS='|' read -r days file date <<< "$entry"
    $first || echo ","
    printf '    {"file": "%s", "days_since_modified": "%s", "last_modified": "%s"}' "$file" "$days" "$date"
    first=false
  done
  echo ""
  echo "  ],"
  echo "  \"recommendations\": ["
  if [[ ${#sorted_stale[@]} -gt 0 ]]; then
    echo "    \"Review stale files and update or delete if no longer needed\","
    echo "    \"Run: bash scripts/ai/ai-doc-check.sh --check\","
    echo "    \"Run: php tools/ai/validate-ai-config.php\""
  else
    echo "    \"All AI files are fresh — no action needed\""
  fi
  echo "  ]"
  echo "}"
else
  echo "AI File Freshness Check (threshold: ${DAYS} days)"
  echo "================================================="
  echo ""

  if [[ ${#sorted_stale[@]} -gt 0 ]]; then
    echo "STALE FILES (${#sorted_stale[@]} files not modified in ${DAYS}+ days):"
    echo ""
    printf "  %-6s %-12s %s\n" "AGE" "LAST MOD" "FILE"
    printf "  %-6s %-12s %s\n" "------" "----------" "----"
    for entry in "${sorted_stale[@]}"; do
      IFS='|' read -r days file date <<< "$entry"
      printf "  %-6s %-12s %s\n" "$days" "$date" "$file"
    done
    echo ""
  fi

  if [[ ${#fresh_files[@]} -gt 0 ]]; then
    echo "FRESH FILES (${#fresh_files[@]} files modified within ${DAYS} days):"
    echo ""
    printf "  %-6s %-12s %s\n" "AGE" "LAST MOD" "FILE"
    printf "  %-6s %-12s %s\n" "------" "----------" "----"
    for entry in "${fresh_files[@]}"; do
      IFS='|' read -r days file date <<< "$entry"
      printf "  %-6s %-12s %s\n" "$days" "$date" "$file"
    done
    echo ""
  fi

  if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo "UNTRACKED (${#missing_files[@]} files not in git history):"
    for file in "${missing_files[@]}"; do
      echo "  $file"
    done
    echo ""
  fi

  echo "Summary: ${#sorted_stale[@]} stale, ${#fresh_files[@]} fresh, ${#missing_files[@]} untracked"

  if [[ ${#sorted_stale[@]} -gt 0 ]]; then
    echo ""
    echo "Recommendations:"
    echo "  - Review stale files and update or delete if no longer needed"
    echo "  - Run: bash scripts/ai/ai-doc-check.sh --check"
    echo "  - Run: php tools/ai/validate-ai-config.php"
  fi
fi

exit 0
