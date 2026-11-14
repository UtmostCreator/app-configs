---
name: agent-definition-review
description: Use when reviewing one agent definition for internal coherence, role and tool fit, next-step advice and token efficiency; return a 0–100 score with exact fixes.
---

## What I Do

I score ONE agent definition file 0-100 against a fixed weighted rubric and return evidence-backed findings with exact minimal fixes, a readiness state and a proposed decision. One file per run, never every agent at once. Repository evidence is the authority, not preference: tie every dimension score and finding to its rubric dimension and the quoted evidence that justifies it. Only the weighted total is computed; each dimension score is a judgement, so a re-run on the same file and repository state may score differently. Make any difference traceable to cited evidence, and never claim a measured reproducibility or reviewer agreement that no run has established.

## Choose This Skill When

- Reviewing one agent definition for internal coherence, role and tool fit, next-step advice and token efficiency.
- Checking whether a new or changed agent definition is ready to use.
- Another agent or the user asks for an independent score of one file.

## Choose Another Skill When

- Use `check-agent-request-fit` when comparing a valid definition with the original user request; this review judges consistency with the definition's own declared mission.
- Use `audit-agent-fleet` when evaluating every installed agent together.
- Use `workflow-drift-audit` when auditing instruction files for drift.

## Read Alongside

- the one agent file under review
- the host's installed agent directory, to list the agents that actually exist (Host Formats below)
- the host's or the project's permission settings, when the review judges tool fit
- the target repository's declared agent format or validator, when present

## Steps

1. Classify the target's role (researcher / architect / implementer / reviewer / auditor / factory) so a generic bar does not over-penalise valid role differences.
2. Judge the front matter against the host's own agent format (Host Formats below), or the format the target repository declares.
3. Score each dimension and show the arithmetic (`total = Σ(score × weight) / 100`); penalise one root cause in its highest-weight dimension only, never twice.

   | Dimension | Weight |
   |---|---:|
   | Front matter and host-format fit | 15 |
   | Role scope and mission fit | 15 |
   | Tool and permission fit | 20 |
   | Instruction correctness and contradictions | 15 |
   | Next-step advice and failure routing | 10 |
   | Evidence, validation and output testability | 10 |
   | Brevity, duplication and token economy | 10 |
   | Runtime safety and enforceability | 5 |

4. Write each finding as `[SEVERITY] dimension — problem` with `Evidence` (quoted, line N), `Why` and an exact `Fix`. Severities: blocker, major, minor, note. A finding missing Evidence, Why or Fix is invalid; delete it.
5. Check every agent the target names against the installed roster; a named agent that is not installed, or a missing failure path for risky work, is a blocker.
6. Emit readiness and a proposed decision. Finding severity decides the decision, never the score; the score is `min(rubric score, validator cap)`: 39 for a parse or format failure, 69 for a missing required field, otherwise 100.

## Lenses

Apply two classification lenses while scoring; each feeds the rubric dimensions, not a separate score.

- **Power fit:** classify the agent UNDERPOWERED / FIT / OVERPOWERED: do its tools and permissions match its mission (least privilege)? A mismatch is a major finding; escalate to blocker when the extra power enables mutation, secret exposure, installs, hooks or release work without a matching mission and approval step, or when an underpowered agent recommends an action it cannot perform.
- **Enforceability:** classify each guardrail ENFORCED / INSTRUCTION_ONLY / UNENFORCEABLE. A rule is ENFORCED only when a host setting (an agent field the host honours, or the project's permission settings; Host Formats below) or an executed validator enforces it; otherwise it is guidance. Clear, reachable guidance is acceptable and is not marked down for being unenforced. A body that claims enforcement nothing provides is major. UNENFORCEABLE (the settings grant a broader action than the prose restricts) is major, and blocker when it grants write, destructive, package-manager, hook, release or secret-adjacent access.

## Host Formats


Agents are `.codex/agents/*.toml`, plus `~/.codex/agents/*.toml`; an agent's identity is its `name` field, not its file name. The file must parse as TOML with `name`, `description` and `developer_instructions`. The sandbox and approval policy come from the session, not the agent file, so a restriction stated in the file is guidance.

## Output

- `SCORE: NN/100` with the weighted arithmetic shown
- `READINESS: ready | ready-with-fixes | blocked`
- findings sorted blocker-first, each with evidence and an exact fix
- proposed `decision: approve | approve_with_minor_fixes | needs_refactor | block`
- a one-line-per-finding summary when this review is part of an assessment of every agent

## Gotchas

- reject non-agent input instead of scoring it
- finding severity does not change the score; only a validator cap does (39 for a parse or format failure, 69 for a missing required field), and severity decides the decision and readiness separately
- `decision` uses only the four-value enum; never invent another value
- agent files installed by Glyphbrace are managed: only the user section at the end is meant for local edits, so recommend that section or the agent's declared source, never hand-editing the managed part
- use `unknown` where evidence is absent; never score against a line budget the repository does not document
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
