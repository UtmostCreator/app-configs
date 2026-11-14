---
name: change-traceability
description: Use when naming a branch, drafting or auditing a commit, or recording a change's reasoning and evidence; drafts and reviews only, never creates branches or commits.
---

# Change traceability

Preserve **what, why, alternatives, evidence, and revisit conditions** without turning commit history into a book. The user's request or a verified work item sets the scope, a plan organises execution, an accepted decision record governs a design choice, the commit explains the change, and Git, tests, logs or traces supply detailed evidence on demand. Neither a ticket nor a branch is always required.

## Choose This Skill When

- Proposing a ticket ID, branch name, commit message, PR/squash message, or linked decision record.
- Finishing a feature, fix, refactor, test, experiment, migration, or revert whose history must remain understandable.
- Recording a rejected approach or research result even if no production code changed.
- Auditing whether a change's history is sufficient for a future human or agent.

## Choose Another Skill When

- `feature-planning` owns unclear feature requirements and acceptance criteria.
- `technical-change-planning` owns substantial designs and implementation plans.
- `repo-investigation` owns root-cause discovery.
- `bug-reproduction-and-fix` owns defect correction.
- `safe-refactor` owns behavior-preserving restructuring.
- `verify-change` owns execution of proof.
- `review-diff` owns independent patch review.
- `docs-sync` owns documentation synchronization.

## Authority And Evidence Rules

- Resolve relevant repository instructions and the active ticket/plan first. Local conventions override these defaults.
- Draft and review only. This skill never creates tickets, branches, commits, decision files, or PRs, and never grants authority to do so. Whoever the user asks to make such a change performs it outside this skill; a read-only role only reviews.
- Do not bypass pre-commit hooks, CI, approval gates, or generated-file ownership.
- Do not invent ticket existence, root causes, tests, measurements, discarded options, or approval. A diff establishes changed bytes, not intent; a passing test establishes only what that test observed. Mark incomplete or conflicting evidence `unverified`.
- Do not add AI `Co-Authored-By`, `Generated with`, `Claude-Session`, or similar attribution unless explicitly requested and allowed locally. Keep credentials and sensitive trace payloads out of commits and docs.

## Workflow

1. **Find the conventions.** Read the repository's instructions, its existing branch names and the hooks or automation that read them. Local rules override everything below.
2. **Identify the work item, if there is one.** Sources: a verified Jira issue (its real project key), a GitHub or GitLab issue in its own repository, an existing local ticket, or the user's request with no separate id (`direct`). Keep the source apart from the id. An id is optional: never invent one, infer a tracker from an id's shape (a local `RS-MCP-IDENTITY-01` is not a Jira key), or create a ticket only to name a branch. If you cannot look an id up, say it is unverified. Suggest a ticket only when local policy requires one or the work needs tracking (see Ticket, Decision Record Or Plan).
3. **Propose a branch, only when one is needed.** Follow an explicit repository convention, including an id-first one that issue-linking automation depends on (`DEV-5830-fix-go-test-runner`, `42-add-export-command`). Otherwise use `<type>/<short-kebab-description>` (`feat/add-model-selector`), or `<type>/<id>-<description>` with a verified id (`fix/42-restore-config-backup`). Take the type from the intended change, not the ticket type (table below); keep it lowercase ASCII, one scope, normally under 60 characters; check it with `git check-ref-format --branch "<name>"` and against existing branches. Reuse a suitable existing branch rather than renaming it.
4. **Inspect the commit-sized change.** Describe only its staged patch or precisely identified commit. A ticket may contain `test`, `fix` and `docs` commits. A squash describes the final accepted changes, not every intermediate experiment.
5. **Choose depth.** Minimal: trivial formatting or generated refresh. Standard: meaningful code/test/docs change. Extended: significant defect, feature, security/architecture decision, performance measurement, spike, or revert. Write only applicable details; important rejected options go in a linked decision record, not every commit.
6. **Validate the draft.** Ensure the subject matches the patch, references point to real records, verification claims name actual outcomes, breaking changes are explicit, and incomplete work is not claimed complete. Return missing evidence instead of making it up.

## Ticket, Decision Record Or Plan

Decide each independently, reusing existing records before proposing new ones:

- **Ticket:** A ticket is required when any of these holds: the work has two or
  more independently deliverable outcomes, each with its own acceptance criteria
  (a change and its regression test are one outcome); the work carries
  consequential risk: security, migration, data loss or breaking compatibility;
  meaningful work remains unfinished, blocked or unverified when the session
  ends, judged at the final answer (a question awaited in the same conversation
  does not end it); or the work must continue in another session, or the user
  asks for a ticket. Duration or the number of files alone never requires a
  ticket. Local policy may require one in other cases. Trivial maintenance may
  need only a commit where local policy allows it.
- **Decision record:** a choice affects architecture, a public contract,
  security, ownership or compatibility, would be costly to reverse, and weighed
  credible alternatives, and no binding record already covers it. Complexity,
  file count or the need for a plan alone is not a reason.
- **Plan:** A plan file is optional: it is written only when the user asks for
  one or the work must continue in another session. A plan never approves a
  design; it links the governing record.

A work record's folder name follows the work-record convention in the project's
work README (a verified tracker id, the project's own scheme, or a local
`T-NNNN`); this skill never takes an id only to name a branch.

