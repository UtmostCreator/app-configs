#!/usr/bin/env bash
# profile_hm_conflicts MANIFEST HOME_PATH
#
# Print "<profile element>\t<relative file>" for every file in bin/ of a
# hand-installed nix-profile element that the new Home Manager package set
# (HOME_PATH = <activationPackage>/home-path) also provides.
#
# Why: Home Manager installs home-manager-path into the same nix profile.
# When a file collides, `home-manager switch` fails with "conflicting
# packages" AFTER it already removed the old home-manager-path, so git,
# home-manager and starship drop off PATH until it is repaired by hand.
# Checking first turns that into a clean stop with a one-line fix.
#
# Reads profile manifest version 2 (list) and 3 (object). Missing inputs are
# not an error: nothing is printed.
profile_hm_conflicts() {
  local manifest="$1" home_path="$2"
  [[ -f "$manifest" && -d "$home_path/bin" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local name paths p f
  while IFS=$'\t' read -r name paths; do
    [[ -z "$name" || "$name" == home-manager-path ]] && continue
    for p in $paths; do
      [[ -d "$p/bin" ]] || continue
      for f in "$p"/bin/*; do
        [[ -e "$f" ]] || continue
        [[ -e "$home_path/bin/${f##*/}" ]] && printf '%s\tbin/%s\n' "$name" "${f##*/}"
      done
    done
  done < <(jq -r '
    .elements
    | if type == "object" then to_entries[] | [.key, (.value.storePaths // [] | join(" "))]
      else .[] | [((.attrPath // "") | split(".") | last), (.storePaths // [] | join(" "))] end
    | @tsv' "$manifest" 2>/dev/null)
}
