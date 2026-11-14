---
name: workflow-drift-audit
description: Use when auditing AI workflow files for instruction drift, repository-context drift, or unsupported behavioral and enforcement claims, including drift shown by collected session evidence.
---

## What I Do

I audit AI workflow files read-only and flag drift: stale paths, placeholder leaks, the same agent or skill diverging between hosts, unsupported claims about tools, hooks or enforcement, and contradictions between instruction files. I report evidence-backed findings; I do not edit.

## Choose This Skill When

- Checking whether instruction, agent or skill files still match reality.
- A file references a tool, hook or path that may no longer exist.
- The Claude Code, Codex and GitHub Copilot copies of an agent or skill may have diverged.
- A workflow claim has no evidence behind it.

## Choose Another Skill When

- Use `agent-definition-review` when scoring one agent definition.
- Use `project-context` when you need to understand ownership and boundaries.
- Use `script-inventory` when the drift is in the repository's scripts rather than its instruction files.

## Read Alongside

- `project-context` — durable repository facts
- `agent-definition-review` — to score one agent definition
- `audit-agent-fleet` — to rank every installed agent
- `runtime-evidence` — to collect execution evidence before a session-derived check

## Steps

1. Confirm instruction files (`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md` and the files they point to) reference correct, existing paths; flag any broken or stale reference with its file location.
2. Check for placeholder leaks and secret values in live workflow files; report only the path and required owner action, never the value.
3. List the installed agents and skills per host from their directories (Claude Code `.claude/agents/` and `.claude/skills/`, Codex `.codex/agents/` and `.agents/skills/`, GitHub Copilot `.github/agents/` and `.github/skills/`). Compare the same agent or skill across hosts: differences confined to host-specific delegation or format are expected; any other divergence is drift.
4. When the files were installed by Glyphbrace and the `glyphbrace` command is available, run `glyphbrace status --root <dir> --provider <name>` for each installed provider: it reports installed files that changed or went missing, and exits 0 when nothing is pending. Edits inside a file's user section are the user's own and are not drift.
5. Flag unsupported workflow claims: features, tools, hooks or enforcement referenced but not present in the repository or the host's settings. A rule stated only in prose is guidance; a file that claims it is enforced when nothing enforces it is a finding.
6. Check for contradictions across the instruction files and the installed agent and skill files.
7. Report a verdict (CLEAN / DRIFT FOUND / ERRORS FOUND) with a severity-ranked findings table and a fix direction per row.

## Session-Derived Drift

Given bounded, source-identified execution evidence (collected beforehand,
never here), check whether a workflow failure reflects drift in an
instruction, navigation pointer, agent file or check. Classify each confirmed
candidate as navigation (missing or misleading pointer), enforcement (a
deterministic violation no check caught), guidance (a judgement the
instructions misdescribe), tool economy (repeated or needless retrieval),
staleness (instructions contradict repository facts), or access gap (evidence
the role cannot reach). For a deterministic failure, find the check or hook
that should have caught it and recommend repairing that rather than adding
prose. Recommend an instruction change only for a demonstrated guidance gap,
naming the observation, the instruction it implicates, and the owner of the
fix.

## Output

- a verdict and a severity-ranked findings table (file, issue, evidence, fix direction)
- a drift summary separating expected host differences from real divergence
- `unknown` for any surface that was blocked, denied or missing evidence

## Gotchas

- this is read-only; flag drift, never edit or invent new policy
- do not treat expected host-specific differences as drift
- name the file and evidence for every finding; use `unknown` rather than guessing a verdict
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
