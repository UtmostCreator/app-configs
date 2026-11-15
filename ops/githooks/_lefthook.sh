# shellcheck shell=bash
# Sourced by the hook dispatchers next to it (T-0051). It runs BEFORE lefthook
# and refuses to continue when lefthook could be skipped, redirected or made to
# skip commands. lefthook MAY stash unstaged changes (some versions, or jobs
# with `stage_fixed`), and `git stash` is shared by every worktree (AGENTS.md
# forbids it), so nothing may weaken the guard in the dispatchers.
#
# bash 3.2 safe (macOS): no mapfile, no associative arrays.

case "${OSTYPE:-}" in
  msys* | cygwin*) PATH="${BASH%/*}:$PATH" ;;
esac

top="$(git rev-parse --show-toplevel)" || exit 1

_lh_refuse() {
  printf '[git-hooks] refused: %s\n' "$1" >&2
  exit 1
}

# Any LEFTHOOK* variable can disable or redirect lefthook (LEFTHOOK=0,
# LEFTHOOK_EXCLUDE, LEFTHOOK_BIN, ...). Only the two cosmetic ones pass, and
# LEFTHOOK_CONFIG when it already names this checkout's config.
for _lh_var in "${!LEFTHOOK@}"; do
  case "$_lh_var" in
    LEFTHOOK_VERBOSE | LEFTHOOK_QUIET) continue ;;
    LEFTHOOK_CONFIG)
      [ "$LEFTHOOK_CONFIG" = "$top/.lefthook.yml" ] && continue
      ;;
  esac
  _lh_refuse "$_lh_var is set; unset it and commit again."
done

# SKIP_HOOKS=1 is ops/hooks/pre-push.sh's escape hatch. The dispatcher refuses
# it too (fail closed) until the owner decides whether the hatch stays.
if [ -n "${SKIP_HOOKS+x}" ]; then
  _lh_refuse "SKIP_HOOKS is set; unset it and try again."
fi

# A local config turns commands into skips even when LEFTHOOK_CONFIG is pinned.
for _lh_dir in "$top" "$top/.config"; do
  for _lh_prefix in lefthook-local .lefthook-local; do
    for _lh_ext in yml yaml json jsonc toml; do
      if [ -e "$_lh_dir/$_lh_prefix.$_lh_ext" ] || [ -L "$_lh_dir/$_lh_prefix.$_lh_ext" ]; then
        _lh_refuse "local lefthook config found: $_lh_dir/$_lh_prefix.$_lh_ext (remove it)."
      fi
    done
  done
done

[ -f "$top/.lefthook.yml" ] || _lh_refuse "$top/.lefthook.yml is missing."

# Pin the config: an untracked lefthook.yml would otherwise shadow it.
export LEFTHOOK_CONFIG="$top/.lefthook.yml"

if ! command -v lefthook >/dev/null 2>&1; then
  echo "lefthook not found; commit blocked. Install it (Windows: winget install --id evilmartians.lefthook --exact; Linux/macOS: sys-install), then open a new terminal." >&2
  exit 1
fi

cd "$top" || exit 1
