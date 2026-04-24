#!/usr/bin/env bash
# Pack only changed or targeted files into AI context bundles.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TOKEN_BUDGET="${TOKEN_BUDGET:-80000}"
OUTPUT_DIR="${OUTPUT_DIR:-${COPILOT_CONTEXT_DIR}/diff}"
INCLUDE_TESTS="${INCLUDE_TESTS:-1}"
SECRETS_SCAN="${SECRETS_SCAN:-1}"

require_bins jq

usage() {
  cat <<'EOF'
Usage:
  ai-diff-context.sh since <ref>
  ai-diff-context.sh unstaged
  ai-diff-context.sh pr <number>
  ai-diff-context.sh recent [--count N]
  ai-diff-context.sh touched <pattern>
EOF
}

collect_related_tests() {
  local files=("$@")
  local test_files=()
  local root
  root="$(git_root)"

  for f in "${files[@]}"; do
    local base stem
    base="$(basename "$f")"
    stem="${base%.*}"

    while IFS= read -r match; do
      test_files+=("$match")
    done < <(fd --hidden -e php -E vendor -E node_modules -E dist "${stem}Test" "$root" 2>/dev/null || true)

    while IFS= read -r match; do
      test_files+=("$match")
    done < <(fd --hidden -E node_modules -E dist "^${stem}\.(test|spec)\.(js|ts|jsx|tsx)$" "$root" 2>/dev/null || true)

    while IFS= read -r match; do
      test_files+=("$match")
    done < <(fd --hidden -e kt "${stem}Test" "$root" 2>/dev/null || true)
  done

  printf '%s\n' "${test_files[@]+${test_files[@]}}" | sort -u
}

deduplicate_files() {
  local files=("$@")
  printf '%s\n' "${files[@]+${files[@]}}" | sort -u | grep -v '^$'
}

filter_existing() {
  while IFS= read -r f; do
    [[ -f "$f" ]] && printf '%s\n' "$f"
  done
}

