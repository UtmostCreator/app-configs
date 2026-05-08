#!/usr/bin/env bash
set -euo pipefail
AI_OUTPUT=json bash scripts/ai/ai-search.sh doctor | jq -e '.status=="ok"' >/dev/null
AI_OUTPUT=json bash scripts/ai/ai-search.sh text AGENTS.md . --dry-run | jq -e '.status=="dry_run"' >/dev/null
AI_OUTPUT=json bash scripts/ai/ai-search.sh unsafe-all AGENTS.md . | jq -e '.status=="unsafe_blocked"' >/dev/null
AI_OUTPUT=json bash scripts/ai/ai-search.sh docs "Project Summary" . --fixed | jq -e '.status=="ok" or .status=="no_matches"' >/dev/null
echo "ai-search tests passed"
