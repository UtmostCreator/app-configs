# Authorization And Tool Governance Capability

## Purpose

Define who can use which tools, under what scope, with which approval and audit requirements.

## Trigger When

- a task uses agent tools, hooks, or MCP-style tool surfaces
- a task can mutate repository or external state
- permission boundaries are implied but not explicit
- approval requirements for risky operations need a canonical source

## Workflow

1. classify actors as human, agent, or service identities
2. define on-behalf-of delegation when an agent acts for a user or another agent
3. map each tool to its risk tier using `docs/ai/command-risk-taxonomy.md` (tier 1 = read-only, tier 2 = modification, tier 3 = deletion/recovery), then record allowed scope and deny rules
4. define which actions are approval-required before execution (tier 2 = confirm, tier 3 = explicit approval or deny)
5. define required audit fields for mutating actions and policy decisions
6. route runtime adapters to this capability instead of inventing permissions ad hoc

## Output Contract

- actor and delegation model
- tool scope and deny rules, with tier labels from `docs/ai/command-risk-taxonomy.md`
- approval-required action list (tier 2: confirm; tier 3: explicit approval or deny)
- audit requirements for tool use and policy decisions

## Acceptance Criteria

- mutating tool actions have explicit owner, scope, and approval posture
- tool availability is not treated as permission
- on-behalf-of delegation is documented for agent-executed actions
- high-risk actions (tier 3) require explicit approval before execution
- mixed-risk wrappers are classified by invocation shape, not by script name alone
- read-only-adjacent exceptions are explicitly listed and bounded to known generated directories
