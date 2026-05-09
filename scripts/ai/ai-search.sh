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

emit() {
  local status="$1" tool="$2" matches_json="${3:-[]}" warnings_json="${4:-[]}" errors_json="${5:-[]}"
  local matches_file
  matches_file="$(mktemp)"
  printf '%s' "$matches_json" >"$matches_file"
  jq -nc \
    --arg status "$status" \
    --arg tool "$tool" \
    --arg mode "$mode" \
    --arg query "$query" \
    --arg root "$root" \
    --argjson warnings "$warnings_json" \
    --argjson errors "$errors_json" \
    --argjson dry "$DRY_RUN" \
    --argjson max "$MAX" \
    --argjson context "$CONTEXT" \
    --argjson max_columns "$MAX_COLUMNS" \
    --arg max_filesize "$MAX_FILESIZE" \
    --slurpfile matches "$matches_file" '
{schema:"1",status:$status,tool:$tool,mode:$mode,query:$query,root:$root,matches:($matches[0] // []),limits:{max:$max,context:$context,max_columns:$max_columns,max_filesize:$max_filesize,unlimited:false},warnings:$warnings,errors:$errors,meta:{elapsed_ms:0,truncated:false,dry_run:($dry=="1")}}'
  rm -f "$matches_file"
}

match_json_filter='[.[]|select(.type=="match")|{file:.data.path.text,line:.data.line_number,text:.data.lines.text}]'

rg_matches() {
  local rc stdout_file stderr_file stderr_output
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  set +e
  rg "$@" >"$stdout_file" 2>"$stderr_file"
  rc=$?
  set -e

  stderr_output="$(<"$stderr_file")"
  if [[ -n "$stderr_output" ]]; then
    printf '%s\n' "$stderr_output" >&2
  fi

  if [[ "$rc" -eq 1 ]]; then
    rm -f "$stdout_file" "$stderr_file"
    printf '[]'
    return 0
  fi

  if [[ "$rc" -ne 0 ]]; then
    rm -f "$stdout_file" "$stderr_file"
    return "$rc"
  fi

  jq -sc "$match_json_filter" <"$stdout_file"
  rc=$?
  rm -f "$stdout_file" "$stderr_file"
  return "$rc"
}

git_grep_matches() {
  local output rc
  local git_flags=(-n -m "$MAX")
  [[ "$FIXED" == "1" ]] && git_flags+=(-F)

  set +e
  output="$(git -C "$root" grep "${git_flags[@]}" -- "$query" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 1 ]]; then
    printf '[]'
    return 0
  fi

  if [[ "$rc" -ne 0 ]]; then
    printf '%s\n' "$output" >&2
    return "$rc"
  fi

  printf '%s' "$output" | jq -R 'split(":")|{file:.[0],line:(.[1]|tonumber),text:(.[2:]|join(":"))}' | jq -sc '.'
}

diff_file_matches() {
  local diff_flag="${1:-}"
  local -a diff_args=()
  local -a files=()
  [[ -n "$diff_flag" ]] && diff_args+=("$diff_flag")
  mapfile -d '' files < <(git -C "$root" diff "${diff_args[@]}" --name-only -z)

  if [[ "${#files[@]}" -eq 0 ]]; then
    printf '[]'
    return 0
  fi

  (cd "$root" && rg_matches "${rg_flags[@]}" --json "$query" "${files[@]}")
}

struct_matches() {
  require_bins ast-grep
  local output rc lang
  lang="${AI_LANG:-php}"

  set +e
  output="$(ast-grep run --lang "$lang" --pattern "$query" "$root" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 1 ]]; then
    printf '[]'
    return 0
  fi

  if [[ "$rc" -ne 0 ]]; then
    printf '%s\n' "$output" >&2
    return "$rc"
  fi

  printf '%s' "$output" | jq -R -s 'split("\n") | map(select(length > 0) | {file:"",line:0,text:.})'
}

if [[ "$mode" == "doctor" ]]; then
  require_bins rg git jq fd ast-grep
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
errors='[]'
status_override=''

case "$mode" in
  text|all|unsafe-all|secrets) matches="$(rg_matches "${rg_flags[@]}" --json "$query" "$root")" || status_override="error" ;;
  docs) matches="$(rg_matches "${rg_flags[@]}" --json -g '*.md' "$query" "$root")" || status_override="error" ;;
  tests) matches="$(rg_matches "${rg_flags[@]}" --json -g 'tests/**' "$query" "$root")" || status_override="error" ;;
  config|schema) matches="$(rg_matches "${rg_flags[@]}" --json -g '*.{json,yml,yaml,toml,xml,dist,lock}' "$query" "$root")" || status_override="error" ;;
  files) require_bins fd; matches="$(fd "$query" "$root" | jq -R . | jq -sc '[.[]|{file:.,line:0,text:""}]')" || status_override="error" ;;
  tracked) matches="$(git_grep_matches)" || status_override="error" ;;
  changed) matches="$(diff_file_matches)" || status_override="error" ;;
  staged) matches="$(diff_file_matches --cached)" || status_override="error" ;;
  struct) matches="$(struct_matches)" || status_override="error" ;;
  *) usage; die "unknown mode: $mode" ;;
esac

if [[ "$status_override" == "error" ]]; then
  errors="$(jq -nc --arg mode "$mode" '[{message:("search failed for mode: " + $mode)}]')"
  matches='[]'
fi

if [[ "$JSON_MODE" == "json" ]]; then
  status="${status_override:-ok}"; [[ -z "$status_override" && "$(jq 'length' <<<"$matches")" == "0" ]] && status="no_matches"
  emit "$status" facade "$matches" "[]" "$errors"
else
  [[ "$status_override" == "error" ]] && exit 1
  jq -r '.[] | "\(.file):\(.line):\(.text)"' <<<"$matches"
fi
