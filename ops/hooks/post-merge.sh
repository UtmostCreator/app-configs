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
grep -q '^\.lefthook\.yml$' <<<"$changed" && hint ".lefthook.yml" "run: lefthook install"

exit 0
