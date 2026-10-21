#!/usr/bin/env bash
# repo-stats.sh - print per-file and per-directory line/size metrics for a repo.
# Stdout only. No files written.
# Ignore model: .repomixignore -> .ignore -> .gitignore (via git or fd natively).
# Counting engine: scc --by-file --format json.
# Aggregation: jq (flatten) + awk (recursive dir totals).

set -euo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
    printf '[ERROR] Bash 4+ required; current version is %s. On macOS: brew install bash\n' "${BASH_VERSION:-unknown}" >&2
    exit 1
fi

shopt -s extglob globstar

usage() {
  cat <<'EOF'
Usage:
  scripts/ai/repo-stats.sh [root] [options]

Scan a repo and print per-file and per-directory line/size metrics.
Respects .repomixignore, .ignore, and .gitignore (via git ls-files or fd).
Stdout only - no files are written.

Options:
  --large-file <n>        line threshold for LARGE file flag        (default: 500)
  --large-file-kb <n>     KB threshold for LARGE file flag          (default: 100)
  --large-dir <n>         recursive line threshold for LARGE dir    (default: 5000)
  --large-dir-files <n>   recursive file count threshold            (default: 100)
  --ext <php,js,...>      only include files with these extensions
  --multiplier <n>        quota-weight multiplier for AI usage     (default: 1)
  --multiplier-label <s>  label shown for weighted usage            (default: 1x)
  --no-git                force fd-based discovery even inside a git repo
  --json                  emit flat per-file JSON instead of text report
  --debug-selection       print each skipped file and its skip reason to stderr
  --help

Examples:
  scripts/ai/repo-stats.sh .
  scripts/ai/repo-stats.sh /path/to/project --ext php,blade.php
  scripts/ai/repo-stats.sh . --large-file 300 --large-dir 3000
  scripts/ai/repo-stats.sh . --multiplier 0.33 --multiplier-label GPT-5.4-mini
  scripts/ai/repo-stats.sh . --multiplier 3 --multiplier-label Opus-4.6
  scripts/ai/repo-stats.sh . --json | jq '[.[] | select(.lines > 200)]'
EOF
}

die()  { printf 'Error: %s\n' "$1" >&2; exit 1; }
log()  { printf '[repo-stats] %s\n' "$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || die "required: '$1' not found (brew install ${2:-$1})"; }

fmt_bytes() {
  local b="$1"
  if   (( b >= 1048576 )); then awk "BEGIN{printf \"%.1f MB\", $b/1048576}"
  elif (( b >= 1024    )); then awk "BEGIN{printf \"%.1f KB\", $b/1024}"
  else printf '%d B' "$b"
  fi
}

ROOT='.'
LARGE_FILE_LINES=500
LARGE_FILE_KB=100
LARGE_DIR_LINES=5000
LARGE_DIR_FILES=100
EXT_FILTER=''
TOKEN_MULTIPLIER='1'
TOKEN_MULTIPLIER_LABEL='1x'
FORCE_FD=0
JSON_OUTPUT=0
DEBUG_SELECTION=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --large-file)       LARGE_FILE_LINES="$2";  shift 2 ;;
    --large-file-kb)    LARGE_FILE_KB="$2";     shift 2 ;;
    --large-dir)        LARGE_DIR_LINES="$2";   shift 2 ;;
    --large-dir-files)  LARGE_DIR_FILES="$2";   shift 2 ;;
    --ext)              EXT_FILTER="$2";        shift 2 ;;
    --multiplier)       TOKEN_MULTIPLIER="$2";  shift 2 ;;
    --multiplier-label) TOKEN_MULTIPLIER_LABEL="$2"; shift 2 ;;
    --no-git)           FORCE_FD=1;               shift ;;
    --json)             JSON_OUTPUT=1;            shift ;;
    --debug-selection)  DEBUG_SELECTION=1;        shift ;;
    --help|-h)          usage; exit 0 ;;
    -*)                 die "unknown option: $1" ;;
    *)  if [[ -z "${ROOT_SET:-}" ]]; then ROOT="$1"; ROOT_SET=1; shift
        else die "unexpected argument: $1"; fi ;;
  esac
