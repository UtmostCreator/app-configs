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

# _nix_version_starts <text after a dash>: succeeds when it begins a version.
# A version starts with a non-letter, `v<digit>` or `unstable-<digit>`.
_nix_version_starts() {
  [[ "$1" =~ ^([^a-zA-Z]|v[0-9]|unstable-[0-9]) ]]
}

# nix_parse_store_name <store path or basename> -> "pname\tversion"
#
# Follows the nixpkgs convention that the version starts at the first dash
# followed by a version-looking token (so `python3.14-lizard-1.24.0` splits
# correctly, `foo-v1.2.3` keeps `v1.2.3` as the version, and `vicinae-resize`
# is recognised as having no version at all).
nix_parse_store_name() {
  local name="${1##*/}" pname version
  # Drop the 32-character store hash prefix when present.
  [[ "$name" =~ ^[0-9a-df-np-sv-z]{32}-(.*)$ ]] && name="${BASH_REMATCH[1]}"

  # Peel one output suffix, but only if a version survives underneath it —
  # that keeps genuinely suffixed pnames such as `nix-output-monitor` intact.
  if [[ "$name" =~ ^(.*)-(${_NIX_OUTPUT_SUFFIXES})$ ]]; then
    local stem="${BASH_REMATCH[1]}" j
    for (( j = 0; j < ${#stem}; ++j )); do
      if [[ "${stem:j:1}" == "-" ]] && _nix_version_starts "${stem:j+1}"; then
        name="$stem"
        break
      fi
    done
  fi

  # Leftmost split wins: POSIX EREs have no lazy quantifier, so scan by hand.
  # (for-loop arithmetic, not a bare `((i++))`, which returns 1 when i is 0
  # and would abort a caller running under `set -e`.)
  local i len=${#name}
  pname="$name"
  version=""
  for (( i = 0; i < len; ++i )); do
    if [[ "${name:i:1}" == "-" ]] && _nix_version_starts "${name:i+1}"; then
      pname="${name:0:i}"
      version="${name:i+1}"
      break
    fi
  done
  printf '%s\t%s\n' "$pname" "$version"
}

# nix_packages_from_paths  (store paths on stdin) -> sorted unique "pname\tversion"
#
# Skips store paths that are not packages (sources, generated JSON, derivations
# and build environments), judged on the basename: `foo-1.0.drv` parses to
# pname `foo`, so only the whole name reveals what it is.
nix_packages_from_paths() {
  local path base
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    base="${path##*/}"
    [[ "$base" =~ ^[0-9a-df-np-sv-z]{32}-(.*)$ ]] && base="${BASH_REMATCH[1]}"
    case "$base" in
      source|source-* | *.json | *.drv | env | *-env) continue ;;
    esac
    nix_parse_store_name "$path"
  done | LC_ALL=C sort -u
}

# nix_toplevel_packages <profile or buildEnv store path> -> "pname\tversion" list
#
# The direct references of a Home Manager `home-path` (or of a Nix profile) are
# exactly the packages that were asked for — their dependencies are one level
# deeper and deliberately not reported. Fails when nix-store fails, so a
# half-read closure is never mistaken for the package list.
nix_toplevel_packages() {
  local target="$1" resolved refs
  [[ -n "$target" ]] || return 1
  command -v nix-store >/dev/null 2>&1 || return 1
  resolved="$(readlink -f "$target" 2>/dev/null)" || return 1
  [[ -n "$resolved" ]] || return 1
  [[ -e "$resolved/home-path" ]] && resolved="$(readlink -f "$resolved/home-path")"
  refs="$(nix-store -q --references "$resolved" 2>/dev/null)" || return 1
  printf '%s\n' "$refs" | nix_packages_from_paths
}

# ── Package delta ───────────────────────────────────────────────────────────

# package_delta <before TSV> <after TSV>
#
# Input rows are "pname<TAB>version". Duplicate rows collapse; several versions
# of one pname are compared as a set (inputs are sorted first, so row order
# does not matter). A same-version rebuild is invisible here: the rows carry no
# build identity, so detecting it needs a producer change (follow-up).
#
# Emits one row per change, sorted, then a final summary row:
#   upgraded<TAB>pname<TAB>old<TAB>new
#   added<TAB>pname<TAB><TAB>new
#   removed<TAB>pname<TAB>old<TAB>
#   summary<TAB>upgraded<TAB>added<TAB>removed<TAB>unchanged   (always last)
package_delta() {
  # The summary row is emitted as "~summary" so a C-locale sort places it
  # after every lowercase change row; sed then restores its real name.
  awk -F '\t' '
    FNR == 1 { file++ }
    NF >= 1 && $1 != "" {
      pair = file SUBSEP $1 SUBSEP $2
      if (pair in seen) next
      seen[pair] = 1
      key = file SUBSEP $1
      if (key in ver) ver[key] = ver[key] "," $2
      else ver[key] = $2
      if (file == 1) before[$1] = 1; else after[$1] = 1
    }
    END {
      for (p in before) {
        k1 = 1 SUBSEP p; k2 = 2 SUBSEP p
        if (!(p in after)) { printf "removed\t%s\t%s\t\n", p, ver[k1]; n_rm++ }
        else if (ver[k1] != ver[k2]) { printf "upgraded\t%s\t%s\t%s\n", p, ver[k1], ver[k2]; n_up++ }
        else n_same++
      }
      for (p in after) if (!(p in before)) { printf "added\t%s\t\t%s\n", p, ver[2 SUBSEP p]; n_add++ }
      printf "~summary\t%d\t%d\t%d\t%d\n", n_up, n_add, n_rm, n_same
    }
  ' <(printf '%s\n' "$1" | LC_ALL=C sort -u) <(printf '%s\n' "$2" | LC_ALL=C sort -u) | LC_ALL=C sort | sed 's/^~summary/summary/'
}

# ── Git worktree ────────────────────────────────────────────────────────────

# git_worktree_state <repo> -> "clean|dirty|no-repo|error\tmodified\tuntracked"
#
# Fails closed: when `git status` itself fails (corrupt index, lock problems,
# ...) the state is `error` and the exit status is 1 — never `clean`. A
# non-repository is not a failure (`no-repo`, status 0). Read-only: optional
# locks are disabled so the probe cannot write to the index, and every
# untracked file is listed rather than just its top-level directory.
git_worktree_state() {
  local repo="$1" porcelain modified untracked
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'no-repo\t0\t0\n'
    return 0
  fi
  if ! porcelain="$(GIT_OPTIONAL_LOCKS=0 git -C "$repo" status --porcelain --untracked-files=all 2>/dev/null)"; then
    printf 'error\t0\t0\n'
    return 1
  fi
  if [[ -z "$porcelain" ]]; then
    printf 'clean\t0\t0\n'
    return 0
  fi
  untracked="$(printf '%s\n' "$porcelain" | grep -c '^??' || true)"
  modified="$(printf '%s\n' "$porcelain" | grep -vc '^??' || true)"
  printf 'dirty\t%s\t%s\n' "$modified" "$untracked"
}

# git_upstream <repo> -> upstream ref
#
# Empty output with status 0 means "no upstream configured" (detached HEAD, or
# the branch has no remote/merge settings). A non-zero status means the answer
# is unknown: 2 when <repo> is not a repository, 1 when an upstream is
# configured but cannot be resolved.
git_upstream() {
  local repo="$1" branch remote merge
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 2
  branch="$(git -C "$repo" symbolic-ref -q --short HEAD 2>/dev/null)" || return 0
  remote="$(git -C "$repo" config --get "branch.$branch.remote" 2>/dev/null || true)"
  merge="$(git -C "$repo" config --get "branch.$branch.merge" 2>/dev/null || true)"
  [[ -n "$remote" && -n "$merge" ]] || return 0
  git -C "$repo" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || return 1
}

# ── Warning classification ──────────────────────────────────────────────────

# classify_warning <line> -> "info|warn|error\tsource\tmessage"
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
    *"unread and relevant news item"*)
      # The count is the number right before "unread", not the first number
      # on the line (which may be a timestamp).
      n=""
      [[ "$line" =~ ([0-9]+)[[:space:]]+unread ]] && n="${BASH_REMATCH[1]}"
      printf 'info\thome-manager\t%s unread news %s (read them with: home-manager news)\n' \
        "${n:-some}" "$([[ "$n" == 1 ]] && echo entry || echo entries)"
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
      printf 'error\tlog\t%s\n' "${line#*error: }"
      return 0 ;;
  esac
  return 1
}
