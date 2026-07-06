#!/usr/bin/env bash
# Project-aware verification gate for AI-driven changes.

set -euo pipefail

# shellcheck source=scripts/ai/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

root="${1:-.}"

VERIFY_FULL="${VERIFY_FULL:-0}"
VERIFY_TIMEOUT="${VERIFY_TIMEOUT:-180}"
SHELLCHECK_ARGS="${SHELLCHECK_ARGS:--x -e SC1091}"
AI_VERIFY_SCOPE="${AI_VERIFY_SCOPE:-ai}"
VERIFY_SECRETS="${VERIFY_SECRETS:-${SECRETS_SCAN:-1}}"
# Base ref used by the "branch" scope to diff the current branch against its
# divergence point. Override when your trunk is not origin/main.
VERIFY_BASE_REF="${VERIFY_BASE_REF:-}"
# Optional author filter for the "branch" scope. When set (e.g. your git email),
# only files from commits authored by you (plus uncommitted work) are scoped.
VERIFY_AUTHOR="${VERIFY_AUTHOR:-}"
# Link checking is OFF by default because it can reach the network and hit
# production URLs embedded in docs. Set VERIFY_LINKS=1 to enable it. Even then,
# lychee runs with --offline (local file links only) unless VERIFY_LINKS_NETWORK=1
# is also set, so a verify run never dials production endpoints by accident.
VERIFY_LINKS="${VERIFY_LINKS:-0}"
VERIFY_LINKS_NETWORK="${VERIFY_LINKS_NETWORK:-0}"
# Suggest mode: when set, ESLint additionally runs a non-blocking
# --fix-dry-run --format json pass (advisory only; never fails the gate).
# Off by default.
VERIFY_SUGGEST="${VERIFY_SUGGEST:-0}"

failures=0

cd "$root"

# Resolve the merge-base between HEAD and the branch this branch was created from.
# Prints the merge-base commit, or nothing if it cannot be determined.
#
# Detection order:
#   1. explicit VERIFY_BASE_REF override
#   2. scripts/ai/git-branch-origin.sh (closest-merge-base + release-pattern aware)
#   3. fallback trunk list (origin/main -> origin/master -> main -> master)
resolve_branch_base() {
    local candidate base
    local origin_script
    local detected=""

    # 1. Explicit override always wins.
    if [[ -n "$VERIFY_BASE_REF" ]]; then
        git rev-parse --verify --quiet "$VERIFY_BASE_REF^{commit}" >/dev/null 2>&1 || return 1
        base="$(git merge-base HEAD "$VERIFY_BASE_REF" 2>/dev/null || true)"
        [[ -n "$base" ]] && printf '%s\n' "$base" && return 0
        return 1
    fi

    # 2. Prefer the smarter branch-origin detector when available.
    origin_script="$(dirname "${BASH_SOURCE[0]}")/git-branch-origin.sh"
    if [[ -f "$origin_script" ]]; then
        detected="$(bash "$origin_script" --field base 2>/dev/null || true)"
        if [[ -n "$detected" ]]; then
            printf '%s\n' "$detected"
            return 0
        fi
    fi

    # 3. Fallback trunk list.
    for candidate in origin/main origin/master main master; do
        git rev-parse --verify --quiet "$candidate^{commit}" >/dev/null 2>&1 || continue
        if base="$(git merge-base HEAD "$candidate" 2>/dev/null)" && [[ -n "$base" ]]; then
            printf '%s\n' "$base"
            return 0
        fi
    done

    return 1
}

# Files changed by the current branch since it diverged from its base, plus any
# uncommitted, staged, or untracked work. Respects $1 as a pathspec glob.
# Stops at the merge-base: shared history before the divergence is never touched.
branch_scoped_files() {
    local glob="${1:?glob required}"
    local base=""

    base="$(resolve_branch_base || true)"

    {
        if [[ -n "$base" ]]; then
            if [[ -n "$VERIFY_AUTHOR" ]]; then
                # Only files from commits authored by VERIFY_AUTHOR on this branch.
                local sha
                while IFS= read -r sha; do
                    [[ -n "$sha" ]] || continue
                    git show --no-patch --format= --name-only --diff-filter=ACMRT "$sha" -- "$glob"
                done < <(git rev-list --author="$VERIFY_AUTHOR" "$base..HEAD" 2>/dev/null)
            else
                git diff --name-only --diff-filter=ACMRT "$base"...HEAD -- "$glob"
            fi
        fi
        # Always include local in-progress work regardless of authorship.
        git diff --name-only --diff-filter=ACMRT -- "$glob"
        git diff --cached --name-only --diff-filter=ACMRT -- "$glob"
        git ls-files --others --exclude-standard -- "$glob"
    } | sort -u
}

