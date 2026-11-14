---
name: technical-change-planning
description: Plans medium or large technical changes, covering design, ownership and task sequencing; produces or maintains an evidence-backed implementation plan. Does not implement.
---

## What I Do

I produce a grounded implementation plan: the owners, boundaries, risks,
acceptance criteria and tasks of a change, before any code changes. The plan is
plain Markdown. It is normally returned in the conversation; it is written to a
file only when it should outlive the session.

## Choose This Skill When

- A medium or large repository change needs a bounded plan before editing.
- Ownership, boundaries or the approach are uncertain.
- A plan file is optional: it is written only when the user asks for one or the work must continue in another session.

## Choose Another Skill When

- Use `feature-planning` when a raw or ambiguous feature request must first become an agreed brief.
- Implement directly when the owner, approach and scope are obvious and fit one session.

## Read Alongside

- `release-safety` for rollout and rollback design.

## Reply Or File

| Situation | Action |
| --- | --- |
| Obvious owner, one approach, one session | Do not plan; implement directly |
| A bounded slice that needs thought, one session | Return the plan in the reply; write no file |
| The user asks, or the work must continue in another session | Return the plan; it is kept in a file |
| More than one credible approach, or ownership is uncertain | Plan first and record the chosen alternative |
| The user asks to keep the plan | Write it to a file (below) |

A ticket is required when any of these holds: the work has two or more
independently deliverable outcomes, each with its own acceptance criteria (a
change and its regression test are one outcome); the work carries consequential
risk: security, migration, data loss or breaking compatibility; meaningful work
remains unfinished, blocked or unverified when the session ends, judged at the
final answer (a question awaited in the same conversation does not end it); or
the work must continue in another session, or the user asks for a ticket.
Duration or the number of files alone never requires a ticket. Local policy may
require one in other cases.

Planning never edits implementation, tests or configuration. Whoever designs
the plan returns it; whoever is asked to keep it writes the file and nothing
else.

Writing or updating a plan file also requires the calling agent's authority.
A read-only designer returns the plan and, when persistence is requested,
hands the finished design to an authorised plan writer. This skill does not
independently grant file-writing authority.

## Where A Plan File Goes

Use the path the user gives, or the location the project's instructions name.
In the work layout Glyphbrace installs (`docs/work/active/`), the plan is
`docs/work/active/<work-id>/plan.md` beside the item's `ticket.md`, and a
superseded approved plan moves to that item's `decisions/` with its date.

Each item's folder, `<work-id>` in these paths, is its id followed by a short
slug, and holds its `ticket.md`. The id is the item's verified tracker id
exactly as its source writes it (`DEV-1234-fix-login`), or the next number in
the project's own scheme when its instructions or existing numbered folders use
one. Only when neither applies, and only for a work record that is actually
being created, take a local id: the highest `T-NNNN` among the folders under
`docs/work/active/` and anywhere under `docs/work/archive/` and the ids in
`docs/work/index.md`, plus one, as four digits (`T-0001` when there is none);
its `ticket.md` records `Source: local`. Never take an id only to name a
branch, and never guess a tracker id. The id and folder stay fixed when the
title changes: change the title and summary in `ticket.md` instead. Existing
folders, slug-only ones included, keep their names. Before the record is
integrated, check that no folder on the branch it joins already uses its id;
parallel branches can take the same number, and the record not yet integrated
moves to the next unused id.

Without that work layout, propose `docs/plans/<slug>.md`, where `<slug>` is a short
lowercase-hyphenated name for the work, and say that you chose it. Do not name
the file after the branch: branches get renamed and contain `/`. Record the
branch inside the plan instead.

One plan per independently executable scope. Keep the path stable while the
work is active. A finished plan moves only with its work item and only when the
project's instructions say so (for example to `docs/work/archive/<yyyy>/<work-id>/`);
update the links that point at it in the same change. Otherwise it stays put.

## Plan Format

```md
# <title>

Status: draft | active | blocked | complete | superseded
Branch: <branch>
Designed against: <commit>
Date: <yyyy-mm-dd>
Superseded by: <path>   (only when superseded)

## Context
## Decision
## Acceptance Criteria
- [ ] AC1: <observable, testable outcome>
## Tasks
- [ ] T1: <one-line observable outcome>
  - Files: <paths, or none>
  - Depends on: <task ids, or none>
  - Covers: <AC ids>
  - Risk: low | medium | high; review before the next task: yes | no
  - Done when: <observable result>
  - Verify: <focused command and expected result>
## Risks And Rollback
## Notes
```

- A plan starts as `draft`. It becomes `active` once work starts and
  `complete` only when every task and criterion is ticked with evidence.
- Task and criterion ids are never renumbered or reused. A dropped task stays
  in the file, struck through, with the date and reason.
- Add sections the work needs (open decisions, a file tree delta, contract
  ownership) rather than forcing every plan into every section.
- Keep each fact in one place: the header or the body, not both.

## Requirements And Criteria

Source every requirement, non-goal and material invariant to the request, a
confirmed amendment or a repository contract, and classify it `explicit`,
`inferred`, `evidence-backed` or `unknown`. Keep confirmed requirements,
necessary technical obligations, open decisions and optional proposals apart;
an unapproved proposal does not become a task.

