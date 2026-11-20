#!/usr/bin/env bash
set -euo pipefail

managed="$(cat <<'VSCODE_MCP_JSON'
{{ template "vscode/mcp.json" . }}
VSCODE_MCP_JSON
)"

warn() { printf 'chezmoi: VS Code mcp.json: %s; left unchanged\n' "$1" >&2; }

current_file="$(mktemp)"
trap 'rm -f "$current_file"' EXIT
cat >"$current_file"

if ! grep -q '[^[:space:]]' "$current_file"; then
  printf '%s\n' "$managed"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found"
  cat "$current_file"
  exit 0
fi

if ! current_json="$(jq -ce 'if type == "object" then . else error("not an object") end' <"$current_file" 2>/dev/null)"; then
  warn "not a plain JSON object"
  cat "$current_file"
  exit 0
fi

managed_json="$(jq -ce . <<<"$managed")"

if jq -ne --argjson c "$current_json" --argjson m "$managed_json" '$c == ($m * $c)' >/dev/null; then
  cat "$current_file"
else
  jq -n --argjson c "$current_json" --argjson m "$managed_json" '$m * $c'
fi
