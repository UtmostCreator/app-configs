---
name: safe-refactor
description: Use when restructuring code without changing its observable behavior; require a relevant test baseline first, make the structural edit, and prove behavioral equivalence.
---

## What I Do

I change internal structure without changing declared observable behavior, to reduce the cost of the next change. I record before-change evidence, make structure-only edits, prove equivalent after-change evidence stays green, and confirm the intended structural problem actually improved.

**Two Hats.** At any moment exactly one hat is on: `structure` or `behavior`. Under the structure hat no observable behavior may change and no test may be rewritten to agree with a changed behavior. If a requested or discovered change intentionally alters behavior, stop the structural wave, record it, and route the behavioral work separately. Structural and behavioral work must stay distinguishable in the plan, the diff, the evidence, and the report.

**Atomic techniques** — the only catalogue I carry: rename; extract / inline; move; split phase; encapsulate; simplify control flow; isolate side effects; make state explicit; invert dependency; consolidate duplication; remove proven-dead transition code.

## When To Use Me

- when only structure, naming, or duplication needs work and no defect is reported or suspected in the behavior being preserved
- before a review that must confirm behavior is unchanged
- when consolidating near-duplicate logic into a single source of truth
- when a smell is bounded to named files and no public contract should move

My direct-execution band is L4-L6 — class or component (L4), function or method (L5), statement, expression, or variable (L6) — inside one already-established boundary, with no escalation trigger present. L0-L3 (system or project, architecture, subsystem or capability, module or package) is architect territory: hand off instead of executing.

## Choose Another Skill When

- Use `bug-reproduction-and-fix` when observation reveals a reported or suspected defect: stop the structural pass, report the evidence, and route the fix there. Fixing a defect is behavior-hat work and never happens inside a refactor.

## Observable Behavior

Fifteen dimensions, in this order: return values; errors and exceptions; side effects; output ordering; public API shape; serialization format; database writes and stored-data shape; transaction boundaries; events and queued messages; authorization decisions; retries and idempotency; concurrency and ordering guarantees; CLI exit codes; logs, metrics, and trace fields used operationally; compatibility with older workers or deployments.

Name the dimensions in scope before editing; never claim equivalence for a dimension that was not observed; report unobserved dimensions explicitly as unverified rather than asserting equivalence.

## Escalate Instead

Stop and hand back to the architect when the work touches any of these triggers: public APIs or independently deployed consumers; database schemas or stored data; events or queue payloads; externally consumed serialization; framework or major dependency replacement; cross-module, service, or ownership boundaries; security or authorization policy; concurrency semantics; mixed-version deployment; behavior that cannot be observed safely.

A trigger forces architect involvement at ANY level, including L6. Escalation is a stop, not a widening: hand back rather than expanding a local refactor into architectural work on your own authority, and never stretch this skill to cover a trigger.

## Read Alongside

- `verify-change` — the mandatory test gate for a behavior-preserving change
- `review-diff` — read its criteria to self-check the patch; independent review belongs to a separate reviewer, not to the author
- `docs-sync` — when the refactor moves documented paths
- `characterization-testing` — when the target behavior has no relevant baseline yet
- the refactoring contract — the normative source where the kit documentation surface is installed; this skill carries the compact operative form either way

## Steps

1. Confirm no defect is reported or suspected in the behavior being preserved — a baseline records what the code does now, not that it is correct — then declare the scope contract: allowed paths, prohibited paths, affected surfaces, the bounded completion condition, the active hat, the observable-behavior dimensions that must not change, and the concrete structural problem the change must improve.
2. Identify the tests that actually exercise that behavior and run them first to record a baseline — exact commands and flags, pass/fail/error/skip counts, and any pre-existing failures. Review new or changed tests against repository conventions and current testing best practices, and prove their assertions detect the behavior at risk rather than merely execute code. No relevant behavioral evidence, no structural edit. If the target code is uncovered or legacy with no usable baseline, route to `characterization-testing` to build one, then return here. Admit the structural edit only for dimensions that baseline evidences on the original code; when a seam was prepared, passing post-seam tests are not admission — stop while material seam equivalence for an affected dimension remains unverified.
3. Before adding logic that resembles logic the repository already has, identify the closest existing implementation and prefer reuse, replacement, parameterization, or consolidation over a near-duplicate. Judge overlap by behavior and responsibility, not by text similarity, and never state a numeric overlap score unless a tool measured it.
4. Make one conceptual structure-only change; keep mechanical moves (rename, extract, reorder) in separate passes from any semantic edit. Do not add features, change public contracts, or edit generated/lock/secret files.
5. Re-run the same commands over equivalent scope and compare against the baseline: no new failures, no unexplained change to a pre-existing failure, no weakened assertion. For any large or potentially performance-impacting new test, profile bounded inputs with suitable tooling, record elapsed time, CPU use, and peak memory, and reduce or split the test when its cost is not justified by the behavioral evidence. Fix or revert within scope until it passes.
6. Confirm the intended structural improvement is real and visible in the diff — duplication removed, responsibility localized, dependency direction corrected, public surface narrowed, change fan-out reduced, or side effects isolated.
7. Report the goal, the behavior-preservation boundary, the reuse check, the before/after evidence, and every dimension left unverified, then hand off.

## Output

- the active hat and the scope contract: allowed paths, prohibited paths, affected surfaces, completion condition
- the behavior-preservation boundary — which of the fifteen dimensions were in scope
- structure changed and behavior confirmed unchanged
- the reuse/duplication check (what was searched, reused, and why any new code was needed)
- before and after commands with pass/fail/error/skip counts, and any pre-existing failure that stayed unchanged
- the baseline's origin — existing tests or a characterization baseline — and any seam-equivalence gap that limited admission
- the structural improvement achieved, stated as a concrete claim the diff supports
- any behavior dimension you could not verify, marked explicitly as unverified rather than asserted equivalent
- required follow-up or escalation

## Gotchas

- never claim green without an executed run
- equal pass counts do not prove that equivalent relevant tests ran
- tests must use isolated fakes, fixtures, containers, or dedicated test stores; never connect directly to a real database or read real user, production, or environment data unless the user explicitly instructs it
- do not add a wrapper or layer that hides no complexity from its callers; if deleting it would simplify the code, do not add it
- preserve file history where the tooling supports it; never delete and recreate a file to bypass deletion controls, ownership rules, or review visibility
- do not delete files without explicit approval
- do not weaken tests to make a change fit
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
