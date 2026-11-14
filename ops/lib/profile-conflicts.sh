#!/usr/bin/env bash
# profile_hm_conflicts MANIFEST HOME_PATH
#
# Print "<profile element>\t<relative file>" for every file of an active,
# hand-installed nix-profile element that the new Home Manager package set
# (HOME_PATH = <activationPackage>/home-path) also provides (bin/, share/,
# lib/, ... — any path, not just bin/). Directories never conflict (Nix merges
# them), and identical store paths on both sides still do.
#
# Why: Home Manager installs home-manager-path into the same nix profile.
# When a file collides, `home-manager switch` fails with "conflicting
# packages" AFTER it already removed the old home-manager-path, so git,
# home-manager and starship drop off PATH until it is repaired by hand.
# Checking first turns that into a clean stop with a one-line fix.
#
# Reads profile manifest version 2 (list) and 3 (object). Elements with
# "active": false are ignored. Missing inputs are not an error: nothing is
# printed.
profile_hm_conflicts() {
  local manifest="$1" home_path="$2"
  [[ -f "$manifest" && -d "$home_path" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local name p rel
  # One row per (element, store path): paths may contain spaces.
  while IFS=$'\t' read -r name p; do
    [[ -z "$name" || -z "$p" || "$name" == home-manager-path ]] && continue
    [[ -d "$p" ]] || continue
    while IFS= read -r rel; do
      rel="${rel#./}"
      # Nix merges directories, so only a clash of two non-directories (after
      # following symlinks) is a conflict. Link paths are compared, not
      # targets: the same store path on both sides still conflicts.
      [[ -d "$p/$rel" ]] && continue
      [[ -e "$home_path/$rel" && ! -d "$home_path/$rel" ]] || continue
      printf '%s\t%s\n' "$name" "$rel"
    done < <(cd "$p" && find . \( -type f -o -type l \) 2>/dev/null | LC_ALL=C sort)
  done < <(jq -r '
    .elements
    | if type == "object"
        then to_entries[] | select(.value.active != false)
             | .key as $n | (.value.storePaths // [])[] | [$n, .]
        else .[] | select(.active != false)
             | ((.attrPath // "") | split(".") | last) as $n
             | (.storePaths // [])[] | [$n, .] end
    | @tsv' "$manifest" 2>/dev/null)
}
