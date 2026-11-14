---
name: contract-boundaries
description: "Guides shared API, package, adapter, data, generated-artifact and CLI changes: identify the contract owner, reuse existing logic and assess consumer impacts."
---

# Contract boundaries — one owner per contract

Keep exactly one owner for each contract, and avoid parallel implementations that
drift apart. Most boundary damage is not a broken build — it is a second copy of
the same logic that slowly disagrees with the first.

## Choose This Skill When

- A change adds or alters an API, package boundary, adapter surface, generated
  artifact, CLI contract, or install path.
- Data ownership, persistence shape, secrets flow, or external integration
  behavior might change.
- A proposal duplicates existing logic instead of extending the current owner.
- A workflow or host surface may need provider-specific rendering.

## Choose Another Skill When

- Use `safe-refactor` for a purely local, behavior-preserving change that keeps
  every call site and generated output identical.
- Use `technical-change-planning` when the boundary change is large enough to need a
  persisted plan first.

## Required Checks

1. Identify the source-of-truth file or owner for the boundary before changing it.
2. Search for adjacent patterns before adding new logic; prefer reuse when
   behavioral or responsibility overlap is substantial. State numeric similarity
   only when a tool measured it, naming the method and scope.
3. Prefer extending the existing owner over creating a parallel path.
4. Keep provider-specific differences in mappings or renderers, never in copied
   policy bodies — author once, project per host.
5. Update the tests, validators, docs, and generated artifacts the boundary feeds.
6. State rollback posture for a medium or high-risk boundary change.

## Interface Quality

When proposing or changing a module interface, state what callers must know
(operations, invariants, errors, side effects) and prefer an interface that hides
real complexity. Apply the deletion test: if removing a layer would simplify the
code without pushing complexity onto callers, do not add or keep it. Name the
callers that change when a rule changes, justify each adapter by a real
variation, an independent owner, a compatibility need, or a test need, and do not
expose internals only for tests. A design heuristic never authorizes crossing an
ownership boundary.

## Boundary Kinds

- **API / package** — the callable contract. Changing a signature, an error shape,
  or a default is a contract change even when nothing fails to compile.
- **Adapter / host surface** — rendered per provider from one canonical source.
  A hand-edit to rendered output is overwritten on the next render and drifts the
  fleet; change the canonical source and re-render.
- **Data** — ownership, persistence shape, secrets flow, fixtures. Ask who is
  allowed to write a field, not merely who reads it.
- **Generated artifacts** — never hand-maintain something a generator owns. If the
  generated output is wrong, the generator or its input is the defect.
- **Tooling / CLI** — flags, exit codes, and output shape are a contract as soon as
  anything scripts against them.

## Output

- the boundary owner, or `unknown`
- affected contracts and source-of-truth files
- the existing pattern to reuse, or why reuse is unsafe here
- required test, validator, doc, and generated-artifact updates
- rollback notes when risk is medium or high

## Gotchas

- "It is only internal" is not a reason to skip the owner check — internal
  contracts drift the same way public ones do.
- If you cannot name the owner, mark it `unknown` and stop rather than assuming
  the boundary is yours to move.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
