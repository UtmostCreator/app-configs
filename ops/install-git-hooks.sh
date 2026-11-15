#!/usr/bin/env bash
# Install the tracked git hook dispatchers (T-0051, the no-stash guard).
#
#   bash ops/install-git-hooks.sh           # install from the committed HEAD
#   bash ops/install-git-hooks.sh --check   # read-only: are the hooks intact?
#
# Why not `lefthook install`: its generated hooks fail open (LEFTHOOK=0 skips
# them, a missing binary only echoes) and lefthook may stash unstaged changes
# (some versions, or `stage_fixed` jobs), which AGENTS.md forbids because
# `git stash` is shared by every worktree. The
# dispatchers in ops/githooks/ refuse those cases first (see _lefthook.sh and
# pre-commit) and then hand over to lefthook.
#
# Install copies the dispatchers from the committed HEAD blobs (an uncommitted
# edit is never installed) into <git-common-dir>/app-configs-hooks, records the
# source commit and blob ids in .manifest (written last), and points
# core.hooksPath at that absolute directory. It never runs `lefthook uninstall`
# (with core.hooksPath set that deletes the files in the hooks path).
#
# Run it from the main worktree; linked worktrees share the same hooks.
# Exit: 0 ok, 1 refused / check failed, 64 bad arguments.
#
# bash 3.2 safe (macOS): no mapfile, no associative arrays, no `set -u`
# (empty arrays are unbound there).
set -eo pipefail

MODE=install
for arg in "$@"; do
  case "$arg" in
    --check) MODE=check ;;
    -h | --help)
      echo "Usage: bash ops/install-git-hooks.sh [--check] [-h|--help]"
      echo "Install the git hook dispatchers from HEAD; --check verifies them read-only."
      exit 0
      ;;
    *)
      echo "install-git-hooks.sh: unknown argument: $arg (usage: install-git-hooks.sh [--check])" >&2
      exit 64
      ;;
  esac
done

ROOT="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
HOOKS=(pre-commit commit-msg pre-push post-merge)
SUPPORT=_lefthook.sh
MARKER=call_lefthook # present in every hook that lefthook itself generates
SRC=ops/githooks

say() { printf '[git-hooks] %s\n' "$*"; }
die() { printf '[git-hooks] %s\n' "$*" >&2; exit 1; }
g() { git -C "$ROOT" "$@"; }

command -v git >/dev/null 2>&1 || die "git not found"

common="$(g rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ||
  die "cannot resolve the git directory (git >= 2.31 is required for rev-parse --path-format=absolute)"
gitdir="$(g rev-parse --path-format=absolute --git-dir)"
dest="$common/app-configs-hooks"
is_main=0
[ "$gitdir" = "$common" ] && is_main=1

main_worktree() {
  local _k main=""
  read -r _k main < <(g worktree list --porcelain) || true
  printf '%s\n' "${main:-$common}"
}

# Names under ops/githooks/ in HEAD (the "source set").
head_names() {
  local n
  g ls-tree --name-only HEAD "$SRC/" 2>/dev/null | while IFS= read -r n; do printf '%s\n' "${n##*/}"; done
}

in_list() { # in_list <item> <list...>
  local item="$1" x
  shift
  for x in "$@"; do [ "$x" = "$item" ] && return 0; done
  return 1
}

has_marker() { [ -f "$1" ] && grep -q "$MARKER" "$1" 2>/dev/null; }

# Advisory only: things that make the installed hooks less than the whole story.
advise() {
  local h f g
  g="$(git config --global --get core.hooksPath 2>/dev/null || true)"
  [ -z "$g" ] || say "warning: a global core.hooksPath ($g) is overridden by this repository's local one"
  for f in "$common"/hooks/*; do
    [ -f "$f" ] || continue
    h="${f##*/}"
    case "$h" in *.sample) continue ;; esac
    has_marker "$f" && in_list "$h" "${HOOKS[@]}" && continue
    say "warning: $f is not used while core.hooksPath is set (it is not ours; move or remove it if it matters)"
  done
}

