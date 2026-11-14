---
name: verify-change
description: Use when implementation claims must be proven before handoff or release; run targeted verification and record reproducible evidence.
---

# Verify change

Run the **smallest proof** that can catch the likely failure, then report
completed versus recommended verification honestly.

## Choose This Skill When

- Implementation claims must be proven before handoff or release.
- You are deciding the smallest verification that can catch the likely failure.

## Choose Another Skill When

- Use `review-diff` when you are judging an existing patch for correctness.
- Use `bug-reproduction-and-fix` when you are implementing and proving a bug fix.
- Use `release-safety` when designing rollout and rollback controls.
- Use `test-quality-audit` when passing tests exist but their protection value is the question.
- Use `human-handoff` when a required check can only be run or approved by a person.

## Verification ladder

1. **Static first.** The project's formatter in check mode, linter, and compile or type check,
   scoped to the touched package.
2. **Focused test.** The unit or feature test nearest the change — a single
   package or a single failing case — before any broad suite.
3. **Affected layer.** Widen to the affected layer's tests only when the change
   crosses a boundary (a shared type, a golden, a public contract).
4. **Broad suite.** The project's full test suite, only when risk or a golden
   re-freeze demands whole-tree confirmation.

Resolve each rung to a real command by discovery — the repository's documented
task runner, script manifest, or CI configuration — never by assuming an
ecosystem. If no command can be discovered, say so and stop; do not guess one.

## Criterion states

Record every required acceptance criterion separately with its command or inspection,
scope, observed result, and evidence. Use only:

- `pass` — the named evidence proves the criterion
- `fail` — the evidence contradicts the criterion
- `blocked` — a required dependency or service prevented the check
- `not_applicable` — the criterion does not apply, with a reason
- `unverified` — evidence is absent, insufficient, or contradictory

Derive the overall result: `fail` if any required criterion fails; otherwise
`blocked` if any is blocked; otherwise `unverified` if any is unverified; otherwise
`pass` when all required criteria pass or are justified as not applicable. Never let
a missing result imply success.

```yaml
criterion: AC-003
state: blocked
reason: Required service unavailable
evidence:
  attempted_command: "..."
  exit_status: 1
```

Report these states exactly as named, with the supporting proof as evidence in
your report.

## Reporting contract

- Separate **completed** verification (commands you ran, with their result) from
  **recommended** verification (commands a reviewer should still run and why).
- Re-run the relevant final verification after the last corrective edit.
- Never claim an unexecuted command as passed. Use `Not run: <cmd> — <reason>`
  and `Recommended: <cmd> — <why>` verbatim.
- Evidence that must be kept goes where the project's instructions name or, in
  the work layout Glyphbrace installs, to `docs/work/active/<work-id>/evidence/`
  (copy `docs/shared/templates/verification-evidence.template.md` when it
  exists); output left in a temporary folder is not kept evidence. Saving it
  needs write authority in your own role; otherwise put it in your report.

## Never

- Edit project source or apply remediation while verifying. Return findings to the
  change owner; verification may exercise isolated fixtures and write evidence.
- Weaken a test, assertion, schema, or golden to make a check pass.
- Report a suite as green without pasted evidence for the run that proves it.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
