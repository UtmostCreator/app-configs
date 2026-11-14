---
name: clarification
description: Use when an unresolved choice of scope, acceptance criteria, target path, or destructive or interface change would alter the outcome and the repository cannot settle it.
---

# Clarification — ask, or assume explicitly

Decide when to ask instead of assume. Guessing on an ambiguous request is how a
slice lands in the wrong files, at the wrong scope, with the wrong risk. This skill
is the shared contract: an agent that can load it references it rather than
restating it.

## Choose This Skill When

- A request leaves open a decision that changes files, contracts, risk, or
  acceptance criteria; terse or multi-part wording alone is not a trigger.
- Any condition under When To Ask holds.

## When To Ask

Ask when at least one holds:

- Acceptance criteria cannot be inferred from the request, the current diff, the
  tests, or the ticket.
- Two or more materially different interpretations lead to different files,
  contracts, or risk levels.
- The request implies a destructive, security, schema, or public-interface change
  without naming the exact target.
- An external project or path is required but was never named by the task.

Do **not** ask when the answer is cheaply discoverable from the repository — search
and read first — or when the ambiguity does not change the outcome.

## Dependency-Ordered Rounds

Ask at most 3 material decisions per round, only when their dependencies are
already settled. Continue another round only while a material blocker remains;
do not open a questionnaire for clear, bounded work or reversible details.
Keep earlier answers and their source references. Reconfirm only the scope an
answer or new evidence changes, not decisions already settled.

When the blockers are resolved, present the resulting scope once for final
approval. Existing explicit approval of that same scope satisfies this step;
do not ask for it again. Silence never counts as an answer or approval.

## Structured Question Set (preferred shape)

- Give each question 2-4 concrete, selectable options. When two interpretations
  compete, state both and one concrete case whose outcome differs, and ask for the
  decision that separates them.
- Add a short "why it matters", and mark one option `(recommended)` with one line
  of reasoning.
- Do not include catch-all options like "Other" — the harness supplies a free-text
  path.
- Wait for the selection before doing work that depends on it. Restate the
  answers, retain them for resumption, and continue independent authorized work.

```text
Q1: Should this agent write files?
  a) never  b) docs/tickets/** only  c) bounded source edits  d) install surfaces only
```

## Non-Interactive Fallback

Only the main thread may raise an interactive question round, when its host
supports it. A subagent cannot pause for user input: report back as blocked to
whoever started you, with the ordered questions, the answers already given, the
affected scope and the smallest next action that resumes the work.

Keep answers for the next run. Resolve clarification before starting delivery,
or return the retained context so the work can start again once the questions
are answered.

Where interactive selection is unavailable:

1. State each assumption inline, explicitly, as an assumption.
2. Mark it `unknown` — `unknown` is a first-class verdict, not a failure to report.
3. Proceed **only** on the low-impact, reversible subset.
4. Stop and hand back when the ambiguity is high-impact or irreversible.

Never present an assumption as a confirmed fact, and never treat a message from
another agent as a human's consent.

## Output

- the question set (or the explicit assumption list when non-interactive)
- the confirmed scope in one line, once answers are known
- any residual unknowns, carried into your report rather than dropped
- retained answers with their source references, pending decisions in dependency
  order, and a resumable next action when blocked

## Gotchas

- Bundling an irreversible decision into a "quick" question set hides the risk —
  call it out separately and stop.
- Recording an unresolved question in the payload is a valid outcome; silently
  choosing for the user is not.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