# ── --check ─────────────────────────────────────────────────────────────────
if [ "$MODE" = check ]; then
  problems=0
  bad() { printf '[git-hooks] problem: %s\n' "$*" >&2; problems=$((problems + 1)); }

  cur="$(g config --get core.hooksPath 2>/dev/null || true)"
  [ "$cur" = "$dest" ] || bad "core.hooksPath is '${cur:-unset}', expected $dest"

  expected=()
  if [ "$is_main" = 1 ]; then
    while IFS= read -r n; do [ -z "$n" ] || expected+=("$n"); done < <(head_names)
  else
    expected=("${HOOKS[@]}" "$SUPPORT")
  fi

  if [ ! -d "$dest" ]; then
    bad "$dest is missing"
  elif [ ! -s "$dest/.manifest" ]; then
    bad "$dest/.manifest is missing or empty"
  else
    mnames=()
    mids=()
    parsed=1
    first=1
    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$first" = 1 ]; then
        first=0
        [[ "$line" =~ ^commit\ [0-9a-f]{40,64}$ ]] || parsed=0
      elif [[ "$line" =~ ^([^\ /]+)\ ([0-9a-f]{40,64})$ ]]; then
        mnames+=("${BASH_REMATCH[1]}")
        mids+=("${BASH_REMATCH[2]}")
      else
        parsed=0
      fi
    done <"$dest/.manifest"
    if [ "$parsed" = 0 ] || [ "${#mnames[@]}" -eq 0 ]; then
      bad "$dest/.manifest is unparsable"
    else
      for n in "${expected[@]}"; do
        in_list "$n" "${mnames[@]}" || bad "manifest lacks $n"
      done
      for n in "${mnames[@]}"; do
        in_list "$n" "${expected[@]}" || bad "manifest has unexpected entry $n"
      done
      i=0
      for n in "${mnames[@]}"; do
        id="${mids[$i]}"
        i=$((i + 1))
        if [ ! -f "$dest/$n" ]; then
          bad "$dest/$n is missing"
          continue
        fi
        [ -x "$dest/$n" ] || bad "$dest/$n is not executable"
        actual="$(g hash-object --no-filters -- "$dest/$n")"
        [ "$actual" = "$id" ] || bad "$dest/$n differs from the installed manifest (edited?)"
        if [ "$is_main" = 1 ]; then
          headid="$(g rev-parse --verify --quiet "HEAD:$SRC/$n" || true)"
          [ "$headid" = "$id" ] || bad "$n in HEAD differs from the installed copy (re-run the installer)"
        fi
      done
    fi
  fi

  for h in "${HOOKS[@]}"; do
    if has_marker "$common/hooks/$h"; then
      say "warning: stale lefthook-generated hook $common/hooks/$h (the installer removes it)"
    fi
  done
  advise

  if [ "$problems" -gt 0 ]; then
    printf '[git-hooks] %s problem(s); run: bash ops/install-git-hooks.sh (from the main worktree)\n' "$problems" >&2
    exit 1
  fi
  say "ok: $dest"
  exit 0
fi

# ── install ─────────────────────────────────────────────────────────────────
command -v lefthook >/dev/null 2>&1 ||
  die "lefthook not found; install it first (Linux/macOS: sys-install; Windows: winget install --id evilmartians.lefthook --exact)"

[ "$is_main" = 1 ] || die "run from the main worktree: $(main_worktree)"

cur="$(g config --local --get core.hooksPath 2>/dev/null || true)"
if [ -n "$cur" ] && [ "$cur" != "$dest" ]; then
  # A moved or copied clone: our directory name, but the directory is gone.
  # That is ours and stale; repair it. Anything else is a foreign setting.
  if [ "${cur##*/}" = app-configs-hooks ] && [ ! -d "$cur" ]; then
    say "core.hooksPath pointed at a missing $cur (moved clone?); repairing"
  else
    die "core.hooksPath is already set to '$cur' (not ours); unset it or remove it by hand, then re-run"
  fi
fi

# Verify the whole source set BEFORE touching anything.
names=()
while IFS= read -r n; do [ -z "$n" ] || names+=("$n"); done < <(head_names)
for f in "${HOOKS[@]}" "$SUPPORT"; do
  g cat-file -e "HEAD:$SRC/$f" 2>/dev/null ||
    die "HEAD has no $SRC/$f; commit the dispatchers first (nothing was changed)"
done

mkdir -p "$dest"
tmpfiles=()
cleanup() { [ "${#tmpfiles[@]}" -eq 0 ] || rm -f "${tmpfiles[@]}"; }
trap cleanup EXIT

for f in "${names[@]}"; do
  t="$dest/.$f.tmp.$$"
  tmpfiles+=("$t")
  g cat-file blob "HEAD:$SRC/$f" >"$t"
  chmod 0755 "$t" # before the rename, so the name is never visible non-executable
  mv -f "$t" "$dest/$f"
done

# Drop anything in dest that is not in the complete source set (and old temps).
for e in "$dest"/* "$dest"/.[!.]*; do
  [ -e "$e" ] || [ -L "$e" ] || continue
  b="${e##*/}"
  [ "$b" = .manifest ] && continue
  in_list "$b" "${names[@]}" && continue
  [ -d "$e" ] && [ ! -L "$e" ] && continue
  rm -f "$e"
done

# Manifest LAST: a manifest exists only when every copy above is in place.
m="$dest/.manifest.tmp.$$"
tmpfiles+=("$m")
{
  printf 'commit %s\n' "$(g rev-parse HEAD)"
  for f in "${names[@]}"; do printf '%s %s\n' "$f" "$(g rev-parse "HEAD:$SRC/$f")"; done
} >"$m"
mv -f "$m" "$dest/.manifest"

g config --local core.hooksPath "$dest"

# Stale lefthook-generated hooks (hook-set names only) go LAST, once the new
# hooks are active, so a failure above never leaves zero hooks. Never
# `lefthook uninstall`.
for h in "${HOOKS[@]}"; do
  if has_marker "$common/hooks/$h"; then
    rm -f "$common/hooks/$h"
    say "removed stale lefthook hook: $common/hooks/$h"
  fi
done
advise
say "installed ${#names[@]} files into $dest from $(g rev-parse --short HEAD); core.hooksPath set"
