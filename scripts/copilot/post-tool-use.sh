#!/usr/bin/env bash
set -euo pipefail

mkdir -p .copilot-logs
input="$(cat)"

jq -c '{ts: .timestamp, tool: .toolName, args: .toolArgs, result: (.toolResult.resultType // "unknown")}' <<< "$input" >> .copilot-logs/tool-usage.jsonl