pack_files_list() {
  local label="$1"
  shift
  local files=("$@")

  (( ${#files[@]} > 0 )) || die "no files to pack"

  mkdir -p "$OUTPUT_DIR"
  local out_file="${OUTPUT_DIR}/${label}-$(date +%Y%m%d-%H%M%S).xml"
  local list_file
  list_file="$(mktemp)"
  printf '%s\n' "${files[@]}" > "$list_file"

  log_info "Packing ${#files[@]} files into context"

  if [[ "$SECRETS_SCAN" == "1" ]]; then
    section "Secrets scan"
    if ! secrets_scan "$(git_root)"; then
      rm -f "$list_file"
      die "secrets detected; aborting context pack"
    fi
    log_ok "No secrets found"
  fi

  local root
  root="$(git_root)"

  if command -v repomix >/dev/null 2>&1; then
    (
      cd "$root"
      repomix --stdin --output "$out_file" --style xml --compress < "$list_file"
    )
  elif command -v files-to-prompt >/dev/null 2>&1; then
    mapfile -t file_args < "$list_file"
    files-to-prompt "${file_args[@]}" > "$out_file"
  else
    rm -f "$list_file"
    die "no context packer available; install repomix or files-to-prompt"
  fi

  rm -f "$list_file"

  local tokens
  tokens="$(estimate_tokens "$out_file")"
  if ! within_token_budget "$out_file" "$TOKEN_BUDGET"; then
    log_warn "Context is ~${tokens} tokens, exceeding budget ${TOKEN_BUDGET}"
  else
    log_ok "Context packed: ~${tokens} tokens"
  fi

  local manifest="${out_file%.xml}.manifest.json"
  jq -n \
    --arg label "$label" \
    --arg out "$out_file" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson files "$(printf '%s\n' "${files[@]}" | jq -R . | jq -s .)" \
    --argjson tokens "$tokens" \
    '{label:$label, output:$out, ts:$ts, file_count:($files|length), estimated_tokens:$tokens, files:$files}' \
    > "$manifest"

  log_json "context.pack" "$(cat "$manifest")"
  printf '%s\n' "$out_file"
}

cmd_since() {
  local ref="${1:?git ref required}"
  section "Changed files since $ref"
  mapfile -t files < <((git diff --name-only "$ref"...HEAD 2>/dev/null || git diff --name-only "$ref") | filter_existing)

  if [[ "$INCLUDE_TESTS" == "1" ]]; then
    mapfile -t tests < <(collect_related_tests "${files[@]+${files[@]}}" | filter_existing)
    files+=("${tests[@]+${tests[@]}}")
  fi

  mapfile -t files < <(deduplicate_files "${files[@]+${files[@]}}" | filter_existing)
  pack_files_list "since-${ref//\//-}" "${files[@]}"
}

cmd_unstaged() {
  section "Unstaged and untracked changed files"
  mapfile -t files < <({ git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } | sort -u | filter_existing)

  if [[ "$INCLUDE_TESTS" == "1" ]]; then
    mapfile -t tests < <(collect_related_tests "${files[@]+${files[@]}}" | filter_existing)
    files+=("${tests[@]+${tests[@]}}")
  fi

  mapfile -t files < <(deduplicate_files "${files[@]+${files[@]}}" | filter_existing)
  pack_files_list "unstaged" "${files[@]}"
}

cmd_pr() {
  local pr="${1:?PR number required}"
  require_bins gh
  section "Files in PR #$pr"
  mapfile -t files < <(gh pr view "$pr" --json files --jq '.files[].path' | filter_existing)

  if [[ "$INCLUDE_TESTS" == "1" ]]; then
    mapfile -t tests < <(collect_related_tests "${files[@]+${files[@]}}" | filter_existing)
    files+=("${tests[@]+${tests[@]}}")
  fi

  mapfile -t files < <(deduplicate_files "${files[@]+${files[@]}}" | filter_existing)
  pack_files_list "pr-${pr}" "${files[@]}"
}

cmd_recent() {
  local count=10
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --count|-n) count="$2"; shift 2 ;;
      --count=*) count="${1#*=}"; shift ;;
      *) die "unknown option: $1" ;;
    esac
  done

  section "Files changed in last $count commits"
  mapfile -t files < <(git log --name-only --pretty=format: -"$count" | sort -u | grep -v '^$' | filter_existing)

  if [[ "$INCLUDE_TESTS" == "1" ]]; then
    mapfile -t tests < <(collect_related_tests "${files[@]+${files[@]}}" | filter_existing)
    files+=("${tests[@]+${tests[@]}}")
  fi

  mapfile -t files < <(deduplicate_files "${files[@]+${files[@]}}" | filter_existing)
  pack_files_list "recent-${count}" "${files[@]}"
}

cmd_touched() {
  local pattern="${1:?pattern required}"
  require_bins fd rg
  section "Files matching: $pattern"
  local root
  root="$(git_root)"
  mapfile -t files < <({ fd --hidden -E vendor -E node_modules -E dist -E .git "$pattern" "$root"; rg -l --hidden -g '!vendor' -g '!node_modules' -g '!dist' -g '!.git' "$pattern" "$root" 2>/dev/null || true; } | sort -u | filter_existing)

  if [[ "$INCLUDE_TESTS" == "1" ]]; then
    mapfile -t tests < <(collect_related_tests "${files[@]+${files[@]}}" | filter_existing)
    files+=("${tests[@]+${tests[@]}}")
  fi

  mapfile -t files < <(deduplicate_files "${files[@]+${files[@]}}" | filter_existing)
  pack_files_list "touched-${pattern//[^a-zA-Z0-9]/-}" "${files[@]}"
}

agent_session_init "ai-diff-context"

cmd="${1:-}"
[[ -n "$cmd" ]] || { usage; exit 1; }
shift || true

case "$cmd" in
  since) cmd_since "$@" ;;
  unstaged) cmd_unstaged ;;
  pr) cmd_pr "$@" ;;
  recent) cmd_recent "$@" ;;
  touched) cmd_touched "$@" ;;
  --help|-h) usage ;;
  *) usage; die "unknown command: $cmd" ;;
esac
