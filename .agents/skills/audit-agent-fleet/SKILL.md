---
name: audit-agent-fleet
description: Reviews every installed agent individually, then ranks readiness, role overlaps, delegation risks and coverage gaps across the fleet. Not for single-agent review.
---

## What I Do

I list every installed agent, get one per-file review for each, and aggregate the results into a triage-ordered 0-100 report with fix priorities. I own the listing, the progress list and the aggregation; each score comes from a one-file review. I never average a blocker away or invent a missing result.

## Choose This Skill When

- Evaluating every installed agent, not a single file.
- Producing a ranked report with fix priorities across all agents.
- A change touched several agent files, shared skills or instruction files.
- Looking for overlap, delegation cycles and gaps across agents.

## Choose Another Skill When

- Use `agent-definition-review` when scoring one agent definition.

## Read Alongside

- the host's installed agent directory: Claude Code `.claude/agents/*.md`, Codex `.codex/agents/*.toml` (identity is the `name` field), GitHub Copilot `.github/agents/*.agent.md`
- `agent-definition-review` — the per-file rubric

## Steps

1. List the agents installed for each host in use from its agent directory, and confirm each file exists. Record the list before you start; report host differences from the files themselves, not from memory.
2. Get one review per file, one at a time. Delegate it to a per-file reviewer when the host lets you and that reviewer is installed; otherwise review the file yourself with the per-file rubric. Say in the report which files were reviewed which way.
3. Keep a short progress list: agents done and remaining, and for each done file its path, score, readiness and top findings with severity and line references, never the full review text. A review that is missing, is for a different file or lacks a valid 0-100 score is recorded and the file is reviewed again; if it is still invalid, the agent is `unknown`. Never skip a file or reuse another file's score.
4. Order agents for triage: group by readiness in the order `blocked`, `unknown`, `ready-with-fixes`, `ready`, and within a group put the lowest score first (an `unknown` agent has no score and sorts by path). Equal scores in a group sort by installed path, ascending. Use each reviewer's final effective score and readiness exactly as returned: never recompute a score from dimensions or finding counts, and never apply a per-file cap again.
5. For each agent, list up to 3 evidenced strengths and up to 3 actionable weaknesses (never padded), plus P0/P1/P2 fixes.
6. Aggregate. All three results are reported, none stands in for another:
   - **Coverage:** `reviewed N of M agents`, where M is every installed agent from step 1. `unknown` agents stay in M.
   - **Fleet score:** the unweighted mean of the reviewed agents' final scores, rounded down, then capped at 69 once when any agent is `blocked`. `unknown` agents are not scored as 0 or as the mean. The score is `unknown` when no agent was reviewed, and also when the reviews used different scoring methods (for example weighted and unweighted): report each method's set separately instead.
   - **Fleet readiness:** `blocked` if any agent is blocked; otherwise `ready-with-fixes` if any agent is `ready-with-fixes` or `unknown`; otherwise `ready`; `unknown` when no agent was reviewed.
7. Once every file has a result, check across agents: overlapping roles, delegation cycles, next-step advice naming agents that are not installed, and responsibilities nobody covers.

## Output

- `FLEET SCORE: NN/100 | unknown`, `COVERAGE: reviewed N of M agents` and `READINESS: ready | ready-with-fixes | blocked | unknown`
- a triage-ordered table (blocked, unknown, ready-with-fixes, ready; lowest score first within a group) with per-agent score, readiness and finding counts
- per-agent strengths, weaknesses and P0/P1/P2 fix priorities
- patterns across agents and a ranked list of top fixes

## Gotchas

- if a per-file result is missing and cannot be produced, mark that agent `unknown`; never fabricate counts
- the order is a triage order, not a best-to-worst ranking; blocked agents come first
- a fleet with an `unknown` agent is never `ready`, and its coverage line says how many agents the score covers
- review one agent per review; do not batch several files into one
- derive the list from the installed files at run time; do not trust a memorised list
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
