---
name: human-handoff
description: Prepares evidence-backed steps when a check or operation needs a person, access or approval. Defines expected results and feedback; grants no authorisation.
---

# Human Handoff

Turn a real human dependency into steps a person can follow exactly, then
continue from what they report. A handoff never grants permission and never
counts as the check itself.

## Choose This Skill When

- A required check needs an account, device, environment or service you cannot
  reach, and no authorised automated check can replace it.
- A command needs access or approval you lack: a database query, a console or
  production command, a deployment step.
- An operation is destructive or hard to reverse: deleting files or data, a
  migration, a schema or permission change.
- Only a person's observation can tell the remaining hypotheses apart.

Not when automated checks were not tried, the code was not investigated, a tool
is merely inconvenient, or the work is still within your own authority. Never
invent a human dependency.

## Choose Another Skill When

- Use `clarification` when the open item is a decision about scope, behaviour
  or acceptance rather than an action.

## Read Alongside

- `verify-change` — its criterion states record each check before and after the
  person reports.
- `verify-ui-change` — for a user-interface journey, its journey contract
  defines the steps; this skill only hands them over.
- `project-context` — ownership, environments and the documented commands.

## Before You Hand Off

1. Establish what is done and what is proven: the change, each check that ran
   with its scope and result, and the criteria still `blocked` or `unverified`.
2. Find the exact code, configuration and entry point involved, and the
   commands the repository documents (instructions, scripts, CI). Record paths,
   symbols and the revision.
3. Say why a person is needed: what you tried, what you cannot reach, and
   whether the gap blocks completion or only limits confidence.

Never invent a path, command, query, table, screen, expected value or account.
When something cannot be established, say so and ask for the smallest missing
fact instead.

## Each Action

Number actions `H-1`, `H-2`, … and give each:

- **Who and why:** the role that can do it (an operator, the database owner,
  the release owner), and whether it blocks completion.
- **Prerequisites:** environment, access, revision and starting state. State
  shared prerequisites once.
- **Steps:** where to run each one and the exact command, query or UI action,
  marked read-only or state-changing.
- **Expected result,** what counts as a failure and what is inconclusive, with
  the source that makes it expected (a criterion, a test, the code).
- **Stop when:** the conditions that end the procedure, and whether a rerun is
  safe.
- **Send back:** the smallest evidence that settles it: the command, its exit
  status, a redacted excerpt, observed against expected, the environment and
  revision. Ask for a screenshot only when the visual state is the question.

Order actions by safety, then by what they reveal. Make later steps depend on
earlier results instead of asking for everything at once, and do not ask for a
check an automated one already proves.

## Destructive Or State-Changing Operations

A handoff is not permission, and a read never turns into a change on its own.

1. Establish the exact target, environment and current state with read-only
   checks first: a count, a bounded query, a dry run, a listing.
2. Describe the operation, what it changes and its risks.
3. Name the backup or recovery path and how to confirm it applies here; say
   plainly when something cannot be undone.
4. Ask for explicit approval from whoever owns the system.
5. Give the exact operation only once its target, scope and prerequisites are
   established, scoped as narrowly as the tool allows (a transaction, a
   filter, one environment).
6. Give the check that proves it worked, and the rollback with its limits.

Never ask for secrets, credentials, full dumps or unrestricted logs, and never
ask someone to disable a security control to make a check pass.

## After The Person Reports

- Record what they observed, against which revision and environment, as
  evidence for the criterion, and set its state from that evidence rather than
  from their conclusion.
- An unexpected or inconclusive result goes back to investigation or to the
  change owner; do not patch speculatively.
- A person running a check is not a waiver, and a waiver is not a pass. Record
  each as what it is.
- Until the evidence arrives the criterion stays `blocked` or `unverified`, and
  nothing that depends on it is reported done, passed or accepted.

## Report

A short block the person can follow without the rest of the conversation:
implementation and verification state (separately), why a person is needed,
the actions, and what happens once they report. Omit empty parts.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
