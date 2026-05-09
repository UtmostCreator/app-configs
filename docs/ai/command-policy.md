# AI Command Policy

This document explains command governance for AI agents. The enforceable source is `docs/ai/command-policy.tiers.yaml`.

## Authority

1. `scripts/ai/pre-tool-use.sh` runtime decision
2. `docs/ai/command-policy.tiers.yaml`
3. `docs/ai/script-registry.json`
4. Agent permission frontmatter (generated from policy tiers)
5. This markdown explanation

If this markdown conflicts with machine-readable policy, update this file to match machine-readable sources.

## Required Command Selection

Agents must choose commands in this order:

1. Approved repository wrapper
2. Structured CLI with bounded flags
3. Ask-gated raw fallback
4. Stop

Skipping a level is a policy violation.

## Wrapper-First Rule

Use repository wrappers for search, preview, structured data, test selection, task discovery, context packing, and verification. Raw shell is fallback only.

## Output Contract

Agent-facing wrappers must support at least one of:

- `AI_OUTPUT=json`
- `--json`
- bounded plain output with documented limits

Wrappers used by agents must avoid unbounded full-file, full-diff, full-log, or full-repo output.

## Secret Rule

Commands must not print secret values. Secret scanners must redact values and report path, line, and detector only.

## Unknown Command Rule

Unknown commands are `ask` or `deny`; never silently allowed.
