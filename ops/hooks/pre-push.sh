#!/usr/bin/env bash
# pre-push: inspect the commits being pushed (catches --no-verify commits).
#   1. Optionally block direct pushes to protected branches.
#   2. Reject conflict markers added by the pushed commits.
#
# Protection is opt-in because this repo is normally pushed to main directly:
#   PUSH_PROTECTED_BRANCHES='^(main|release/.*)$' git push
# Escape hatch for a single push: SKIP_HOOKS=1 git push
set -euo pipefail

if [[ "${SKIP_HOOKS:-0}" == "1" ]]; then
    echo "[pre-push] skipped (SKIP_HOOKS=1)"
    exit 0
fi

zero="0000000000000000000000000000000000000000"
protected="${PUSH_PROTECTED_BRANCHES:-}"

# git passes: <local_ref> <local_sha> <remote_ref> <remote_sha> per pushed ref.
while read -r local_ref local_sha remote_ref remote_sha; do
    [[ -n "${local_ref:-}" ]] || continue
    [[ "$local_sha" == "$zero" ]] && continue # branch deletion

    branch="${remote_ref#refs/heads/}"
    if [[ -n "$protected" && "$remote_ref" == refs/heads/* && "$branch" =~ $protected ]]; then
        echo "[pre-push] direct push to '$branch' is blocked (PUSH_PROTECTED_BRANCHES)."
        echo "[pre-push] open a pull request, or unset the variable for this push."
        exit 1
    fi

    if [[ "$remote_sha" == "$zero" ]]; then
        range=("$local_sha" --not --remotes)
    else
        range=("$remote_sha..$local_sha")
    fi

    while IFS= read -r sha; do
        [[ -n "$sha" ]] || continue
        if git show --format= --unified=0 "$sha" | grep -qE '^\+(<{7}|>{7})( |$)'; then
            echo "[pre-push] conflict markers added in commit $sha"
            exit 1
        fi
    done < <(git rev-list "${range[@]}")
done

exit 0
