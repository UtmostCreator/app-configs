#!/usr/bin/env bash
# post-merge: after a pull/merge, say what needs re-applying. Prints hints
# only; it never runs anything, so it cannot fail or surprise a merge.
set -uo pipefail

base="$(git rev-parse --verify --quiet ORIG_HEAD || true)"
[[ -n "$base" ]] || exit 0

changed="$(git diff --name-only "$base" HEAD 2>/dev/null || true)"
[[ -n "$changed" ]] || exit 0

hint() { printf '[post-merge] %s changed -> %s\n' "$1" "$2"; }

grep -qE '^(flake\.lock|nix/)' <<<"$changed" && hint "nix/ or flake.lock" "run: sys-update"
grep -q '^home/' <<<"$changed" && hint "home/" "run: chezmoi apply"
grep -q '^mise\.toml$' <<<"$changed" && hint "mise.toml" "run: mise install"
grep -q '^\.lefthook\.yml$' <<<"$changed" && hint ".lefthook.yml" "run: bash ops/install-git-hooks.sh"

# The dispatchers are installed copies: drift (a changed ops/githooks/ blob, or
# edited/removed copies) means the installer has to run again. Read-only.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -f "$root/ops/install-git-hooks.sh" ]] && ! bash "$root/ops/install-git-hooks.sh" --check >/dev/null 2>&1; then
  hint "git hooks" "run: bash ops/install-git-hooks.sh"
fi

exit 0