# Emit existing files matching the given glob(s), scoped per $1 (branch|changed).
# Any caller with mode "all" or "ai" should short-circuit before calling this
# (see changed_files_for) rather than passing those modes in directly.
scoped_files() {
    local mode="${1:?mode required}"
    shift
    local globs=("$@")

    {
        if [[ "$mode" == branch ]]; then
            local g
            for g in "${globs[@]}"; do
                branch_scoped_files "$g"
            done
        else
            git diff --name-only --diff-filter=ACMRT -- "${globs[@]}"
            git diff --cached --name-only --diff-filter=ACMRT -- "${globs[@]}"
            git ls-files --others --exclude-standard -- "${globs[@]}"
        fi
    } |
        sort -u |
        while IFS= read -r f; do
            [[ -n "$f" ]] || continue
            [[ -f "$f" ]] || continue
            printf '%s\n' "$f"
        done
}

# Emit existing files matching the given glob(s) according to AI_VERIFY_SCOPE:
# - ai (default) / branch: merge-base diff of the current branch + local work
# - changed: local working-tree/staged/untracked work only
# Returns no output for the project-wide "all" scope, signalling callers to run
# the tool project-wide instead of per-file.
changed_files_for() {
    local mode
    case "$AI_VERIFY_SCOPE" in
    all) return 0 ;;
    changed) mode=changed ;;
    *) mode=branch ;; # "ai" (default) and "branch" both resolve to branch-aware scoping
    esac
    scoped_files "$mode" "$@"
}

# Emit existing changed PHP files according to AI_VERIFY_SCOPE. Thin wrapper
# kept for call-site readability; behavior is identical to changed_files_for.
scoped_php_files() {
    changed_files_for '*.php'
}

if [[ "${AI_VERIFY_TEST_MODE:-0}" == "1" ]]; then
    echo "==> repository"
    git status --short || true
    echo "==> shellcheck"
    echo "==> composer"
    if [[ "${VERIFY_FULL:-0}" != "1" ]]; then
        log_warn "Skipping full PHP test suite. Use VERIFY_FULL=1 to run phpunit/pest."
    fi
    echo "==> done"
    exit 0
fi

run_step() {
    local label="$1"
    shift

    echo "==> $label"

    # Run under the hang/freeze watchdog: a hard wall-clock ceiling plus
    # idle-output + idle-CPU detection that kills a stuck process group. Set
    # VERIFY_GUARD=0 to fall back to the plain wall-clock timeout wrapper.
    local rc=0
    if [[ "${VERIFY_GUARD:-1}" == "1" ]]; then
        AI_GUARD_TIMEOUT="${AI_GUARD_TIMEOUT:-$VERIFY_TIMEOUT}" run_guarded "$label" "$@" || rc=$?
    else
        run_with_timeout "$VERIFY_TIMEOUT" "$@" || rc=$?
    fi

    if ((rc != 0)); then
        echo "FAIL: $label failed (exit $rc)" >&2
        failures=$((failures + 1))
    fi
}

# Same execution/guard/timeout behavior as run_step, but findings are advisory:
# a non-zero exit is logged as a warning and never increments $failures. Use
# for tools that report existing debt (e.g. composer-unused) rather than
# regressions the gate should block on.
run_step_advisory() {
    local label="$1"
    shift

    echo "==> $label (advisory; findings do not fail the gate)"

    local rc=0
    if [[ "${VERIFY_GUARD:-1}" == "1" ]]; then
        AI_GUARD_TIMEOUT="${AI_GUARD_TIMEOUT:-$VERIFY_TIMEOUT}" run_guarded "$label" "$@" || rc=$?
    else
        run_with_timeout "$VERIFY_TIMEOUT" "$@" || rc=$?
    fi

    if ((rc != 0)); then
        log_warn "$label reported findings (exit $rc) - advisory only, not failing the gate"
    fi
}

has_package_script() {
    local script_name="${1:?script name required}"
    [[ -f package.json ]] || return 1
    jq -e --arg name "$script_name" '.scripts[$name] // empty' package.json >/dev/null 2>&1
}

