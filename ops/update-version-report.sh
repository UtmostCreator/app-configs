#!/usr/bin/env bash
# Reporting helpers for ops/update-all.sh. These functions are intentionally
# side-effect free so a failed comparison never changes upgrade behavior.

profile_target() {
  local link="$1"
  [[ -e "$link" || -L "$link" ]] || return 0
  if command -v realpath >/dev/null 2>&1; then
    realpath "$link" 2>/dev/null || true
  else
    readlink -f "$link" 2>/dev/null || true
  fi
}

mise_versions() {
  command -v mise >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 1
  mise ls --json 2>/dev/null \
    | jq -r 'to_entries[] | .key as $tool | .value[] | select(.active == true) | [$tool, .version] | @tsv' \
    | LC_ALL=C sort
}

report_nix_changes() {
  local label="$1" before="$2" after="$3" changes=""
  printf '[update-all:versions] %s\n' "$label"
  if [[ -z "$before" || -z "$after" ]]; then
    printf '   unavailable (profile generation not found)\n'
  elif [[ "$before" == "$after" ]]; then
    printf '   no version changes\n'
  else
    if ! changes="$(nix store diff-closures "$before" "$after" 2>/dev/null \
      | sed $'s/\033\\[[0-9;]*m//g; s/ → / => /g')"; then
      printf '   unavailable (nix closure comparison failed)\n'
      return 0
    fi
    if [[ -n "$changes" ]]; then
      printf '%s\n' "$changes" | sed 's/^/   /'
    else
      printf '   generation changed; no package version changes reported\n'
    fi
  fi
}

report_mise_changes() {
  local before="$1" after="$2" available="$3" changes=""
  printf '[update-all:versions] mise tools\n'
  if [[ "$available" != 1 ]]; then
    printf '   unavailable (mise version snapshot failed)\n'
    return 0
  fi
  changes="$(awk -F '\t' '
    NR == FNR { if (NF >= 2) before[$1] = $2; next }
    NF >= 2 {
      seen[$1] = 1
      if (!($1 in before)) printf "   %s: ∅ => %s\n", $1, $2
      else if (before[$1] != $2) printf "   %s: %s => %s\n", $1, before[$1], $2
    }
    END {
      for (tool in before)
        if (!(tool in seen)) printf "   %s: %s => ∅\n", tool, before[tool]
    }
  ' <(printf '%s\n' "$before") <(printf '%s\n' "$after"))"
  if [[ -n "$changes" ]]; then printf '%s\n' "$changes";
  else printf '   no version changes\n'; fi
}
