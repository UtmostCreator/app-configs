#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

mkdir -p .copilot-logs
input="$(cat)"

classify_failure() {
  jq -r '
    .toolResult as $r
    | (.toolArgs.command // "") as $cmd
    | (.toolResult.error // "") as $err
    | if ($r.resultType // "") == "timeout" then "transient-runtime"
      elif ($err | ascii_downcase | test("not found|required tools not found|missing")) then "environment-missing"
      elif ($err | ascii_downcase | test("denied|blocked|permission")) then "policy-blocked"
      elif ($err | ascii_downcase | test("unknown option|unknown mode|usage|required|file required")) then "usage-error"
      elif ($err | ascii_downcase | test("network|timeout|timed out|connection|dns|tls")) then "network-remote"
      elif ($cmd | test("validate-ai-config|validate-ai-catalog|generate-ai-catalog|phpstan|psalm|phpunit|pest|eslint|biome|tsc|semgrep|trivy|gitleaks")) then "verification-failed"
      else "unknown"
      end
  ' <<< "$input"
}

failure_category="unknown"
if jq -e '.toolResult.resultType? == "error" or .toolResult.isError? == true' >/dev/null 2>&1 <<< "$input"; then
  failure_category="$(classify_failure)"
fi

jq -c '{
  ts: .timestamp,
  tool: .toolName,
  args: .toolArgs,
  result: (.toolResult.resultType // "unknown"),
  isError: (.toolResult.isError // false),
  durationMs: (.toolResult.durationMs // null),
  error: (.toolResult.error // null),
  failureCategory: $category
}' --arg category "$failure_category" <<< "$input" >> .copilot-logs/tool-usage.jsonl

if jq -e '.toolResult.resultType? == "error" or .toolResult.isError? == true' >/dev/null 2>&1 <<< "$input"; then
  log_json "tool.failure" "$(jq -c --arg category "$failure_category" '{tool: .toolName, args: .toolArgs, result: (.toolResult.resultType // "unknown"), error: (.toolResult.error // null), failureCategory: $category}' <<< "$input")" || true
fi
