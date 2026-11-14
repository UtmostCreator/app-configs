---
name: design-agent-runtime-guardrails
description: Designs runtime safeguards for an approved agent specification, identifying enforcement locations, budgets and readiness gaps. Does not configure or enforce safeguards.
---

## What I Do

I map an approved agent specification into a guardrail plan: the input,
tool-call and output controls, stop conditions, budgets and observability that
should wrap the agent when it runs. A valid, well-matched specification can
still misbehave at run time. I produce the plan; I never edit the specification
or any configuration.

## Where Guardrails Live

Instructions in an agent file are guidance; a model can fail to follow them.
Real guardrails live in two places:

- the host's own permission settings (tool allowlists, approval prompts,
  sandboxing), which the user owns and configures;
- deterministic checks in the project (tests, hooks, CI), which the project
  owns.

Glyphbrace installs neither: it writes no permission, tool or hook settings. So
every guardrail in the plan names where it would be enforced, and anything
left only as an instruction is marked as such.

## When To Use Me

- after a specification is approved and its runtime policy must be made concrete
- to translate its tools, limits and autonomy into allow and deny rules and ceilings
- when defining stop conditions, budgets or observability for a run
- before an agent is cleared to run unattended

## Read Alongside

- `check-agent-request-fit` — check the specification fits the task before designing its guardrails.

Read the host's documentation for its permission settings, and the agent's
installed file, to see what the host can actually enforce.

## Steps

1. **Input guardrails:** rules that reject unsafe, out-of-scope or
   injection-style prompts before the agent acts.
2. **Tool-call guardrails:** map every tool the specification needs to an
   explicit allow rule in the host's settings and deny the rest, including
   secret-bearing and destructive paths. Where the host cannot express a rule,
   say so.
3. **Output guardrails:** block leaked secrets, fabricated verification and
   scope creep in the final response, with the check that would catch each.
4. **Stop conditions and budgets:** derive concrete ceilings from the
   specification (maximum steps, token or cost ceiling, repeated-failure
   cutoff). Never invent limits higher than the specification allows.
5. **Observability:** every tool call and decision must be traceable.
6. **Verdicts.** Give two, and never let one stand for the other:
   - `DESIGN: complete | incomplete`. `complete` says only that the plan covers
     every tool, a stop condition, a budget and logging, and names where each
     control would be enforced. A missing stop condition or missing logging is
     `incomplete`. It says nothing about whether any control is configured.
   - `ENFORCEMENT: unverified | verified`. The default is `unverified`, because
     this skill configures nothing. Mark a control `verified` only with evidence
     you have seen: the host setting or project check file that holds the rule
     (path and line), and for an effect at run time a log or test result showing
     the action was refused or stopped. A proposal, a plan or an instruction in
     the agent file is never that evidence.

## Output

- input, tool-call and output guardrail rules, each with where it is enforced:
  host setting, project check, or instruction only
- a least-privilege permission mapping from the specification, for the user to
  apply in the host
- concrete stop conditions and budget ceilings (`unknown` where the
  specification omits one)
- an observability plan, `DESIGN: complete | incomplete` and `ENFORCEMENT: unverified | verified`, with the evidence behind any control marked verified

## Gotchas

- Guardrails may only narrow the granted surface, never widen it.
- Never claim a rule is enforced when it exists only as an instruction.
- A complete design never clears an agent to run; only `ENFORCEMENT: verified` with a human's approval can.
- Do not clear an agent that lacks human approval to run.
- Never read or print secrets while designing guardrails.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
