#!/usr/bin/env bash
set -euo pipefail

# ai-install-coverage.sh — Track AI install completeness
# Checks which expected files exist, which are missing, and suggests commands.
# Usage: bash scripts/ai/ai-install-coverage.sh [--json] [--fix]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

JSON_MODE=false
FIX_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE=true; shift ;;
    --fix) FIX_MODE=true; shift ;;
    -h|--help)
      echo "Usage: bash scripts/ai/ai-install-coverage.sh [--json] [--fix]"
      echo ""
      echo "Check AI install completeness and report missing files."
      echo ""
      echo "Options:"
      echo "  --json  Output as JSON"
      echo "  --fix   Show exact commands to fix missing files"
      echo "  -h      Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

cd "$REPO_ROOT"

# Expected files for full-governance profile

# Core files
core_files=(
  "AGENTS.md"
  "CLAUDE.md"
  ".github/copilot-instructions.md"
)

# Instruction files
instruction_files=(
  ".github/instructions/ai-file-standards.instructions.md"
  ".github/instructions/ai-scripts.instructions.md"
  ".github/instructions/ai-tooling.instructions.md"
  ".github/instructions/ai-workflow.instructions.md"
  ".github/instructions/approval-boundaries.instructions.md"
  ".github/instructions/architecture.instructions.md"
  ".github/instructions/base.instructions.md"
  ".github/instructions/ci-workflows.instructions.md"
  ".github/instructions/composer.instructions.md"
  ".github/instructions/config-infra.instructions.md"
  ".github/instructions/context-gate.instructions.md"
  ".github/instructions/copilot-script-enforcement.instructions.md"
  ".github/instructions/execution-protocol.instructions.md"
  ".github/instructions/generated-artifacts.instructions.md"
  ".github/instructions/php.instructions.md"
  ".github/instructions/security.instructions.md"
  ".github/instructions/shell.instructions.md"
  ".github/instructions/targets.instructions.md"
  ".github/instructions/testing.instructions.md"
  ".github/instructions/tools.instructions.md"
)

# Agent files
agent_files=(
  ".github/agents/architect.agent.md"
  ".github/agents/implementer.agent.md"
  ".github/agents/researcher.agent.md"
  ".github/agents/reviewer.agent.md"
  ".github/agents/repository-researcher.agent.md"
  ".github/agents/repository-reviewer.agent.md"
)

# Doc files
doc_files=(
  "docs/ai/project-context.md"
  "docs/ai/workflow.md"
  "docs/ai/AI-GUARDRAILS.md"
  "docs/ai/approval-boundaries.md"
  "docs/ai/source-of-truth.md"
  "docs/ai/execution-protocol.md"
  "docs/ai/agents.md"
  "docs/ai/failure-handling.md"
  "docs/ai/script-registry.md"
  "docs/ai/script-registry.json"
  "docs/ai/scripts-reference.md"
  "docs/ai/ai-file-standards.md"
  "docs/ai/adapter-contract.md"
  "docs/ai/generated-artifacts.md"
  "docs/ai/catalog.md"
  "docs/ai/integration-matrix.md"
  "docs/ai/agent-ops-checklist.md"
)

# Script files
script_files=(
  "scripts/ai/common.sh"
  "scripts/ai/ai-search.sh"
  "scripts/ai/ai-verify.sh"
  "scripts/ai/ai-doc-check.sh"
  "scripts/ai/preview-file.sh"
  "scripts/ai/query-usage.sh"
  "scripts/ai/git-forensics.sh"
  "scripts/ai/rg-code.sh"
  "scripts/ai/fd-files.sh"
  "scripts/ai/check-file-refs.sh"
  "scripts/ai/ai-file-freshness.sh"
  "scripts/ai/ai-install-coverage.sh"
  "scripts/ai/pre-tool-use.sh"
  "scripts/ai/post-tool-use.sh"
  "scripts/ai/pack-context.sh"
  "scripts/ai/repo-tool-inventory.sh"
)

# Tool files
tool_files=(
  "tools/ai/ai.php"
  "tools/ai/ai_output_lib.php"
  "tools/ai/validate-ai-config.php"
  "tools/ai/validate-ai-catalog.php"
  "tools/ai/generate-ai-catalog.php"
  "tools/ai/generate-repo-structure.php"
)

