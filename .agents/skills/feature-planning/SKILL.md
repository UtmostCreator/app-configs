---
name: feature-planning
description: Clarifies feature goals, scope and acceptance criteria; confirms parent tasks before expanding the implementation plan. Defers unresolved technical design.
---

## What I Do

I turn an initial feature request into a clear, agreed feature brief and then a
staged implementation plan.

## Choose This Skill When

- A feature request's goals, scope, constraints or acceptance criteria are incomplete or ambiguous.
- A complex, multi-project or multi-phase feature must be divided into verifiable tasks with agreed priorities and boundaries before detailed planning.

## Choose Another Skill When

- Use `clarification` when resolving ambiguity is the only required outcome.
- Use `technical-change-planning` when requirements and scope are already agreed and a technical plan is needed.
- Implement directly when the requirements, ownership, approach and scope are clear enough for a bounded change.

## Workflow

1. **Clarify requirements.** Ask about unresolved requirements, acceptance
   criteria, scope, or security and schema implications when they materially
   affect the outcome. Otherwise record reasonable assumptions explicitly.

2. **Establish boundaries.** Identify affected projects, components,
   dependencies, constraints and exclusions. Separate genuinely independent
   projects into distinct briefs without splitting related work.

3. **Define the feature.** Write a concise brief with:
   - the problem and intended outcome;
   - goals and success criteria;
   - in-scope and explicitly out-of-scope work;
   - constraints and dependencies;
   - initial, observable acceptance criteria.

   Keep requirements specific, testable and about outcomes, not implementation.

   For a material business rule, state the behaviour from the affected actor's
   view with its normal and most consequential exceptional path, use a concrete
   counterexample to expose an ambiguous rule, and check whether the behaviour
   already exists before planning work for it: cite the code or the gap.

   Give each requirement, non-goal and material invariant its source: the
   original request, a confirmed amendment or a repository contract. Classify
   each `explicit`, `inferred`, `evidence-backed` or `unknown`. Keep confirmed
   requirements, necessary technical obligations, open decisions and optional
   proposals apart; an optional improvement is not an approved requirement.

4. **Assess architectural implications.** When ownership, system boundaries,
   dependencies or technical risk need architectural decisions, record them as
   open decisions for a technical design rather than deciding here, and do not
   widen the architectural scope yourself.

5. **Outline the parent tasks.** Break the agreed scope into concise,
   prioritised P0/P1/P2 parent tasks, each a coherent unit with a clear
   outcome. Note dependencies and ordering constraints.

6. **Confirm the outline.** Present the parent tasks for explicit user
   confirmation. Stop before expanding subtasks or writing the full plan.
   Apply requested corrections and confirm the revised outline. An approval of
   this same outline already given counts; do not ask again.

   When the effort is too uncertain to plan, record instead its destination,
   the confirmed decisions, the open questions that block the next planning
   decision, and what is not yet specific enough to ask. Resolve only the
   blocking questions and plan none of the unknown work.

7. **Develop the implementation plan.** Once the parent tasks are confirmed,
   expand them into actionable tasks, each with its files, dependencies,
   covered acceptance criteria, done condition and verify command, keeping the
   agreed scope, priorities and acceptance criteria. Map
   every acceptance criterion to at least one task whose verification
   demonstrates it, and every task to an accepted outcome or a necessary
   technical obligation. Unapproved proposals stay out of the tasks. Return the
   plan. A plan file is optional: it is written only when the user asks for one
   or the work must continue in another session.

A ticket is required when any of these holds: the work has two or more
independently deliverable outcomes, each with its own acceptance criteria (a
change and its regression test are one outcome); the work carries consequential
risk: security, migration, data loss or breaking compatibility; meaningful work
remains unfinished, blocked or unverified when the session ends, judged at the
final answer (a question awaited in the same conversation does not end it); or
the work must continue in another session, or the user asks for a ticket.
Duration or the number of files alone never requires a ticket. Local policy may
require one in other cases.

## Read Alongside

- `clarification` — resolve material ambiguity without unnecessary questions.
- `technical-change-planning` — the plan format and the detailed technical planning.

## Output

Before confirmation:

- a concise feature brief with goals, scope, constraints and acceptance criteria;
- a prioritised P0/P1/P2 parent-task outline;
- material assumptions, dependencies, risks and open decisions;
- an explicit confirmation checkpoint.

After confirmation:

- an implementation plan with actionable tasks;
- traceability from confirmed requirements to tasks and acceptance criteria;
- a clear next step.

## Gotchas

- Do not expand subtasks or finalise the plan before the parent tasks are confirmed.
- Do not confuse requirements definition with technical design.
- Do not add implementation details or scope beyond what was agreed.
- Do not treat assumptions, proposed tasks or unconfirmed decisions as approved requirements.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
