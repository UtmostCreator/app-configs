#!/usr/bin/env bash
# pre-push: inspect the commits being pushed (catches --no-verify commits).
#   1. Optionally block direct pushes to protected branches.
#   2. Reject conflict markers added by the pushed commits.
#   3. Scan the pushed commits for secrets (gitleaks, else trufflehog), within
#      a time budget. This is the only secret scan: pre-commit does none.
#   4. Lint GitHub workflows with actionlint and zizmor, only when a pushed
#      commit changes a file under .github/workflows/. This is the only place
#      those two run.
#
# Protection is opt-in because this repo is normally pushed to main directly:
#   PUSH_PROTECTED_BRANCHES='^(main|release/.*)$' git push
# Escape hatch for a single push: SKIP_HOOKS=1 git push
# Secret scan: only the commits being pushed are scanned, so it stays fast.
#   APP_CONFIGS_SECRET_SCAN_TIMEOUT   seconds allowed per pushed ref (default 10);
#                                     a scan that runs over blocks the push.
#   APP_CONFIGS_ALLOW_MISSING_SCANNER=1   bootstrap only: push without a scanner.
set -euo pipefail

if [[ "${SKIP_HOOKS:-0}" == "1" ]]; then
    echo "[pre-push] skipped (SKIP_HOOKS=1)"
    exit 0
fi

diff="$(mktemp "${TMPDIR:-/tmp}/app-configs-prepush.XXXXXX")"
snap=""
cr=$'\r' # CRLF files end markers with \r
trap 'rm -f "$diff"; [[ -z "$snap" ]] || rm -rf "$snap"' EXIT

scan_budget="${APP_CONFIGS_SECRET_SCAN_TIMEOUT:-10}"
workflows_changed=0

# budgeted CMD...: run CMD under the time budget when `timeout` exists (stock
# macOS has none; the scan then runs unbounded rather than not at all).
budgeted() {
    if command -v timeout >/dev/null 2>&1; then
        timeout "$scan_budget" "$@"
    else
        "$@"
    fi
}

# scan_secrets LOCAL_SHA LOG_RANGE: fail the push on a finding, on a scan that
# exceeds the budget, or when no scanner is installed (fail closed).
scan_secrets() {
    local local_sha="$1" log_range="$2" rc=0
    if command -v gitleaks >/dev/null 2>&1; then
        # `gitleaks git` is the supported form (protect is deprecated);
        # --log-opts limits it to the commits being pushed.
        budgeted gitleaks git --redact --verbose --no-banner --log-opts="$log_range" . || rc=$?
    elif command -v trufflehog >/dev/null 2>&1; then
        # A snapshot of the pushed commit, not the worktree.
        snap="$(mktemp -d "${TMPDIR:-/tmp}/app-configs-pushed.XXXXXX")"
        git archive "$local_sha" | tar -x -C "$snap"
        budgeted trufflehog filesystem "$snap" --results=verified,unknown --fail || rc=$?
        rm -rf "$snap"
        snap=""
    elif [[ "${APP_CONFIGS_ALLOW_MISSING_SCANNER:-}" == "1" ]]; then
        # Deliberate bootstrap escape hatch: the push goes through, but loudly.
        {
            echo "[pre-push] ************************************************************"
            echo "[pre-push] WARNING: no secret scanner installed; pushed commits were NOT scanned."
            echo "[pre-push] APP_CONFIGS_ALLOW_MISSING_SCANNER=1 is set, so this push is allowed."
            echo "[pre-push] Use this only while bootstrapping; install gitleaks (sys-update) next."
            echo "[pre-push] ************************************************************"
        } >&2
        return 0
    else
        # Security gate: fail closed so a push never looks scanned when it was not.
        {
            echo "[pre-push] no secret scanner found (need gitleaks or trufflehog); push blocked."
            echo "[pre-push] Install: gitleaks is provided by nix/modules/home/dev.nix; run sys-update."
            echo "[pre-push] Bootstrap only: APP_CONFIGS_ALLOW_MISSING_SCANNER=1 git push ... (skips the scan)"
        } >&2
        return 1
    fi
    if ((rc == 124)); then
        {
            echo "[pre-push] the secret scan exceeded its time budget of ${scan_budget}s; push blocked."
            echo "[pre-push] Raise it for this push: APP_CONFIGS_SECRET_SCAN_TIMEOUT=60 git push"
        } >&2
        return 1
    fi
    if ((rc != 0)); then
        echo "[pre-push] the secret scan reported a possible secret in the pushed commits; push blocked." >&2
        return 1
    fi
}

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
        log_range="$local_sha --not --remotes"
    else
        range=("$remote_sha..$local_sha")
        log_range="$remote_sha..$local_sha"
    fi

    # Capture first: a failing rev-list inside process substitution would be
    # hidden and the push would pass unchecked. Fail closed instead.
    if ! shas="$(git rev-list "${range[@]}")"; then
        echo "[pre-push] cannot list commits for $remote_ref (unknown remote sha?); blocking."
        exit 1
    fi

    while IFS= read -r sha; do
        [[ -n "$sha" ]] || continue
        # --diff-merges=first-parent so a merge commit shows what it brings in
        # (plain `git show` on a merge prints a combined diff with `++` lines).
        # Written to a temp file, not piped: `git show | grep -q` would SIGPIPE
        # git on large diffs and pipefail would then report "no match".
        git show --diff-merges=first-parent --format= --unified=0 "$sha" >"$diff"
        if grep -aE "^\+(<{7}|>{7})( |${cr}?\$)" "$diff" >/dev/null; then
            echo "[pre-push] conflict markers added in commit $sha"
            exit 1
        fi
    done <<<"$shas"

    # Nothing new to push for this ref: nothing to scan.
    [[ -n "$shas" ]] || continue
    scan_secrets "$local_sha" "$log_range" || exit 1

    if git log --format= --name-only "${range[@]}" -- .github/workflows | grep -q .; then
        workflows_changed=1
    fi
done

# Workflow lint, once, and only when a pushed commit changed a workflow. Run on
# the working tree's workflow files (what the push normally carries). A missing
# linter is noted, not fatal: both are optional developer tools.
if ((workflows_changed)) && [[ -d .github/workflows ]]; then
    if command -v actionlint >/dev/null 2>&1; then
        if ! actionlint; then
            echo "[pre-push] actionlint found problems in .github/workflows; push blocked." >&2
            exit 1
        fi
    else
        echo "[pre-push] note: actionlint not installed; workflow syntax was not checked."
    fi
    if command -v zizmor >/dev/null 2>&1; then
        if ! zizmor --offline --no-progress .github/workflows; then
            echo "[pre-push] zizmor found security problems in .github/workflows; push blocked." >&2
            exit 1
        fi
    else
        echo "[pre-push] note: zizmor not installed; workflow security was not checked."
    fi
fi

exit 0
