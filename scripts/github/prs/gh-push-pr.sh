#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: gh-push-pr.sh [--base <branch>] [--ticket <TICKET>] [--title <title>] [--help] [-- <git-push-args...>]

Recommended default workflow for any repo:
- runs git push first
- opens prefilled GitHub PR URL only after successful push

Examples:
  gh-push-pr.sh
  gh-push-pr.sh -- --set-upstream origin "$(git branch --show-current)"
  gh-push-pr.sh --base main
  gh-push-pr.sh --ticket ABC-1234 --title "ABC-1234 fix checkout copy"

Notes:
- Git push args can be passed directly (e.g. --no-verify) or after --.
- Requires a GitHub origin remote and the companion hooks/pr-url.sh script.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pr_url_script="$script_dir/hooks/pr-url.sh"

if [[ ! -x "$pr_url_script" ]]; then
  echo "Required script not found or not executable: $pr_url_script" >&2
  exit 1
fi

pr_args=(--push --open)
push_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base|--ticket|--title)
      [[ $# -ge 2 ]] || { echo "$1 requires a value" >&2; exit 2; }
      pr_args+=("$1" "$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      push_args=("$@")
      break
      ;;
    --*)
      # Pass unknown long options through to git push so callers can use flags
      # like --no-verify without requiring the separator.
      push_args+=("$1")
      shift
      ;;
    -*)
      # Pass unknown short options through to git push.
      push_args+=("$1")
      shift
      ;;
    *)
      # Treat positional args as git push args (e.g. origin, branch, refspec).
      push_args+=("$1")
      shift
      ;;
  esac
done

exec "$pr_url_script" "${pr_args[@]}" -- "${push_args[@]}"
