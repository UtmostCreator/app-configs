#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
tool_name="$(jq -r '.toolName // empty' <<< "$input")"
tool_args_raw="$(jq -c '.toolArgs // {}' <<< "$input")"

if [[ "$tool_name" != "bash" ]]; then
  exit 0
fi

command="$(jq -r '.command // empty' <<< "$tool_args_raw")"

if grep -Eq '(^|[[:space:]])(sudo|mkfs|dd|shutdown|reboot)([[:space:]]|$)' <<< "$command"; then
  echo '{"permissionDecision":"deny","permissionDecisionReason":"dangerous system command blocked by repo policy"}'
  exit 0
fi

if grep -Eq '(^|[[:space:]])rm([[:space:]]|$)' <<< "$command"; then
  echo '{"permissionDecision":"deny","permissionDecisionReason":"rm blocked by repo policy"}'
  exit 0
fi

if grep -Eq '^git push([[:space:]]|$)' <<< "$command"; then
  echo '{"permissionDecision":"deny","permissionDecisionReason":"git push blocked by repo policy"}'
  exit 0
fi

if grep -Eq '^(rg|fd|fzf|bat|jq|yq|ast-grep|semgrep|git grep|git log|git blame|git show|gh |delta|eza)\b' <<< "$command"; then
  echo '{"permissionDecision":"allow"}'
  exit 0
fi

if grep -Eq '^(\./)?scripts/copilot/' <<< "$command"; then
  echo '{"permissionDecision":"allow"}'
  exit 0
fi

exit 0