# Policy files
policy_files=(
  "policies/copilot/policy.yaml"
  ".github/hooks/tool-policy.json"
)

# Manifest
manifest_files=(
  ".ai-install-manifest.json"
)

present=()
missing=()
missing_categories=()

check_category() {
  local category="$1"
  shift
  local files=("$@")

  for file in "${files[@]}"; do
    if [[ -f "$REPO_ROOT/$file" ]]; then
      present+=("$category|$file")
    else
      missing+=("$category|$file")
      missing_categories+=("$category")
    fi
  done
}

check_category "core" "${core_files[@]}"
check_category "instructions" "${instruction_files[@]}"
check_category "agents" "${agent_files[@]}"
check_category "docs" "${doc_files[@]}"
check_category "scripts" "${script_files[@]}"
check_category "tools" "${tool_files[@]}"
check_category "policies" "${policy_files[@]}"
check_category "manifest" "${manifest_files[@]}"

total=$(( ${#present[@]} + ${#missing[@]} ))
coverage=0
if [[ $total -gt 0 ]]; then
  coverage=$(( ${#present[@]} * 100 / total ))
fi

# Deduplicate categories
IFS=$'\n' unique_missing_cats=($(printf '%s\n' "${missing_categories[@]}" 2>/dev/null | sort -u)); unset IFS

if $JSON_MODE; then
  echo "{"
  echo "  \"total_expected\": $total,"
  echo "  \"present\": ${#present[@]},"
  echo "  \"missing\": ${#missing[@]},"
  echo "  \"coverage_percent\": $coverage,"
  echo "  \"missing_files\": ["
  first=true
  for entry in "${missing[@]}"; do
    IFS='|' read -r category file <<< "$entry"
    $first || echo ","
    printf '    {"category": "%s", "file": "%s"}' "$category" "$file"
    first=false
  done
  echo ""
  echo "  ],"
  echo "  \"fix_commands\": ["
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "    \"php tools/ai/ai.php install --profile full-governance --reinstall --apply --force --allow-placeholders\","
    echo "    \"php tools/ai/ai.php preflight\","
    echo "    \"php tools/ai/ai.php env-check\""
  fi
  echo "  ]"
  echo "}"
else
  echo "AI Install Coverage Report"
  echo "=========================="
  echo ""
  echo "Coverage: ${#present[@]}/$total files present ($coverage%)"
  echo ""

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "MISSING FILES (${#missing[@]}):"
    echo ""
    current_cat=""
    for entry in "${missing[@]}"; do
      IFS='|' read -r category file <<< "$entry"
      if [[ "$category" != "$current_cat" ]]; then
        echo "  [$category]"
        current_cat="$category"
      fi
      echo "    - $file"
    done
    echo ""

    if $FIX_MODE; then
      echo "FIX COMMANDS:"
      echo ""
      echo "  # Reinstall all managed files:"
      echo "  php tools/ai/ai.php install --profile full-governance --reinstall --apply --force --allow-placeholders"
      echo ""
      echo "  # Verify after install:"
      echo "  php tools/ai/ai.php preflight"
      echo "  php tools/ai/ai.php env-check"
      echo "  bash scripts/ai/ai-verify.sh ."
      echo ""
    else
      echo "Run with --fix to see repair commands."
    fi
  else
    echo "All expected files are present."
  fi

  # Show category summary
  echo ""
  echo "Category Breakdown:"
  for cat in core instructions agents docs scripts tools policies manifest; do
    cat_present=0
    cat_total=0
    for entry in "${present[@]}"; do
      IFS='|' read -r c _ <<< "$entry"
      [[ "$c" == "$cat" ]] && ((cat_present++))
    done
    for entry in "${present[@]}" "${missing[@]}"; do
      IFS='|' read -r c _ <<< "$entry"
      [[ "$c" == "$cat" ]] && ((cat_total++))
    done
    if [[ $cat_total -gt 0 ]]; then
      cat_pct=$(( cat_present * 100 / cat_total ))
      printf "  %-15s %d/%d (%d%%)\n" "$cat" "$cat_present" "$cat_total" "$cat_pct"
    fi
  done
fi

if [[ ${#missing[@]} -gt 0 ]]; then
  exit 1
fi
exit 0
