#!/usr/bin/env bash
# Unified search wrapper so agents do not guess which discovery tool to call.

set -euo pipefail
# shellcheck source=scripts/ai/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
    cat <<'EOF'
Usage:
  ai-search.sh MODE QUERY [root] [options]
  ai-search.sh doctor

Modes:
  text files struct tracked changed staged docs tests config schema secrets unsafe-all all doctor
EOF
}

mode="${1:-}"
query="${2:-}"
root="${3:-.}"
shift $(( $# > 0 ? 1 : 0 )) || true
[[ "$mode" == "doctor" ]] || shift $(( $# > 0 ? 1 : 0 )) || true
[[ "$mode" == "doctor" ]] || shift $(( $# > 0 ? 1 : 0 )) || true

JSON_MODE="${AI_OUTPUT:-}" ; JSON_MODE="${JSON_MODE,,}"
DRY_RUN=0; FIXED=0; CONTEXT=2; MAX=100; MAX_COLUMNS=300; MAX_FILESIZE="1M"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE="json"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --fixed|-F) FIXED=1; shift ;;
    --context|-C) CONTEXT="${2:-2}"; shift 2 ;;
    --context=*|-C=*) CONTEXT="${1#*=}"; shift ;;
    --max|-m) MAX="${2:-100}"; shift 2 ;;
    --max=*|-m=*) MAX="${1#*=}"; shift ;;
    -m[0-9]*) MAX="${1#-m}"; shift ;;
    --max-columns) MAX_COLUMNS="${2:-300}"; shift 2 ;;
    --max-columns=*) MAX_COLUMNS="${1#*=}"; shift ;;
    --max-filesize) MAX_FILESIZE="${2:-1M}"; shift 2 ;;
    --max-filesize=*) MAX_FILESIZE="${1#*=}"; shift ;;
    *) die "unknown option: $1" ;;
  esac
done

emit() { jq -nc --arg status "$1" --arg tool "$2" --arg mode "$mode" --arg query "$query" --arg root "$root" --argjson matches "${3:-[]}" --argjson warnings "${4:-[]}" --argjson errors "${5:-[]}" --argjson dry "$DRY_RUN" '
{schema:"1",status:$status,tool:$tool,mode:$mode,query:$query,root:$root,matches:$matches,limits:{max:100,context:2,max_columns:300,max_filesize:"1M",unlimited:false},warnings:$warnings,errors:$errors,meta:{elapsed_ms:0,truncated:false,dry_run:($dry=="1")}}'; }

if [[ "$mode" == "doctor" ]]; then
  require_bins rg git jq
  [[ "$JSON_MODE" == "json" ]] && emit ok facade "[]" || echo "ok: ai-search doctor passed"
  exit 0
fi

[[ -n "$mode" && -n "$query" ]] || {
    usage
    exit 2
}

if [[ "$mode" == "unsafe-all" || "$mode" == "secrets" ]]; then
  if [[ "${AI_ALLOW_UNSAFE:-0}" != "1" ]]; then
    [[ "$JSON_MODE" == "json" ]] && emit unsafe_blocked facade "[]" || echo "unsafe_blocked: approval required"
    exit 0
  fi
fi

if [[ "$DRY_RUN" == "1" ]]; then
  [[ "$JSON_MODE" == "json" ]] && emit dry_run facade "[]" || echo "dry_run"
  exit 0
fi

rg_flags=(-n -m "$MAX" -C "$CONTEXT" --max-columns "$MAX_COLUMNS" --max-filesize "$MAX_FILESIZE")
[[ "$FIXED" == "1" ]] && rg_flags+=(-F)
matches='[]'

case "$mode" in
  text|all|unsafe-all|secrets) matches="$(rg "${rg_flags[@]}" --json "$query" "$root" | jq -sc '[.[]|select(.type=="match")|{file:.data.path.text,line:.data.line_number,text:.data.lines.text}]')" ;;
  docs) matches="$(rg "${rg_flags[@]}" --json -g '*.md' "$query" "$root" | jq -sc '[.[]|select(.type=="match")|{file:.data.path.text,line:.data.line_number,text:.data.lines.text}]')" ;;
  tests) matches="$(rg "${rg_flags[@]}" --json -g 'tests/**' "$query" "$root" | jq -sc '[.[]|select(.type=="match")|{file:.data.path.text,line:.data.line_number,text:.data.lines.text}]')" ;;
  config|schema) matches="$(rg "${rg_flags[@]}" --json -g '*.{json,yml,yaml,toml,xml,dist,lock}' "$query" "$root" | jq -sc '[.[]|select(.type=="match")|{file:.data.path.text,line:.data.line_number,text:.data.lines.text}]')" ;;
  files) require_bins fd; matches="$(fd "$query" "$root" | jq -R . | jq -sc '[.[]|{file:.,line:0,text:""}]')" ;;
  tracked) matches="$(git -C "$root" grep -n -m "$MAX" -- "$query" | jq -R 'split(\":\")|{file:.[0],line:(.[1]|tonumber),text:(.[2:]|join(\":\"))}' | jq -sc '.')" ;;
  changed) matches="$(git -C "$root" diff --name-only | xargs -r rg "${rg_flags[@]}" --json "$query" | jq -sc '[.[]|select(.type=="match")|{file:.data.path.text,line:.data.line_number,text:.data.lines.text}]')" ;;
  staged) matches="$(git -C "$root" diff --cached --name-only | xargs -r rg "${rg_flags[@]}" --json "$query" | jq -sc '[.[]|select(.type=="match")|{file:.data.path.text,line:.data.line_number,text:.data.lines.text}]')" ;;
  struct) matches="$(rg "${rg_flags[@]}" --json "$query" "$root" | jq -sc '[.[]|select(.type=="match")|{file:.data.path.text,line:.data.line_number,text:.data.lines.text}]')" ;;
  *) usage; die "unknown mode: $mode" ;;
esac

if [[ "$JSON_MODE" == "json" ]]; then
  status="ok"; [[ "$(jq 'length' <<<"$matches")" == "0" ]] && status="no_matches"
  emit "$status" facade "$matches"
else
  jq -r '.[] | "\(.file):\(.line):\(.text)"' <<<"$matches"
fi
