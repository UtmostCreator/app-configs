# Execution Protocol

Use this as the canonical operating contract for non-trivial AI-assisted planning, editing, review, and verification.

## 1) Prime Directive

Prefer the smallest safe change that is easy for humans to read, maintain, and modify.

## 2) Conflict Priority

When guidance conflicts, use this order: direct user request -> active repository evidence -> canonical docs under `docs/ai/` -> adapter files.

## 3) Source-of-Truth Order

Follow `docs/ai/source-of-truth.md` and treat adapter files as summaries.

## 4) Task Mode Detection

Classify the task before edits: research, plan, test-only, source-fix, refactor, docs-only, config-infra, migration-data.

## 5) Understanding Gate

Do not edit until scope, owner paths, and verification target are clear enough to avoid speculative changes.

## 6) Dirty Worktree Protection

Inspect `git status --short` and relevant `git diff` before edits. Do not overwrite pre-existing user changes without explicit approval.

## 7) Edit Transaction Protocol

1. declare intended scope
2. apply minimal focused edits
3. inspect final diff
4. verify with the smallest relevant proof

## 8) Patch-Only Rule

Use patch-sized updates and avoid broad rewrites unless explicitly approved.

## 9) Scope and Diff Budget

Default budget: about 6 files or 300 lines changed. Pause for re-approval if exceeded.

## 10) Protected Actions

Treat destructive commands, dependency changes, lockfile changes, migrations, auth/security changes, CI/deploy changes, generated-artifact rewrites, and public-contract changes as approval-gated.

## 11) Public Contract Gate

Escalate when changes affect public interfaces, schemas, package boundaries, or install contracts.

## 12) Snapshot and Fixture Policy

Do not update snapshots/fixtures only to make tests pass; prove behavior first.

## 13) Data Safety Rule

Never read or expose secrets. Keep sensitive files and credentials out of normal mutation flow.

## 14) Verification Classification

Use one status in final output: `verified`, `partially-verified`, `not-verified`, or `failed-verification`.

## 15) Checkpoint and Resume

Use `docs/ai/session-reentry.md` and preserve concise handoff context when work spans sessions.

## 16) Non-Interactive Mode

Follow `docs/ai/failure-handling.md` for retries, stop conditions, and command failure logging.

## 17) Final Output Contract

For code/config changes report: changed files, verification run, verification status, assumptions, rollback posture for medium/high risk, and remaining risks.