A proposed record does not authorise implementation that depends on it. Never
fabricate an ID, approval or existing record.

## Ticket Type → Branch Intent

This is a fallback for branch naming, **not** a rule that the commit type must equal the ticket type.

| Ticket type | Default branch prefix |
| --- | --- |
| `task`, `subtask` | actual intent (`feat`, `fix`, `test`, etc.) |
| `bug` | `fix` |
| `spike` | `docs` research; `test` experiment |
| `story` | usually `feat` |
| `feature` | `feat` |
| `epic` | child-ticket intent; implement through child tickets, no epic-wide branch |
| `test`, `docs`, `style`, `refactor`, `perf`, `build`, `ci`, `chore`, `revert` | the same type |
| `repo` | `repo` if locally supported |

## Universal Commit Contract

Use an imperative Conventional Commit subject, ordinarily at most 72 characters; `scope` is optional and refers to the affected domain. Choose the **commit** type from actual changed behaviour, regardless of ticket type.

```text
<type>(<scope>): <what this commit changes>

Why: <problem, need or confirmed limitation>
Change: <essential solution and why this approach>
Verified: <exact check and observed result, or Not run: reason>

Refs: <verified work-item ID>
Decision: <existing decision ID, if relevant>
```

Add `Refs:` only for a verified work item; with none, omit it unless local policy requires it. Add a decision trailer only when the commit implements or changes that decision, using the trailer the repository defines (for example `ADR: ADR-0001`); `Decision:` applies only when it defines none. Never use an issue-closing keyword (`Closes #42`) unless closing that issue is intended and the work is complete.

Minimal commits may omit the body when the change is self-explanatory and local policy permits it. In extended messages, add type-specific context below. Use `BREAKING CHANGE: <impact and migration>` for a breaking contract. An actual revert retains `This reverts commit <full-sha>.` Do not insert exception or approval trailers unless justified by the governing process. Never commit unresolved `<placeholders>`.

## Type-Specific Commit Prompts

The right column is an **additional question**, not a mandatory literal heading.

| Commit type | Essential additional context |
| --- | --- |
| `feat` | User-visible behaviour, accepted scope, compatibility and important alternatives |
| `fix` | Symptom, reproduction, confirmed cause, regression protection |
| `docs` | What was unclear or wrong; authoritative reference |
| `style` | Mechanical formatting boundary; no intended behaviour change |
| `refactor` | Structural problem, invariants preserved, equivalence proof |
| `perf` | Before/after numbers, environment, measurement method, trade-off |
| `test` | Missing proof, distinguishing assertion, run result |
| `build` | Toolchain/dependency cause, compatibility/reproducibility |
| `ci` | Previously unprotected failure and observed pipeline result |
| `chore` | Maintenance trigger, mechanical scope, unexpected drift |
| `revert` | Reverted SHA, reason, restored behaviour and checks |
| `repo` | Governance issue, affected workflow, real enforcement boundary |

`epic` commits relate to a child scope, not epic completion. A `spike` records the research question, options, observed result, uncertainty and revisit trigger (usually as `docs(research)`, even if no code ships).

## Worked Example

**Rejected spike** — do not disguise research as a shipped feature:

```text
docs(research): retain one owner for Git history enumeration

Question: Would a second Python history engine improve analysis?
Considered: Shared scope engine versus separate Python engine.
Outcome: Retain shared scope; two enumerators risk divergent sets.
Evidence: <exact probe and archive ref>
Revisit: If a measured requirement defeats the shared model.

Refs: <existing spike ID>
Decision: <existing decision ID, if any>
```

## Durable Decisions: One Page, Not A Book

For consequential alternatives, a rejected attempt, or a durable constraint, reuse the repository's authoritative decision or investigation location. A choice between alternatives earns a record only when reversing it would be costly, a future maintainer would question it without its context, and real alternatives were weighed; otherwise the ticket or commit carries the reason. Record only:

- **Question and decision**, including status (`proposed`, `accepted`, `rejected`, `superseded`, `withdrawn`) and decision date.
- **Actually considered alternatives** and concrete reasons for rejection or selection. Unknown or uninvestigated is not rejected.
- **Evidence**: full Git SHAs, reproduction/tests with outcomes, tool versions, trace or experiment references when relevant; identify missing/unavailable evidence.
- **Consequences and limitations**, including compatibility/security implications.
- **Revisit condition** and superseding record when the decision changes; do not silently rewrite rejected history.

Where the repository names the authority for a decision's id, status, dates and supersession (a machine-readable index, or each record's own metadata), only that authority states them: reference the decision by its id, start a new record from the repository's template, and never state a status the authority does not. Without such an authority, do not create one as a side effect. Do not duplicate a transcript, re-copy ticket text, invent a new docs root, or modify generated documentation directly. Published commits stay immutable; improve their explanation with a later reviewed, linked record.

## Output

For a draft, return `work_item` (source: jira, github, gitlab, local or direct; the id or none; verified, unverified or not applicable), `branch` suggestion, existing branch or not needed, `commit_message`, optional `decision_record` link, and any `missing_evidence` or `unverified` claims. For a review, return findings and a corrected draft, **without writing**. State explicitly what was proposed versus actually performed.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
