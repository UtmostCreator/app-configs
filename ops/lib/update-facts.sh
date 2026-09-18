#!/usr/bin/env bash
# Fact gathering for ops/update-all.sh.
#
# Every function here is side-effect free: it inspects the world (or plain
# text) and prints a structured answer. Nothing in this file may mutate the
# system, so preflight can call all of it before a single change is made.
#
# Output is TSV so callers can render it however they like.

# ── Nix store names ─────────────────────────────────────────────────────────

# Outputs that belong to a package we already list under its main output.
# Dropping the suffix folds `gnupg-2.4.9-man` back into `gnupg 2.4.9`.
_NIX_OUTPUT_SUFFIXES='bin|man|dev|devdoc|doc|info|lib|out|debug|static|terminfo|python|systemd|unwrapped'

# nix_parse_store_name <store path or basename> -> "pname\tversion"
#
# Follows the nixpkgs convention that the version starts at the first dash
# followed by a non-letter (so `python3.14-lizard-1.24.0` splits correctly, and
# `vicinae-resize` is recognised as having no version at all).
nix_parse_store_name() {
  local name="${1##*/}" pname version
  # Drop the 32-character store hash prefix when present.
  [[ "$name" =~ ^[0-9a-df-np-sv-z]{32}-(.*)$ ]] && name="${BASH_REMATCH[1]}"

  # Peel one output suffix, but only if a version survives underneath it —
  # that keeps genuinely suffixed pnames such as `nix-output-monitor` intact.
  if [[ "$name" =~ ^(.*)-(${_NIX_OUTPUT_SUFFIXES})$ ]]; then
    local stem="${BASH_REMATCH[1]}"
    [[ "$stem" =~ -[^a-zA-Z] ]] && name="$stem"
  fi

  # Leftmost split wins: POSIX EREs have no lazy quantifier, so scan by hand.
  local i=0 len=${#name}
  pname="$name"
  version=""
  while (( i < len )); do
    if [[ "${name:i:1}" == "-" && "${name:i+1:1}" =~ [^a-zA-Z] ]]; then
      pname="${name:0:i}"
      version="${name:i+1}"
      break
    fi
    (( i++ ))
  done
  printf '%s\t%s\n' "$pname" "$version"
}

# nix_packages_from_paths  (store paths on stdin) -> sorted unique "pname\tversion"
#
# Skips store paths that are not packages (sources, generated JSON, and other
# closure noise), because a package report is about what you installed.
nix_packages_from_paths() {
  local path entry pname
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    entry="$(nix_parse_store_name "$path")"
    pname="${entry%%$'\t'*}"
    case "$pname" in
      source|source-* | *.json | *.drv | env | *-env) continue ;;
    esac
    printf '%s\n' "$entry"
  done | LC_ALL=C sort -u
}

# nix_toplevel_packages <profile or buildEnv store path> -> "pname\tversion" list
#
# The direct references of a Home Manager `home-path` (or of a Nix profile) are
# exactly the packages that were asked for — their dependencies are one level
# deeper and deliberately not reported.
nix_toplevel_packages() {
  local target="$1" resolved
  [[ -n "$target" ]] || return 1
  command -v nix-store >/dev/null 2>&1 || return 1
  resolved="$(readlink -f "$target" 2>/dev/null)" || return 1
  [[ -n "$resolved" ]] || return 1
  [[ -e "$resolved/home-path" ]] && resolved="$(readlink -f "$resolved/home-path")"
  nix-store -q --references "$resolved" 2>/dev/null | nix_packages_from_paths
}

# ── Package delta ───────────────────────────────────────────────────────────

# package_delta <before TSV> <after TSV>
#
# Emits one row per change plus a trailing summary row:
#   upgraded<TAB>pname<TAB>old<TAB>new
#   added<TAB>pname<TAB><TAB>new
#   removed<TAB>pname<TAB>old<TAB>
#   summary<TAB>upgraded<TAB>added<TAB>removed<TAB>unchanged
package_delta() {
  awk -F '\t' '
    NR == FNR { if (NF >= 1 && $1 != "") { before[$1] = $2; n_before++ } ; next }
    NF >= 1 && $1 != "" {
      seen[$1] = 1
      if (!($1 in before)) { added[$1] = $2; n_added++ }
      else if (before[$1] != $2) { up_old[$1] = before[$1]; up_new[$1] = $2; n_up++ }
      else n_same++
    }
    END {
      for (p in up_new) printf "upgraded\t%s\t%s\t%s\n", p, up_old[p], up_new[p]
      for (p in added)  printf "added\t%s\t\t%s\n", p, added[p]
      for (p in before) if (!(p in seen)) { printf "removed\t%s\t%s\t\n", p, before[p]; n_removed++ }
      printf "summary\t%d\t%d\t%d\t%d\n", n_up, n_added, n_removed, n_same
    }
  ' <(printf '%s\n' "$1") <(printf '%s\n' "$2") | LC_ALL=C sort
}

# ── Git worktree ────────────────────────────────────────────────────────────

# git_worktree_state <repo> -> "clean|dirty|no-repo\tmodified\tuntracked"
git_worktree_state() {
  local repo="$1" porcelain modified untracked
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'no-repo\t0\t0\n'
    return 0
  fi
  porcelain="$(git -C "$repo" status --porcelain 2>/dev/null)"
  if [[ -z "$porcelain" ]]; then
    printf 'clean\t0\t0\n'
    return 0
  fi
  untracked="$(printf '%s\n' "$porcelain" | grep -c '^??' || true)"
  modified="$(printf '%s\n' "$porcelain" | grep -vc '^??' || true)"
  printf 'dirty\t%s\t%s\n' "$modified" "$untracked"
}

# git_upstream <repo> -> upstream ref, or empty when none is configured
git_upstream() {
  git -C "$1" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true
}

# ── Warning classification ──────────────────────────────────────────────────

# classify_warning <line> -> "severity\tsource\tmessage"
#
# Turns the handful of warnings this stack emits every run into something a
# human can act on — or demotes them to information when they are expected.
# Returns 1 for anything unrecognised so callers can ignore ordinary output.
classify_warning() {
  local line="$1" n systems

  case "$line" in
    *"omitted these incompatible systems"*)
      systems="${line#*incompatible systems: }"
      printf 'info\tflake\t%s checks skipped on this host (use --full-check for all systems)\n' "$systems"
      return 0 ;;
    *"unread and relevant news items"*)
      n="$(printf '%s' "$line" | grep -oE '[0-9]+' | head -1)"
      printf 'info\thome-manager\t%s unread news entries (read them with: home-manager news)\n' "${n:-some}"
      return 0 ;;
    *"is a deprecated alias for"*)
      printf 'warn\thome-manager\tdeprecation notice during activation (see the run log)\n'
      return 0 ;;
    *"not added from a flake"*|*"can't be checked for upgrades"*)
      printf 'info\tnix profile\tskipped a profile entry that Home Manager owns\n'
      return 0 ;;
    *ERESOLVE*|*"peer dep"*)
      printf 'warn\tnpm\tincompatible peer dependency reported during install (see the run log)\n'
      return 0 ;;
    *"Git tree"*"is dirty"*)
      printf 'info\tgit\tbuilt from a dirty worktree (--allow-dirty was given)\n'
      return 0 ;;
    *"error:"*)
      printf 'warn\tlog\t%s\n' "${line#*error: }"
      return 0 ;;
  esac
  return 1
}