done

LARGE_FILE_BYTES=$(( LARGE_FILE_KB * 1024 ))

[[ -d "$ROOT" ]] || die "not a directory: $ROOT"
ROOT="$(cd "$ROOT" && pwd)"

need scc "scc"
need jq "jq"
need fd "fd"

BUILTIN_EXCLUDES=(
  vendor
  node_modules
  .git
  storage/logs
  storage/framework/cache
  storage/framework/sessions
  storage/framework/views
  bootstrap/cache
  public/build
  public/hot
  .repomix-context
  .ai-logs
)

EXTRA_PATTERNS=()

load_extra_ignores() {
  local file
  for file in "$ROOT/.repomixignore" "$ROOT/.ignore"; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line; do
      line="${line%$'\r'}"
      [[ -n "$line" ]] || continue
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      EXTRA_PATTERNS+=("$line")
    done < "$file"
  done
}

extra_pattern_matches() {
  local path="$1" pat
  for pat in "${EXTRA_PATTERNS[@]+${EXTRA_PATTERNS[@]}}"; do
    [[ "$path" == "$pat"   ]] && return 0
    [[ "$path" == "$pat/"* ]] && return 0
    case "$path" in $pat) return 0 ;; esac
  done
  return 1
}

path_matches_ext_filter() {
  local path="$1" ext
  IFS=',' read -ra exts <<< "$EXT_FILTER"
  for ext in "${exts[@]}"; do
    ext="${ext#.}"
    [[ "$path" == *."$ext" ]] && return 0
  done
  return 1
}

FILES=()
IGNORED_EXTRA=0

collect_files_git() {
  while IFS= read -r -d '' path; do
    [[ -n "$path" ]] || continue
    [[ -f "$ROOT/$path" ]] || continue

    if extra_pattern_matches "$path"; then
      (( IGNORED_EXTRA += 1 ))
      [[ "$DEBUG_SELECTION" == "1" ]] && printf '[skip extra-ignore] %s\n' "$path" >&2
      continue
    fi

    if [[ -n "$EXT_FILTER" ]] && ! path_matches_ext_filter "$path"; then
      continue
    fi

    FILES+=("$path")
  done < <(git -C "$ROOT" ls-files -z --cached --others --exclude-standard 2>/dev/null)
}

collect_files_fd() {
  local -a fd_args=(-0 --type f)

  [[ -f "$ROOT/.repomixignore" ]] && fd_args+=(--ignore-file "$ROOT/.repomixignore")

  local excl
  for excl in "${BUILTIN_EXCLUDES[@]}"; do
    fd_args+=(-E "$excl")
  done

  if [[ -n "$EXT_FILTER" ]]; then
    IFS=',' read -ra exts <<< "$EXT_FILTER"
    local ext
    for ext in "${exts[@]}"; do
      fd_args+=(-e "${ext#.}")
    done
  fi

  while IFS= read -r -d '' abs_path; do
    [[ -n "$abs_path" ]] || continue
    local rel="${abs_path#"$ROOT/"}"

    if extra_pattern_matches "$rel"; then
      (( IGNORED_EXTRA += 1 ))
      [[ "$DEBUG_SELECTION" == "1" ]] && printf '[skip extra-ignore] %s\n' "$rel" >&2
      continue
    fi

    FILES+=("$rel")
  done < <(fd "${fd_args[@]}" . "$ROOT" 2>/dev/null)
}

run_scc() {
  (
    cd "$ROOT"
    printf '%s\0' "${FILES[@]}" \
      | xargs -0 scc --by-file --format json --no-cocomo 2>/dev/null
  )
}

