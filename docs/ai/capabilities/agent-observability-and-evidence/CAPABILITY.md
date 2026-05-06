# Agent Observability And Evidence Capability

## Purpose

Make agent runs traceable, reviewable, and auditable before relying on optimization claims.

## Trigger When

- a task uses agents, tool loops, or delegated handoffs
- a task can mutate repository or external state
- a summary needs durable evidence beyond prose notes
- recurring failures need consistent classification

## Workflow

1. assign `trace_id`, `session_id`, and `task_id` for the run
2. record actor identity and `delegated_by` when on-behalf-of execution exists
3. record each tool call with tool name, mutation posture, and argument hash
4. record authorization decision for mutating or high-risk actions
5. classify failures using `docs/ai/capabilities/agent-observability-and-evidence/FAILURE_TAXONOMY.md`
6. link runtime evidence to task summaries and follow-up verification

## Read Next

- `EVENT_SCHEMA.md` for structured evidence event fields
- `FAILURE_TAXONOMY.md` for failure classification

## Output Contract

- trace identifiers for the run
- tool-call evidence records
- authorization decisions for mutating actions
- categorized failures and resolution status

## Acceptance Criteria

- risky tasks can be reviewed using durable evidence, not only narrative output
- tool calls can be correlated to actor, task, and outcome
- mutating actions include explicit authorization posture
- failures are classified with a known taxonomy entry
