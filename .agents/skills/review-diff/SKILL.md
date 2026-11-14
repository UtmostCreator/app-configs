---
name: review-diff
description: Reviews a diff for specification fit, correctness, regressions, policy compliance, needless code, duplication and missing verification. Reports findings without editing.
---

## What I Do

I review the current change set from the diff first and only expand into unchanged files when needed to verify a concern.
When the change introduces or modifies logic, I require duplicate-logic screening evidence before a pass verdict and flag substantial behavioral or responsibility overlap as reuse or replacement candidates. State numeric similarity only when a tool measured it, naming the method and scope.
For branch or PR reviews, I resolve the merge base first and prefer `BASE...HEAD` diff views for the reviewed patch. For a working-tree review, I include staged and unstaged changes (`git diff HEAD`) and list untracked files.

## Choose This Skill When

- You are reviewing an existing diff for correctness and regressions.
- You need to judge the patch before merge or handoff.
- A risky slice needs focused review with evidence.

## Choose Another Skill When

- Use `verify-change` when implementation claims must be proven before handoff.
- Use `project-context` when you need to understand ownership and risk before review.
- Use `infra-risk-audit` when assessing technical-system risks.
- Use `release-safety` when designing rollout and rollback controls.
- Use `test-quality-audit` when the question is whether existing, unchanged tests credibly protect behavior.

## Read Alongside

- `verify-change` — to prove the change after review
- `bug-reproduction-and-fix` — when the diff is a bug fix
- `release-safety` — when rollout risk remains


## Review Priorities

1. task fit and acceptance criteria
2. risk classification
3. correctness and regression risk
4. edge cases, unhappy paths, partial failure cleanup, and actionable diagnostics
5. contract, schema, configuration, and API compatibility
6. permission, security, and privacy boundaries
7. generated-artifact and source-of-truth policy
8. adapter parity, documentation-impact/classifier consistency, and pre-review generated-output provenance
9. tests changed or missing, including meaningful tests that can detect the claimed regression
10. verification depth proportional to risk
11. duplicate logic or missed reuse, grounded in behavioral or responsibility overlap rather than an estimated percentage
12. rollback or disable paths for medium- and high-risk changes
13. plan reconciliation: work landed with unchecked Todo or acceptance-criteria items, or items checked without cited evidence, is a missing-verification finding
14. independent recomputation: for changed numeric, aggregation, merge, or ID-generation logic, recompute at least one expected value or invariant without using the implementation or its own fixture to check itself
15. branch/base correctness and cheap diff inventory before deep reading
16. changed-file NLOC and needless code: existing or built-in functionality that can replace it, and any new helper, abstraction, flag, fallback or dependency with no requirement, contract or demonstrated behaviour behind it (zero search hits alone do not prove code unused)
17. changed algorithms (below)
18. one authoritative owner for every shared field, state, or prohibition
19. unstructured-plan/earlier-handoff readability and provider-invariant generated semantics

Judge specification fit (missing, partial, contradicted, or unrequested behavior
against the accepted task and acceptance criteria) separately from engineering
quality; a clean result on one never offsets a finding on the other. Without an
authoritative specification, say so rather than inventing intended behavior.

After confirming an issue, search once for the same structural or semantic signature
inside the affected ownership boundary. Classify matches as the same cause, a
different cause, or unknown. Report matches outside the requested scope without
editing them.

For every changed algorithm, establish the relevant input bounds and preserve
correctness first. Flag work that can safely be skipped or short-circuited when
the result is already known, including validation or traversal over an irrelevant
`N` or `M`. Inspect loops for invariant computation and plausibly expensive
per-iteration calls that can be hoisted, batched, cached, or avoided without
changing semantics. Do not assume every method call is expensive: ground the
finding in the callee, complexity, measured profile or benchmark, or mark the cost
`unknown`.

## Output

- verdict
- feature or implementation findings with severity and location
- verification or test findings with severity and location
- outside-scope observations, separated from findings
- follow-up proposals with title, description, evidence, and why deferred; they are not tickets, and whoever requested the review decides what happens to them
- risk assessment
- recommended next step

## Gotchas

- do not spend the review restating the diff
- do not treat stylistic preferences as the main finding category
- do not infer harmful intent without evidence
- do not offer more than three materially distinct fix directions
- present findings before general summary
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