has_package_dependency() {
    local package_name="${1:?package name required}"
    [[ -f package.json ]] || return 1
    jq -e --arg name "$package_name" '
      (.dependencies[$name] // .devDependencies[$name] // .peerDependencies[$name] // empty)
    ' package.json >/dev/null 2>&1
}

tracked_existing_shell_files() {
    case "$AI_VERIFY_SCOPE" in
    ai)
        git ls-files -co --exclude-standard 'scripts/ai/*.sh' |
            while IFS= read -r script; do
                [[ -f "$script" ]] || continue
                [[ "$script" == scripts/ai/check-batch*.sh ]] && continue
                printf '%s\n' "$script"
            done
        ;;
    changed)
        {
            git diff --name-only --diff-filter=ACMRT -- '*.sh'
            git diff --cached --name-only --diff-filter=ACMRT -- '*.sh'
            git ls-files --others --exclude-standard -- '*.sh'
        } |
            sort -u |
            while IFS= read -r script; do
                [[ -f "$script" ]] || continue
                [[ "$script" == scripts/ai/check-batch*.sh ]] && continue
                printf '%s\n' "$script"
            done
        ;;
    branch)
        branch_scoped_files '*.sh' |
            while IFS= read -r script; do
                [[ -f "$script" ]] || continue
                [[ "$script" == scripts/ai/check-batch*.sh ]] && continue
                printf '%s\n' "$script"
            done
        ;;
    all)
        git ls-files -co --exclude-standard '*.sh' |
            while IFS= read -r script; do
                [[ -f "$script" ]] || continue
                printf '%s\n' "$script"
            done
        ;;
    *)
        die "unknown AI_VERIFY_SCOPE: $AI_VERIFY_SCOPE"
        ;;
    esac
}

echo "==> repository"
git status --short || true

if command -v shellcheck >/dev/null 2>&1; then
    while IFS= read -r script; do
        [[ -n "$script" ]] || continue
        # shellcheck disable=SC2086
        run_step "shellcheck $script" shellcheck $SHELLCHECK_ARGS "$script"
    done < <(tracked_existing_shell_files)
fi

if command -v shfmt >/dev/null 2>&1; then
    while IFS= read -r script; do
        [[ -n "$script" ]] || continue
        run_step "shfmt -d $script" shfmt -d "$script"
    done < <(tracked_existing_shell_files)
fi

