#!/usr/bin/env bash
# Package reporting for ops/update-all.sh.
#
# What changed is asked of the *top-level* package sets before and after the
# update — the things you actually asked to have installed. Closure diffs are
# deliberately not used: they report dependency churn ("libqmi: -60.1 MiB"),
# which is noise in an answer to "what did this update do to my tools?".
#
# Every function here is side-effect free, so a failed comparison can never
# change what the updater did.

_UVR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/lib/update-facts.sh
source "$_UVR_DIR/lib/update-facts.sh"

profile_target() {
  local link="$1"
  [[ -e "$link" || -L "$link" ]] || return 0
  readlink -f "$link" 2>/dev/null || true
}

# packages_in_profile <profile link> -> "pname\tversion" list (empty on failure)
packages_in_profile() {
  nix_toplevel_packages "$(profile_target "$1")" 2>/dev/null || true
}

mise_versions() {
  command -v mise >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 1
  mise ls --json 2>/dev/null \
    | jq -r 'to_entries[] | .key as $tool | .value[] | select(.active == true) | [$tool, .version] | @tsv' \
    | LC_ALL=C sort
}

# _uvr_rows <kind> — renders the rows of one class from a package_delta stream.
# awk does the splitting: `read` would collapse the empty column that an
# "added" row carries, because tab is IFS whitespace.
_uvr_rows() {
  awk -F '\t' -v kind="$1" '
    $1 != kind { next }
    kind == "upgraded" { printf "      %-24s%s → %s\n", $2, ($3 == "" ? "∅" : $3), $4; next }
    kind == "added"    { printf "      %-24s%s\n", $2, $4; next }
                       { printf "      %-24s%s\n", $2, $3 }
  '
}

# render_package_delta <label> <before TSV> <after TSV> [detail]
#
# Headline counts first, then the individual changes. Removals get their own
# section because an unexpected disappearance matters far more than a routine
# patch bump.
render_package_delta() {
  local label="$1" before="$2" after="$3" detail="${4:-1}"
  printf '  %s\n' "$label"

  if [[ -z "$before" || -z "$after" ]]; then
    printf '    unavailable (no before/after snapshot taken)\n'
    return 0
  fi

  local delta up add rm same
  delta="$(package_delta "$before" "$after")"
  IFS=$'\t' read -r _ up add rm same <<< "$(printf '%s\n' "$delta" | grep '^summary')"

  if (( up == 0 && add == 0 && rm == 0 )); then
    printf '    no package changes (%s unchanged)\n' "$same"
    return 0
  fi

  printf '    ↑ %s upgraded   + %s added   - %s removed   (%s unchanged)\n' \
    "$up" "$add" "$rm" "$same"
  [[ "$detail" == 1 ]] || return 0

  # Removals first: an unexpected disappearance is the one thing you must see.
  if (( rm > 0 )); then
    printf '\n    REMOVED\n'; printf '%s\n' "$delta" | _uvr_rows removed
  fi
  if (( up > 0 )); then
    printf '\n    UPGRADED\n'; printf '%s\n' "$delta" | _uvr_rows upgraded
  fi
  if (( add > 0 )); then
    printf '\n    ADDED\n'; printf '%s\n' "$delta" | _uvr_rows added
  fi
}

# report_mise_changes <before> <after> <available>
report_mise_changes() {
  local before="$1" after="$2" available="$3"
  if [[ "$available" != 1 ]]; then
    printf '  mise tools\n    unavailable (version snapshot could not be taken)\n'
    return 0
  fi
  render_package_delta "mise tools" "$before" "$after"
}

# report_nix_changes <label> <before profile path> <after profile path>
#
# Kept for callers that hold store paths rather than package lists.
report_nix_changes() {
  local label="$1" before_path="$2" after_path="$3" before="" after=""
  [[ -n "$before_path" ]] && before="$(nix_toplevel_packages "$before_path" || true)"
  [[ -n "$after_path" ]] && after="$(nix_toplevel_packages "$after_path" || true)"
  render_package_delta "$label" "$before" "$after"
}