flatten_scc_json() {
  jq -c '
    [
      .[] |
      .Name as $lang |
      (.Files // [])[] |
      {
        path:     (.Filename // .Location // ""),
        language: $lang,
        lines:    (.Lines    // 0),
        code:     (.Code     // 0),
        comments: (.Comment  // .Comments // 0),
        blanks:   (.Blank    // .Blanks   // 0),
        bytes:    (.Bytes    // 0),
        binary:   (.Binary   // false),
        generated:(.Generated // false),
        minified: (.Minified  // false)
      }
      | .path |= ltrimstr("./")
    ]
    | sort_by(.path)
  '
}

accumulate_dirs_awk() {
  awk -v lfl="$LARGE_FILE_LINES" -v lfb="$LARGE_FILE_BYTES" \
      -v ldl="$LARGE_DIR_LINES"  -v ldf="$LARGE_DIR_FILES" '
  BEGIN { FS = "\t" }
  NR == 1 { next }
  {
    path     = $1; lang  = $2
    lines    = $3+0; code = $4+0
    comments = $5+0; blanks = $6+0; bytes = $7+0

    gsub(/\\/, "/", path)

    file_count++
    fpaths[file_count]    = path
    flangs[file_count]    = lang
    flines[file_count]    = lines
    fcode[file_count]     = code
    fcomments[file_count] = comments
    fblanks[file_count]   = blanks
    fbytes[file_count]    = bytes

    g_lines    += lines
    g_code     += code
    g_comments += comments
    g_blanks   += blanks
    g_bytes    += bytes

    lang_files[lang]++
    lang_lines[lang] += lines
    lang_code[lang]  += code
    lang_bytes[lang] += bytes

    n = split(path, parts, "/")
    nparts = n - 1

    if (nparts > 0) {
      pjoin = ""
      for (i = 1; i <= nparts; i++) pjoin = (i == 1 ? parts[i] : pjoin "/" parts[i])
      dir_direct_lines[pjoin] += lines
      dir_direct_files[pjoin]++
      dir_direct_bytes[pjoin] += bytes
    }

    for (depth = 1; depth <= nparts; depth++) {
      ancestor = ""
      for (i = 1; i <= depth; i++) ancestor = (i == 1 ? parts[i] : ancestor "/" parts[i])
      dir_rec_lines[ancestor] += lines
      dir_rec_files[ancestor]++
      dir_rec_bytes[ancestor] += bytes
      dirs_seen[ancestor] = 1
    }
  }
  END {
    print "=TOTALS=" "\t" file_count "\t" g_lines "\t" g_code "\t" g_comments "\t" g_blanks "\t" g_bytes

    for (dir in dirs_seen) {
      rl = dir_rec_lines[dir]+0
      rf = dir_rec_files[dir]+0
      rb = dir_rec_bytes[dir]+0
      dl = dir_direct_lines[dir]+0
      df = dir_direct_files[dir]+0
      large = (rl >= ldl || rf >= ldf) ? "LARGE" : ""
      print "=DIR=" "\t" dir "\t" rl "\t" rf "\t" rb "\t" dl "\t" df "\t" large
    }

    for (lang in lang_files) {
      print "=LANG=" "\t" lang "\t" lang_files[lang] "\t" lang_lines[lang] "\t" lang_code[lang] "\t" lang_bytes[lang]
    }

    for (i = 1; i <= file_count; i++) {
      large = (flines[i] >= lfl || fbytes[i] >= lfb) ? "LARGE" : ""
      print "=FILE=" "\t" fpaths[i] "\t" flangs[i] "\t" flines[i] "\t" fcode[i] "\t" fcomments[i] "\t" fblanks[i] "\t" fbytes[i] "\t" large
    }
  }
'
}

BOLD=$'\033[1m'; RESET=$'\033[0m'; RED=$'\033[31m'; YELLOW=$'\033[33m'
GREEN=$'\033[32m'; CYAN=$'\033[36m'; DIM=$'\033[2m'
[[ -t 1 ]] || { BOLD=''; RESET=''; RED=''; YELLOW=''; GREEN=''; CYAN=''; DIM=''; }

ctx_fit() {
  local b="$1"
  local kb=$(( b / 1024 ))
  if   (( kb <= 32  )); then printf '%s%s%s' "$GREEN"  '8K ok'    "$RESET"
  elif (( kb <= 64  )); then printf '%s%s%s' "$GREEN"  '16K ok'   "$RESET"
  elif (( kb <= 128 )); then printf '%s%s%s' "$GREEN"  '32K ok'   "$RESET"
  elif (( kb <= 256 )); then printf '%s%s%s' "$YELLOW" '64K maybe' "$RESET"
  elif (( kb <= 512 )); then printf '%s%s%s' "$YELLOW" '128K maybe' "$RESET"
  elif (( kb <= 800 )); then printf '%s%s%s' "$RED"    '200K warn' "$RESET"
  else                        printf '%s%s%s' "$RED"    '>200K no'  "$RESET"
  fi
}

estimate_tokens() {
  local b="$1"
  printf '%s\n' $(( (b + 3) / 4 ))
}

weighted_tokens() {
  local raw_tokens="$1"
  local multiplier="$2"
  awk -v raw="$raw_tokens" -v mult="$multiplier" 'BEGIN {
    value = raw * mult
    printf "%d", int(value == int(value) ? value : value + 1)
  }'
}

fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) {
      printf "%.1fM", n / 1000000
    } else if (n >= 1000) {
      printf "%.1fK", n / 1000
    } else {
      printf "%d", n
    }
  }'
}

print_report() {
  local raw_data="$1"

  local total_files=0 total_lines=0 total_code=0 total_comments=0 total_blanks=0 total_bytes=0
  local -a dir_recs=() lang_recs=() file_recs=() large_file_recs=()
  local dir_totals_lookup=''

  while IFS=$'\t' read -r tag rest; do
    case "$tag" in
      =TOTALS=)
        IFS=$'\t' read -r total_files total_lines total_code total_comments total_blanks total_bytes <<< "$rest"
        ;;
      =DIR=)
        dir_recs+=("$rest")
        IFS=$'\t' read -r _d rl rf rb _dl _df _lrg <<< "$rest"
        dir_totals_lookup+="${_d}"$'\t'"${rl}"$'\t'"${rf}"$'\t'"${rb}"$'\n'
        ;;
      =LANG=)
        lang_recs+=("$rest")
        ;;
      =FILE=)
        file_recs+=("$rest")
        IFS=$'\t' read -r _path _lang _lines _code _cmt _blk _bytes large <<< "$rest"
        [[ "$large" == "LARGE" ]] && large_file_recs+=("$rest")
        ;;
    esac
  done <<< "$raw_data"

  dir_lookup_lines() {
    printf '%s' "$dir_totals_lookup" | awk -F'\t' -v d="$1" '$1 == d { print $2; exit }'
  }
  dir_lookup_bytes() {
    printf '%s' "$dir_totals_lookup" | awk -F'\t' -v d="$1" '$1 == d { print $4; exit }'
  }

  local total_bytes_fmt; total_bytes_fmt="$(fmt_bytes "$total_bytes")"
  local total_raw_tokens; total_raw_tokens="$(estimate_tokens "$total_bytes")"
  local total_weighted_tokens; total_weighted_tokens="$(weighted_tokens "$total_raw_tokens" "$TOKEN_MULTIPLIER")"
  local total_raw_tokens_fmt; total_raw_tokens_fmt="$(fmt_tokens "$total_raw_tokens")"
  local total_weighted_tokens_fmt; total_weighted_tokens_fmt="$(fmt_tokens "$total_weighted_tokens")"
  printf '%s\n' "${BOLD}============================================================${RESET}"
  printf '%s%s%s\n' "$BOLD" '  REPO STATS' "$RESET"
  printf '  files: %s   lines: %s   code: %s   comments: %s   blanks: %s\n' \
    "$total_files" "$total_lines" "$total_code" "$total_comments" "$total_blanks"
  printf '  size:  %s\n' "$total_bytes_fmt"
  printf '  raw estimated tokens: %s   weighted usage (%s): %s\n' \
    "$total_raw_tokens_fmt" "$TOKEN_MULTIPLIER_LABEL" "$total_weighted_tokens_fmt"
  printf '%s\n\n' "${BOLD}============================================================${RESET}"

  printf '%s-- DIRECTORIES (recursive totals) ---------------------------%s\n' "$CYAN" "$RESET"
  printf '  %-28s %6s  %11s  %10s  %10s  %12s  %s\n' \
    'directory' 'files' 'total-lines' 'size' 'raw-tokens' 'weighted' 'ctx-fit'
  printf '  %s\n' "$(printf '%.0s-' {1..112})"
  local sorted_dirs
  sorted_dirs="$(for rec in "${dir_recs[@]+${dir_recs[@]}}"; do
      IFS=$'\t' read -r dir rl rf rb dl df large <<< "$rec"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$rl" "$dir" "$rl" "$rf" "$rb" "$dl" "$large"
    done | sort -t$'\t' -k1 -rn | cut -f2-)"

  while IFS=$'\t' read -r dir rl rf rb dl df large; do
    [[ -n "$dir" ]] || continue
    local rb_fmt; rb_fmt="$(fmt_bytes "$rb")"
    local tokens; tokens="$(estimate_tokens "$rb")"
    local tokens_fmt; tokens_fmt="$(fmt_tokens "$tokens")"
    local weighted; weighted="$(weighted_tokens "$tokens" "$TOKEN_MULTIPLIER")"
    local weighted_fmt; weighted_fmt="$(fmt_tokens "$weighted")"
    local ctx; ctx="$(ctx_fit "$rb")"
    local size_flag=''
    [[ "$large" == "LARGE" ]] && size_flag="${RED} LARGE${RESET}"
    printf '  %-28s %6s  %11s  %10s  %10s  %12s  %s%s\n' \
      "$dir/" "$rf" "$rl" "$rb_fmt" "$tokens_fmt" "$weighted_fmt" "$ctx" "$size_flag"
  done <<< "$sorted_dirs"
  printf '\n'

  printf '%s-- LANGUAGE BREAKDOWN --------------------------------------%s\n' "$CYAN" "$RESET"
  printf '  %-20s %8s  %8s  %8s  %10s\n' 'language' 'files' 'lines' 'code' 'size'
  printf '  %s\n' "$(printf '%.0s-' {1..70})"
  local sorted_langs
  sorted_langs="$(for rec in "${lang_recs[@]+${lang_recs[@]}}"; do
      IFS=$'\t' read -r lang lf ll lc lb <<< "$rec"
      printf '%s\t%s\t%s\t%s\t%s\n' "$ll" "$lang" "$lf" "$lc" "$lb"
    done | sort -t$'\t' -k1 -rn | cut -f2-)"
  while IFS=$'\t' read -r lang lf ll lc lb; do
    [[ -n "$lang" ]] || continue
    local lb_fmt; lb_fmt="$(fmt_bytes "$lb")"
    printf '  %-20s %8s  %8s  %8s  %10s\n' "$lang" "$lf" "$ll" "$lc" "$lb_fmt"
  done <<< "$sorted_langs"
  printf '\n'

  printf '%s-- FILES ---------------------------------------------------%s\n' "$CYAN" "$RESET"
  printf '  %-55s %-12s %7s  %7s  %10s\n' 'path' 'language' 'lines' 'code' 'size'
  printf '  %s\n' "$(printf '%.0s-' {1..100})"
  local prev_dir=''
  for rec in "${file_recs[@]+${file_recs[@]}}"; do
    IFS=$'\t' read -r path lang lines code comments blanks bytes large <<< "$rec"
    local dir="${path%/*}"; [[ "$path" == */* ]] || dir='.'
    if [[ "$dir" != "$prev_dir" ]]; then
      local dlines; dlines="$(dir_lookup_lines "$dir")"
      local dbytes; dbytes="$(dir_lookup_bytes "$dir")"
      local dctx=''
      if [[ -n "$dbytes" && "$dbytes" -gt 0 ]]; then
        local dtokens; dtokens="$(estimate_tokens "$dbytes")"
        local dweighted; dweighted="$(weighted_tokens "$dtokens" "$TOKEN_MULTIPLIER")"
        dctx="  $(ctx_fit "$dbytes")  total: ${dlines} lines | raw tokens: ${dtokens} | weighted usage (${TOKEN_MULTIPLIER_LABEL}): ${dweighted}"
      fi
      printf '\n  %s%s/%s%s\n' "$DIM" "$dir" "$RESET" "$dctx"
      prev_dir="$dir"
    fi
    local bytes_fmt; bytes_fmt="$(fmt_bytes "$bytes")"
    local flag=''
    [[ "$large" == "LARGE" ]] && flag="${RED} LARGE${RESET}"
    local name="${path##*/}"
    printf '    %-51s %-12s %7s  %7s  %10s%s\n' "$name" "$lang" "$lines" "$code" "$bytes_fmt" "$flag"
  done
  printf '\n'

  printf '%s-- LARGE FILES (>%s lines or >%s KB) ------------------------%s\n' \
    "$RED" "$LARGE_FILE_LINES" "$LARGE_FILE_KB" "$RESET"
  if [[ ${#large_file_recs[@]} -eq 0 ]]; then
    printf '  %s(none)%s\n' "$DIM" "$RESET"
  else
    printf '  %-55s %-12s %7s  %10s\n' 'path' 'language' 'lines' 'size'
    for rec in "${large_file_recs[@]}"; do
      IFS=$'\t' read -r path lang lines code comments blanks bytes _large <<< "$rec"
      local bytes_fmt; bytes_fmt="$(fmt_bytes "$bytes")"
      printf '  %-55s %-12s %7s  %10s\n' "$path" "$lang" "$lines" "$bytes_fmt"
    done
  fi
  printf '\n'

  printf '%s============================================================%s\n' "$BOLD" "$RESET"
  printf '  Thresholds  file-large: >%s lines or >%s KB   dir-large: >%s lines or >%s files\n' \
    "$LARGE_FILE_LINES" "$LARGE_FILE_KB" "$LARGE_DIR_LINES" "$LARGE_DIR_FILES"
  printf '  Token math  raw-tokens ~= bytes/4   weighted-usage = raw-tokens x %s (%s)\n' \
    "$TOKEN_MULTIPLIER" "$TOKEN_MULTIPLIER_LABEL"
  printf '%s============================================================%s\n' "$BOLD" "$RESET"
}

load_extra_ignores

if [[ "$FORCE_FD" == "0" ]] && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log "using git ls-files in $(basename "$ROOT")"
  collect_files_git
else
  log "using fd in $(basename "$ROOT")"
  collect_files_fd
fi

log "${#FILES[@]} files selected (${IGNORED_EXTRA} extra-ignored)"
(( ${#FILES[@]} > 0 )) || die "no files found after applying ignore rules"

log "running scc on ${#FILES[@]} files..."
SCC_JSON="$(run_scc)"

if [[ "$JSON_OUTPUT" == "1" ]]; then
  printf '%s\n' "$SCC_JSON" | flatten_scc_json
  exit 0
fi

FLAT_TSV="$(printf '%s\n' "$SCC_JSON" | flatten_scc_json \
    | jq -r '
        ["path","language","lines","code","comments","blanks","bytes"],
        (.[] | [.path, .language, .lines, .code, .comments, .blanks, .bytes])
        | @tsv
      ')"

RAW_REPORT="$(accumulate_dirs_awk <<< "$FLAT_TSV")"

print_report "$RAW_REPORT"