if command -v actionlint >/dev/null 2>&1 && [[ -d .github/workflows ]]; then
    if [[ "$AI_VERIFY_SCOPE" == "all" ]]; then
        run_step 'actionlint' actionlint
    else
        workflow_files=()
        while IFS= read -r f; do
            [[ -n "$f" ]] && workflow_files+=("$f")
        done < <(changed_files_for '.github/workflows/*.yml' '.github/workflows/*.yaml')
        if ((${#workflow_files[@]} > 0)); then
            run_step "actionlint (${#workflow_files[@]} changed workflow file(s))" actionlint "${workflow_files[@]}"
        else
            log_warn "No changed workflow files in scope ($AI_VERIFY_SCOPE); skipping actionlint."
        fi
    fi
fi

if { [[ "$VERIFY_LINKS" == "1" ]] || [[ "$VERIFY_FULL" == "1" ]]; } && command -v lychee >/dev/null 2>&1; then
    if [[ -f scripts/run-link-check.sh ]]; then
        run_step 'bash scripts/run-link-check.sh' bash scripts/run-link-check.sh
    elif [[ "$VERIFY_LINKS_NETWORK" == "1" ]]; then
        # Explicit network link check requested. This CAN reach production URLs
        # embedded in docs; only enable when that is intended.
        run_step 'lychee README.md docs/**/*.md' lychee README.md docs/**/*.md
    else
        # Offline by default: validate local file links only, never dial the
        # network (so production URLs in docs are not contacted).
        run_step 'lychee --offline README.md docs/**/*.md' lychee --offline README.md docs/**/*.md
    fi
else
    log_warn "Skipping link check. Use VERIFY_LINKS=1 (offline), VERIFY_FULL=1 (offline, full gate), or VERIFY_LINKS=1 VERIFY_LINKS_NETWORK=1 (network)."
fi

if [[ -f composer.json ]]; then
    # composer validate/audit only when composer.json/composer.lock are
    # actually in scope (branch/changed), or unconditionally for AI_VERIFY_SCOPE=all.
    composer_run=1
    if [[ "$AI_VERIFY_SCOPE" != "all" ]]; then
        composer_changed_files=()
        while IFS= read -r f; do
            [[ -n "$f" ]] && composer_changed_files+=("$f")
        done < <(changed_files_for 'composer.json' 'composer.lock')
        ((${#composer_changed_files[@]} > 0)) || composer_run=0
    fi

    if command -v composer >/dev/null 2>&1; then
        if ((composer_run)); then
            run_step 'composer validate --strict' composer validate --strict
            run_step 'composer audit' composer audit
        else
            log_warn "composer.json/composer.lock unchanged in scope ($AI_VERIFY_SCOPE); skipping composer validate/audit."
        fi
    fi

    if [[ "$VERIFY_FULL" == "1" ]]; then
        if command -v composer-require-checker >/dev/null 2>&1; then
            run_step 'composer-require-checker check composer.json' composer-require-checker check composer.json
        elif [[ -x vendor/bin/composer-require-checker ]]; then
            run_step 'vendor/bin/composer-require-checker check composer.json' vendor/bin/composer-require-checker check composer.json
        fi

        # Advisory only: reports likely-unused composer dependencies without
        # failing the gate (false positives are common for dynamically loaded
        # packages/plugins).
        if [[ -x vendor/bin/composer-unused ]]; then
            run_step_advisory 'vendor/bin/composer-unused' vendor/bin/composer-unused
        fi
    fi

    # Determine whether the PHP linters/analysers should be narrowed to the
    # files changed on this branch, or run project-wide.
    #
    # Default (including the "ai" scope): narrow to changed files. With no local
    # changes we fall back to files unique to the current feature branch via its
    # merge-base (git-branch-origin.sh), so pint/phpstan/psalm/rector never lint
    # the whole project unless the caller explicitly asks with AI_VERIFY_SCOPE=all.
    php_scoped=1
    [[ "$AI_VERIFY_SCOPE" == "all" ]] && php_scoped=0
    php_files=()

    if ((php_scoped)); then
        while IFS= read -r f; do
            [[ -n "$f" ]] && php_files+=("$f")
        done < <(scoped_php_files)
    fi

    # PHPStan/Psalm default to their human-readable console/table output; set
    # AI_OUTPUT=json for machine-readable JSON findings instead (same toggle
    # convention as scripts/ai/ai-search.sh and preview-file.sh).
    phpstan_format_args=()
    psalm_format_args=()
    if [[ "${AI_OUTPUT:-}" == "json" ]]; then
        phpstan_format_args=(--error-format=json)
        psalm_format_args=(--output-format=json)
    fi

    if [[ -x vendor/bin/pint ]]; then
        if ((php_scoped)); then
            if ((${#php_files[@]} > 0)); then
                run_step "vendor/bin/pint --test (${#php_files[@]} changed file(s))" vendor/bin/pint --test "${php_files[@]}"
            else
                log_warn "No changed PHP files in scope ($AI_VERIFY_SCOPE); skipping pint."
            fi
        else
            run_step 'vendor/bin/pint --test' vendor/bin/pint --test
        fi
    fi

    if [[ -x vendor/bin/phpstan ]]; then
        if ((php_scoped)); then
            if ((${#php_files[@]} > 0)); then
                run_step "vendor/bin/phpstan analyse (${#php_files[@]} changed file(s))" vendor/bin/phpstan analyse --memory-limit=1G "${phpstan_format_args[@]}" "${php_files[@]}"
            else
                log_warn "No changed PHP files in scope ($AI_VERIFY_SCOPE); skipping phpstan."
            fi
        else
            run_step 'vendor/bin/phpstan analyse --memory-limit=1G' vendor/bin/phpstan analyse --memory-limit=1G "${phpstan_format_args[@]}"
        fi
    fi

    if [[ -x vendor/bin/psalm ]]; then
        if ((php_scoped)); then
            if ((${#php_files[@]} > 0)); then
                run_step "vendor/bin/psalm (${#php_files[@]} changed file(s))" vendor/bin/psalm --no-cache "${psalm_format_args[@]}" "${php_files[@]}"
            else
                log_warn "No changed PHP files in scope ($AI_VERIFY_SCOPE); skipping psalm."
            fi
        else
            run_step 'vendor/bin/psalm --no-cache' vendor/bin/psalm --no-cache "${psalm_format_args[@]}"
        fi
    fi

    if [[ -x vendor/bin/rector ]]; then
        if ((php_scoped)); then
            if ((${#php_files[@]} > 0)); then
                run_step "vendor/bin/rector process --dry-run (${#php_files[@]} changed file(s))" vendor/bin/rector process --dry-run "${php_files[@]}"
            else
                log_warn "No changed PHP files in scope ($AI_VERIFY_SCOPE); skipping rector."
            fi
        else
            run_step 'vendor/bin/rector process --dry-run' vendor/bin/rector process --dry-run
        fi
    fi

    if [[ "$VERIFY_FULL" == "1" ]]; then
        if [[ -x vendor/bin/deptrac ]]; then
            run_step 'vendor/bin/deptrac analyse' vendor/bin/deptrac analyse
        fi

        if [[ -x vendor/bin/phpunit ]]; then
            run_step 'vendor/bin/phpunit' vendor/bin/phpunit
        fi

        if [[ -x vendor/bin/pest ]]; then
            run_step 'vendor/bin/pest' vendor/bin/pest
        fi
    else
        log_warn "Skipping full PHP test suite. Use VERIFY_FULL=1 to run phpunit/pest."
    fi
fi

if [[ -f package.json ]]; then
    if command -v pnpm >/dev/null 2>&1; then
        # Determine whether ESLint/Biome (when invoked directly, i.e. no
        # project-owned "lint" script) should be narrowed to changed
        # JS/TS/Vue files. Same branch-aware default as the PHP scoping above.
        js_scoped=1
        [[ "$AI_VERIFY_SCOPE" == "all" ]] && js_scoped=0
        js_files=()
        if ((js_scoped)); then
            while IFS= read -r f; do
                [[ -n "$f" ]] && js_files+=("$f")
            done < <(changed_files_for '*.js' '*.jsx' '*.ts' '*.tsx' '*.vue' '*.mjs' '*.cjs')
        fi

        if has_package_script lint; then
            # Project-owned lint script: respect it as-is, not narrowed here.
            run_step 'pnpm run lint' pnpm run lint
        elif has_package_dependency eslint; then
            if ((js_scoped)); then
                if ((${#js_files[@]} > 0)); then
                    run_step "pnpm exec eslint (${#js_files[@]} changed file(s))" pnpm exec eslint "${js_files[@]}"
                else
                    log_warn "No changed JS/TS/Vue files in scope ($AI_VERIFY_SCOPE); skipping eslint."
                fi
            else
                run_step 'pnpm exec eslint .' pnpm exec eslint .
            fi

            # Suggest mode: non-blocking autofix preview as JSON. Off by
            # default; set VERIFY_SUGGEST=1 to enable. Findings never fail
            # the gate (run_step_advisory).
            if [[ "$VERIFY_SUGGEST" == "1" ]]; then
                if ((js_scoped)); then
                    if ((${#js_files[@]} > 0)); then
                        run_step_advisory 'pnpm exec eslint --fix-dry-run --format json (suggest mode)' pnpm exec eslint --fix-dry-run --format json "${js_files[@]}"
                    fi
                else
                    run_step_advisory 'pnpm exec eslint --fix-dry-run --format json (suggest mode)' pnpm exec eslint --fix-dry-run --format json .
                fi
            fi
        fi

        if has_package_script typecheck; then
            run_step 'pnpm run typecheck' pnpm run typecheck
        elif [[ -f tsconfig.json ]] && has_package_dependency typescript; then
            run_step 'pnpm exec tsc --noEmit' pnpm exec tsc --noEmit
        fi

        if has_package_dependency vue-tsc; then
            run_step 'pnpm exec vue-tsc --noEmit' pnpm exec vue-tsc --noEmit
        fi

        if has_package_dependency nuxt || has_package_dependency nuxi; then
            # Nuxt typechecks the whole project graph (no per-file mode), so
            # only gate on WHETHER anything relevant changed, not which files.
            if ((js_scoped)); then
                if ((${#js_files[@]} > 0)); then
                    run_step 'pnpm exec nuxi typecheck' pnpm exec nuxi typecheck
                else
                    log_warn "No changed JS/Vue/Nuxt files in scope ($AI_VERIFY_SCOPE); skipping nuxi typecheck."
                fi
            else
                run_step 'pnpm exec nuxi typecheck' pnpm exec nuxi typecheck
            fi
        fi

        if has_package_dependency @graphql-codegen/cli && [[ -f codegen.yml || -f codegen.yaml || -f codegen.ts ]]; then
            run_step 'pnpm exec graphql-codegen' pnpm exec graphql-codegen
        fi

        if has_package_dependency @graphql-eslint/eslint-plugin; then
            run_step 'pnpm exec graphql-eslint .' pnpm exec graphql-eslint .
        fi

        if has_package_dependency biome; then
            if ((js_scoped)); then
                if ((${#js_files[@]} > 0)); then
                    run_step "pnpm exec biome check (${#js_files[@]} changed file(s))" pnpm exec biome check "${js_files[@]}"
                else
                    log_warn "No changed JS/TS/Vue files in scope ($AI_VERIFY_SCOPE); skipping biome."
                fi
            else
                run_step 'pnpm exec biome check .' pnpm exec biome check .
            fi
        fi

        # Vitest fast path: only the tests affected by files changed since the
        # branch base. Off when VERIFY_FULL=1, where the full run below (or
        # the project's own "test" script) already covers everything.
        if [[ "$VERIFY_FULL" != "1" ]] && has_package_dependency vitest; then
            vitest_base="$(resolve_branch_base || true)"
            if [[ -n "$vitest_base" ]]; then
                run_step "pnpm exec vitest run --changed $vitest_base" pnpm exec vitest run --changed "$vitest_base"
            else
                log_warn "Could not resolve a branch base for vitest --changed; skipping. Use VERIFY_FULL=1 for a full run."
            fi
        fi

        if has_package_dependency knip; then
            if [[ "$VERIFY_FULL" == "1" ]]; then
                run_step 'pnpm exec knip' pnpm exec knip
            else
                log_warn "Skipping knip (unused files/deps/exports). Use VERIFY_FULL=1 to run it."
            fi
        fi

        if [[ "$VERIFY_FULL" == "1" ]] && has_package_dependency jscpd; then
            run_step 'pnpm exec jscpd .' pnpm exec jscpd .
        fi

        if [[ "$VERIFY_FULL" == "1" ]] && has_package_dependency @playwright/test; then
            run_step 'pnpm exec playwright test' pnpm exec playwright test
        fi

        if has_package_script test; then
            if [[ "$VERIFY_FULL" == "1" ]]; then
                run_step 'pnpm test' pnpm test
            else
                log_warn "Skipping full JS test suite. Use VERIFY_FULL=1 to run pnpm test."
            fi
        fi
    elif command -v npm >/dev/null 2>&1; then
        if has_package_script lint; then
            run_step 'npm run lint' npm run lint
        fi

        if has_package_script typecheck; then
            run_step 'npm run typecheck' npm run typecheck
        fi

        if has_package_script test; then
            if [[ "$VERIFY_FULL" == "1" ]]; then
                run_step 'npm test' npm test
            else
                log_warn "Skipping full JS test suite. Use VERIFY_FULL=1 to run npm test."
            fi
        fi
    fi
fi

if [[ "$VERIFY_SECRETS" == "1" ]]; then
    if command -v gitleaks >/dev/null 2>&1; then
        run_step 'gitleaks detect --source . --redact --no-banner' gitleaks detect --source . --redact --no-banner
    fi
else
    log_warn "Skipping secret scan. Use VERIFY_SECRETS=1 to enable gitleaks."
fi

# Full security gate: broad, repo-wide scanners that are too slow/noisy to
# run on every "ai"-scoped edit. Run before merge with VERIFY_FULL=1.
if [[ "$VERIFY_FULL" == "1" ]]; then
    if command -v trivy >/dev/null 2>&1; then
        run_step 'trivy fs --scanners vuln,misconfig,secret .' trivy fs --scanners vuln,misconfig,secret .
    fi

    if command -v semgrep >/dev/null 2>&1; then
        run_step 'semgrep scan --config auto .' semgrep scan --config auto .
    fi

    if command -v osv-scanner >/dev/null 2>&1; then
        # NOTE: `--lockfile=.` is invalid (it treats "." as a single lockfile
        # path, not a directory, and fails with "could not determine
        # extractor"). `--recursive` scans the whole tree for lockfiles, which
        # is what a project-wide full-gate scan is meant to do.
        # `--allow-no-lockfiles` keeps a repo with no PHP/JS/etc. dependency
        # manifests (like this one) from exiting non-zero just because there
        # was nothing to scan.
        run_step 'osv-scanner scan --recursive --allow-no-lockfiles .' osv-scanner scan --recursive --allow-no-lockfiles .
    fi
else
    log_warn "Skipping trivy/semgrep/osv-scanner full security scan. Use VERIFY_FULL=1 to run them."
fi

if ((failures > 0)); then
    echo "==> failed: $failures verification step(s)" >&2
    log_json "verify.failed" "$(jq -cn --argjson failures "$failures" '{failures:$failures}')" || true
    exit 1
fi

echo '==> done'
log_json "verify.passed" "$(jq -cn '{status:"passed"}')" || true
