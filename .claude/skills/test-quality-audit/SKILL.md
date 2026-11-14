---
name: test-quality-audit
description: Use when judging whether selected existing tests credibly protect behavior through assertion strength, refactoring resistance, mocking, determinism, and cost, without rewriting them.
---

## What I Do

I assess whether a selected set of unchanged tests would actually catch the failures
that matter, and report evidence-backed findings with proposed remediation. I am
read-only with respect to project source and the actual worktree: I never rewrite,
delete, or weaken a test, and I do not fix code. The implementation owner chooses
any authorized remediation.

## Choose This Skill When

- Tests pass, but nobody knows whether they would fail for the defects that matter.
- A suite is about to be relied on as a refactor baseline or release gate.
- Tests are suspected of over-mocking, flakiness, coupling to internals, or excessive cost.

## Choose Another Skill When

- Use `review-diff` when the subject is a patch, including the tests it adds or changes.
- Use `verify-change` when the task is running checks to prove an implementation claim.
- Use `characterization-testing` when behavior that must be preserved has no protection at all; I recommend it, I do not perform it.
- Use `bug-reproduction-and-fix` when the audit surfaces evidence of an actual defect.

## Read Alongside

- `verify-change` — the owner of verification states; when a finding bears on an acceptance criterion, map it to `pass`, `fail`, `blocked`, `not_applicable`, or `unverified` there rather than inventing a state

## Audit Dimensions

1. **Behavioral assertions** — does each test assert an observable outcome, or merely execute the path, mirror the implementation, or assert on its own fixture?
2. **Refactoring resistance** — would a behavior-preserving restructuring break it through private names, call order, or internal structure?
3. **Mocking and coupling** — are the relevant boundary and failure modes still exercised, or mocked away? Name the smallest plausible defect each material test should catch; a passing test does not protect a failure mode outside its observation seam.
4. **Determinism** — uncontrolled time, randomness, ordering, environment, shared state, network, or sleeps.
5. **Cost** — elapsed time, CPU, memory, and setup weight relative to the protection provided.

## Workflow

1. Fix the scope: the exact tests or suites, the behavior they are meant to protect,
   and the source identity (commit plus any dirty diff) the audit describes.
2. Review statically first. Read the tests and the code they target; cite file and line
   for every concern.
3. Optionally run an experiment — a seeded fault, a mutation, repeated runs for
   flakiness, or a timed run — only when all of these hold: the active permission
   profile already allows it; it runs in a disposable isolated copy outside the
   worktree (an exported tree or plain file copy, not a linked worktree, symlink, or
   mount that can write back); it uses controlled fixtures and reaches no real
   service, credential, or production data. If any condition fails, say which one and
   stay with static review. Isolation is not permission.
4. Record each experiment's bounds and results: the exact change or run count, the
   commands, and which tests failed or passed. Confirm afterwards that the actual
   worktree is unchanged, and discard the copy.
5. Report findings and the remediation each one needs, routed to its owner.

## Evidence Classes

Label every finding with one class, and never present a weaker class as a stronger one:

- `static` — directly visible in the test or target code
- `suspicion` — a qualified concern that static reading cannot settle; say what would settle it
- `executed_detection` — an experiment ran and the named tests did or did not detect the seeded fault
- `measured_cost` — measured duration, resource use, or flake rate for stated runs

Report experiment results as the counts actually run, never as a suite-wide score or
mutation percentage extrapolated beyond them. Static review alone never establishes
defect-detection strength.

## Output

- scope, source identity, and whether experiments ran, with the reason when they did not
- findings, each with location, evidence class, evidence, impact, confidence and limitations, and proposed remediation with its owner
- strengths worth keeping, so remediation does not discard working protection
- every in-scope dimension left unassessed, marked explicitly

## Gotchas

- a green suite is not evidence of protection; a surviving mutant is not proof of a missing test until its equivalence is ruled out
- do not grade tests by coverage percentage or line count
- do not edit, quarantine, or skip a flaky test; report it with its evidence
- never run experiments in the actual worktree, even when they would be reverted afterwards
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
