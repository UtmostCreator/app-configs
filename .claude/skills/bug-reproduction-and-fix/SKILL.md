---
name: bug-reproduction-and-fix
description: Reproduces reported or confirmed defects with regression coverage; applies a narrow authorised fix when the cause is known, or stops after reproduction. Diagnose unknown causes first.
---

## What I Do

I drive a minimal bug-fix workflow: reproduce, localize, fix narrowly, verify, and report evidence.

## Choose This Skill When

- A reported or confirmed defect has a known cause and the fix is authorized (default mode).
- A repeatable defect needs a failing regression test or deterministic reproduction, with or without the fix.

## Choose Another Skill When

- Use `repo-investigation` when the cause is still unknown.
- Use `verify-change` when implementation is already complete and you need proof.
- Use `safe-refactor` when restructuring code without fixing a bug.
- Use `characterization-testing` when no defect is reported and the current behavior of uncovered or legacy code must be recorded before a change.

## Read Alongside

- `verify-change` — to prove the fix and its regression test
- `review-diff` — read its criteria to self-check the patch; independent review belongs to a separate reviewer, not to the author


## Workflow

1. identify the owning layer
2. add the smallest practical failing reproduction with a concise name that reveals the observable defect
3. apply the smallest safe fix
4. review new or changed tests against the repository's testing conventions (see Reproduction proof and Gotchas for what counts)
5. if a test is large or could materially affect performance, profile it with suitable tooling and bounded inputs; record elapsed time, CPU use, and peak memory, then reduce or split it if its resource cost is not justified by the defect coverage
6. follow the verification ladder: focused proof first, affected layer tests second, broader repository verification third, build as a smoke check when relevant, release-safety review only when risk warrants it
7. report reproduction, root cause, fix, and evidence

## Reproduction proof

Record the baseline commit, environment, role, fixture, exact command or journey,
exit status, expected result, observed result, and intended failing assertion. The
baseline proves the bug only when that assertion fails — compilation, fixture setup,
authentication, environment, or an unrelated test failure does not count.

Shrink the reproduction while that assertion still fails, and control time,
randomness, ordering, shared state and external services. For an intermittent
failure, record attempts, failures and environment; a failure rate is not a
deterministic reproduction.

After the fix, repeat the same reproduction and record the fixed commit and passing
assertion; rerun the original scenario where practical, and remove temporary
instrumentation. If baseline execution is impossible, use `unverified`; do not substitute a
weaker claim. Prefer critical behavioral protection over a coverage percentage.

## Modes

Both modes write code or tests; a read-only role uses this skill only to judge regression proof, never to run a mode.

- **default** — the full workflow above.
- **`reproduce_only`** — stop after proving the failure, when the deliverable is a failing or
  proving regression test for a reported bug or edge case, without the fix (this replaces the
  former `regression-test` skill):
  1. identify the smallest useful proving surface
  2. add the narrowest practical test or deterministic reproduction
  3. confirm failure or proving behavior when practical
  4. check the test as in workflow steps 4–5 and Reproduction proof
  5. stop before changing production code; a request that also asks for the fix is default mode, not `reproduce_only`, so state which mode ran in the report

  Do not widen into a broader refactor or feature task.

## Gotchas

- do not weaken assertions to force a pass
- do not skip the reproduction step when a focused check is practical
- tests must use isolated fakes, fixtures, containers, or dedicated test stores; never connect directly to a real database or read real user, production, or environment data unless the user explicitly instructs it
- do not report a recommendation as if it was verified
- do not accept a test that merely executes the path, mirrors the implementation,
  or mocks away the reported failure
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
