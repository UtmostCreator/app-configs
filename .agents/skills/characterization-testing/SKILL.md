---
name: characterization-testing
description: Use when existing behavior of uncovered or legacy code must be recorded as a scoped, reproducible baseline before a structural, dependency, or configuration change, without deciding it is correct.
---

## What I Do

I record what existing code observably does today, so a later change can be judged
against evidence instead of belief. A characterization baseline describes current
behavior; it never establishes that the behavior is correct, and I never fix what I
observe. I produce the baseline, its provenance, and its gaps; the caller decides
what to do with it.

## Choose This Skill When

- Legacy or uncovered code (no relevant test exercises it) must be pinned before a structural, dependency, or configuration change.
- No defect is reported; the goal is to capture what the code does now.

## Choose Another Skill When

- Use `bug-reproduction-and-fix` when a defect is reported or confirmed; its `reproduce_only` mode proves a reported defect without fixing it.
- Use `safe-refactor` once an admitted baseline exists and the restructuring itself can begin.
- Use `repo-investigation` when an observed problem needs diagnosis before anything is pinned.

## Read Alongside

- `verify-change` — the owner of verification states and evidence semantics; the baseline reuses its `pass`, `fail`, `blocked`, `not_applicable`, and `unverified` states

## Workflow

1. Declare the observation scope: target paths, the proposed change the baseline must
   support, and which observable dimensions are in scope — return values, errors,
   side effects, output ordering, public API shape, serialization, stored data,
   transactions, events, authorization decisions, retries, concurrency, exit codes,
   operational logs or metrics, and compatibility. Unlisted dimensions stay unverified.
2. Choose the observation boundary: a pinch point — the narrowest existing call
   site, command, or interface that exposes the in-scope dimensions. Name every side
   effect crossing it.
3. Control nondeterminism that affects the result: time, randomness, environment,
   ordering, external services, and shared state. Use isolated fakes, fixtures,
   containers, or dedicated test stores; never real production data or services
   unless the user explicitly instructs it.
4. Prefer a non-invasive seam: a test through an existing interface, a recorded
   input/output pair, or an approval/golden file. Production seam or harness
   preparation is allowed only when it is explicitly authorized and necessary for
   observation; it may not restructure the target, change contracts, or fix defects.
5. Write the smallest characterization tests that pin current results, including
   surprising ones. Assert observed values; do not assert what the code should do.
6. Run them and bind the evidence: commit, actual source identity (clean commit or
   the dirty diff or content digest), exact commands and flags, environment, and
   pass/fail/error/skip counts.
7. Apply the seam-equivalence gate below, annotate each result, and hand off.

## Seam-Equivalence Gate

Keep observations made on the original code separate from observations made after
seam preparation. A seam that alters an in-scope dimension characterizes new code,
not the original. For each seam record what changed, the equivalence method (for
example the same test run before and after the seam, a byte-identical recorded
output, or a review that the seam is a pure pass-through), its evidence, and every
affected dimension it leaves unverified.

Passing post-seam tests alone never establish the original behavior. When material
equivalence for a dimension the proposed change relies on is unverified, report the
baseline as partial and state that it does not admit restructuring. The gate is
scoped to the affected dimensions and the proposed change, not every conceivable property.

## Annotations

Label each pinned behavior `observed`, plus any that apply: `expected` (matches a
cited requirement), `suspect` (looks wrong; route it, do not fix it), or
`unobserved` (in scope but not captured). Annotations describe the baseline; they
are not competing verification states.

## Escalate Instead

Stop and hand back when observation itself needs a public API, stored-data, event,
serialization, cross-boundary, security, authorization, or concurrency change, or when
behavior cannot be observed safely. Seam preparation never widens into architecture.

## Output

- the observation scope, boundary, side effects, and controlled nondeterminism
- source identity, commands, environment, and counts for every run
- original and post-seam observations listed separately, with seam changes and equivalence evidence
- annotations per pinned behavior, and every in-scope dimension left unverified
- whether the baseline admits the proposed change, is partial, or is blocked, with reasons
- suspect behavior routed to its owner rather than corrected

## Gotchas

- do not rewrite a characterization test to match a later behavior change; switch hats instead
- do not treat unrelated passing suites or equal pass counts as a baseline
- do not snapshot volatile values (timestamps, random IDs, absolute paths) without controlling them
- do not delete or weaken existing tests while adding characterization tests
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