Acceptance criteria are observable and testable. Every criterion needs a task
whose verification proves it, and every task traces to a criterion or a
necessary technical obligation. A plan with an unresolved decision that blocks
executable work stays `draft`, with the decision under Notes.

## Shaping The Work

- **Vertical slices by default.** Each slice carries one observable behaviour
  through every layer it needs to the check that proves it. A horizontal
  prerequisite is allowed only when a named later task consumes it.
- **Executable from the plan alone.** A fresh agent must be able to do each
  task from its entry: dependencies name only real prerequisites, done is
  observable, and verify fails when the result is missing or broken.
- **Review cadence.** Place review points by the cost of finding a wrong
  decision late: smaller spans cost interruptions, larger spans expose more
  unreviewed work. There is no universal limit.
- **Proof, not motion.** Every behavioural check names the defect or missing
  behaviour it would catch and why it would fail without the change. A test
  that only executes the path, mirrors the implementation or mocks away the
  boundary under test is not proof. Observe behaviour through the highest
  existing caller-visible interface, say what that seam does not prove, and add
  no production interface only for a test.
- **Scoped verification.** Each verify command targets the task's files or the
  smallest behaviour-specific target. List a check that cannot be scoped
  separately as a recommended broad check.
- **Path changes.** For every new, changed, moved or deleted path, list the
  path, the operation, its existing owner, the reason and its verification. Do
  not guess future line counts.
- **Contract ownership.** When a concept has more than one consumer, name its
  authoritative owner and its consumers; no task redefines another owner's
  fields, states or meanings.
- **Release concerns.** For rollout, migration, compatibility or rollback
  design, record exposure, rollback and detection under Risks And Rollback.
  This is planning input, not a release verdict.

## Parallel Work

Tasks that become ready at the same time may run in parallel only when their
files do not overlap and they share no side effect (the git index, a generator,
a lock file, a database, a fixed port).

- Tasks separated by a dependency never run together, so their files may overlap.
- A write scope that is only discovered while the task runs is not provably
  separate: make the tasks sequential.
- Generated output and its source stay with one task.
- Never widen a task's files to make work look parallel.

## Alternatives

When credible alternatives remain, include at most three and score them:
correctness 30, repository fit 20, simplicity 15, testability 15, compatibility
10, operational clarity 10. For a consequential interface, make them materially
different shapes (minimal, common case, extensible), not variants of one
design. Give each its decisive advantage and principal risk, recommend one and
say why the runner-up lost. The chosen option states **Disconfirming
evidence:** (one checkable condition that would make it wrong) and **Revisit
when:** (one observable trigger). With only one responsible design, say why in
one sentence and skip the alternatives.

Prefer additive changes and one source of truth with generation over
duplicated variants. If docs and code disagree, name the higher source of truth
or mark it `unknown`. Do not add a layer, abstraction or named pattern only
because it is common elsewhere: each component needs an evidence-backed owner,
consumer and acceptance criterion.

## Migration Strategy

| Situation | Strategy |
| --- | --- |
| Public API or many consumers | Parallel change |
| Internal implementation replacement | Branch by abstraction |
| Database or stored-data evolution | Expand, migrate, contract |
| Major legacy capability replacement | Strangler-style plan |
| Large mechanical repository edit | Tested AST or codemod procedure |
| Feature needs preparatory restructuring | A separate structural step first, then the behavioural one |
| Performance is intentionally changing | Not a refactor: profile before and after |

For every temporary construct the strategy introduces (a flag, shim, dual write
or duplicated path), record its owner, removal condition and removal trigger in
the plan.

## Algorithm Design

For every new or materially changed algorithm:

1. State the input bounds, invariants and result conditions.
2. Put the cheapest decisive guards first, and note when work over `N` or `M`
   can be skipped or short-circuited.
3. Check each loop for invariant computation and plausibly expensive repeated
   calls that can safely be hoisted, batched, cached or avoided.
4. Keep correctness and clarity ahead of speculative optimisation; do not call
   a method expensive from its syntax alone.
5. Back a material performance claim with complexity evidence and, when that
   is not enough, a bounded benchmark or profile.

Map a material performance property to an acceptance criterion. Use `unknown`
when the repository does not establish the bound or cost.

## Completion

A task is ticked only when:

1. its done condition holds;
2. its verify command ran and passed;
3. the evidence (command, result, commit) is recorded next to it;
4. generated files and documentation it affects are updated;
5. a task marked for review has passed that review.

Editing files is not completion. Each task's evidence carries its own commit,
so later commits do not invalidate it; re-verify only when the task's files
changed afterwards. Ticked tasks alone do not prove every requested outcome:
check each criterion, and record any deferred outcome with who decided to defer
it.

## Stop Conditions

Stop when a required assumption is disproved, the work would exceed the stated
scope, an unapproved destructive or data-migration change becomes necessary,
uncommitted changes conflict with a task, verification cannot run or fails
without explanation, or a dependency differs materially from the plan. Stop
and ask the user, giving the blocker, the evidence and the smallest next action
that would resume the work. A change to tasks, dependencies or criteria goes
back to whoever designed the plan.

## Gotchas

- Do not implement as part of planning.
- Do not present speculation as confirmed by current code.
- Do not tick a task or criterion when the plan is created.
- Do not create a second plan for work an active plan already covers.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
