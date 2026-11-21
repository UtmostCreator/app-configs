Source: local

# T-0058: Secret scan and workflow lint must not depend on local hooks alone (bug)

Status: open (verified 2026-11-21 from an external audit; not started)
Relates to: ADR-0005, T-0051

Written 2026-11-21 against main 0b09964 from a read-only verification of an external audit.

## Findings (verified by reading the code; nothing executed)
- SEC-01: `ops/hooks/pre-commit.sh:45-46` says nothing leaves the machine unscanned, but `ops/hooks/pre-push.sh:20-23` exits on `SKIP_HOOKS=1`, `:58-66` pushes with no scanner when `APP_CONFIGS_ALLOW_MISSING_SCANNER=1`, and `git push --no-verify` skips the hook. `.github/workflows/ci.yml` and `ops/ci.sh` run no gitleaks or trufflehog step, so nothing catches a bypassed push.
- SEC-01b: the trufflehog fallback (`pre-push.sh:52-55`) scans only the tip snapshot, so a secret added and removed inside the pushed range is missed.
- HOOK-01: `pre-push.sh:140-151` runs `actionlint` and `zizmor .github/workflows` on the working tree, not on the pushed commits; CI runs neither.

## Acceptance criteria
- AC1: the pre-commit and pre-push comments state the real guarantee: scanned locally unless an explicit bypass is used.
- AC2: CI scans the pushed commit range for secrets and fails when the scanner is missing, crashes or times out.
- AC3: the trufflehog fallback scans every commit in the pushed range.
- AC4: workflow lint reads the workflow files of each pushed commit (for example from `git archive`), so dirty, staged and untracked files cannot change the result; deletions and merge commits are covered.
- AC5: tests: a local bypass still fails CI on a seeded synthetic secret (no real credential in fixtures); a dirty workflow file does not change the pre-push result.
- AC6: ADR-0005 is amended for the CI backstop.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
