# Evidence-First Execution Capability

## Purpose

Run non-trivial changes with explicit scope control, dirty-worktree protection, and evidence-backed verification.

## When To Use

- source, config, docs, workflow, or policy edits
- diff review with correctness claims
- medium/high risk tasks needing approval boundaries

## When Not To Use

- one-step trivial informational replies
- pure read-only lookups with no change proposal

## Inputs Required

- user objective and boundaries
- current worktree/diff state
- affected paths and contracts
- narrowest verification command

## Execution Protocol

1. classify task mode
2. inspect `git status --short` and relevant `git diff`
3. confirm protected actions and approval posture
4. declare intended scope and smallest change
5. apply minimal patch
6. inspect final diff
7. run focused verification and report evidence

## Stop Conditions

- ownership or contract unclear
- protected action without approval
- scope grows beyond bounded slice
- failing checks unrelated to slice

## Verification Protocol

- choose the smallest relevant proof first
- escalate only if risk requires broader checks
- separate executed checks from recommendations

## Output Contract

- changed files
- verification command(s) and results
- verification status (`verified`, `partially-verified`, `not-verified`, `failed-verification`)
- assumptions and remaining risks

## Related Docs

- `docs/ai/execution-protocol.md`
- `docs/ai/source-of-truth.md`
- `docs/ai/approval-boundaries.md`
- `docs/ai/verification-matrix.md`
