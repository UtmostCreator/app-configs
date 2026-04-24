# AgentOps Integration Checklist

Use this checklist to verify that the repository has the expected AgentOps, approval, failure-handling, and agent-governance layers integrated.

## Phase 1: Entry Points

Goal: confirm that a user or runtime entering through the common top-level files can discover the canonical policy quickly.

Check these files:

- `AGENTS.md`
- `CLAUDE.md`
- `README.md`
- `.github/copilot-instructions.md`
- `.github/instructions/ai-workflow.instructions.md`

Verify:

- `docs/ai/project-context.md` is referenced from the primary runtime entrypoints.
- `docs/ai/agents.md` is referenced as the durable live-agent reference.
- `docs/ai/failure-handling.md` is referenced as the command-failure policy.
- safe repo-local read-only commands are stated as approval-free by default.
- exceptions are stated for secrets, privileged access, destructive work, or side effects.

Accept when:

- every runtime entrypoint points back to canonical docs
- approval-free read-only wording is consistent
- no runtime-specific file claims to be the canonical source of workflow truth

## Phase 2: Canonical Policy

Goal: verify that the live canonical docs cover the operational model instead of relying on adapter-specific instructions.

Check these files:

- `docs/ai/workflow.md`
- `docs/ai/project-context.md`
- `docs/ai/AI-GUARDRAILS.md`
- `docs/ai/agent-ops.md`
- `docs/ai/agents.md`
- `docs/ai/failure-handling.md`

Verify:

- the workflow mentions failure logging and retry decisions
- the project context mentions approval-free read-only work and failure policy
- the guardrails mention command-failure logging and retry constraints
- the agent-ops doc covers observability, evaluation, and optimization in that order
- the agent-ops doc covers shift-left code risk, IAM maturity, common agent risks, ADK versus RAG routing, role design, and multimodal caveats
- the agent reference lists every live agent and explains when to use it
- the failure-handling doc defines taxonomy, retry rules, and logging fields

Accept when:

- canonical docs are sufficient to explain the operating model without reading only `.github/`
- the repo can explain what its agents do, how failures are handled, and when approval is required

## Phase 3: Runtime Enforcement And Telemetry

Goal: verify what is actually operational on supported runtime surfaces.

Check these files:

- `.github/hooks/tool-policy.json`
- `.github/hooks/tool-guardian.json`
- `.github/hooks/scripts/tool-guardian.ps1`
- `scripts/copilot/pre-tool-use.sh`
- `scripts/copilot/post-tool-use.sh`
- `scripts/copilot/common.sh`
- `scripts/copilot/ai-diff-context.sh`
- `docs/ai/copilot-tooling.md`

Verify:

- hook config targets exist
- pre-tool policy blocks or denies obviously risky commands
- post-tool logging is wired
- stronger wrapper scripts share one helper layer for dependency checks, logging, and token budget checks
- guard scripts are narrow and deterministic
- docs describe hooks as enforcement and telemetry, not the canonical workflow source

Accept when:

- runtime enforcement files exist and match the docs that describe them
- post-tool logging works for the supported Copilot surface
- destructive commands remain denied by default unless explicitly requested

## Phase 4: Validation And Discoverability

Goal: make integration easy to prove with machine checks and generated indexes.

Check these files:

- `tools/ai/validate-ai-config.php`
- `tools/ai/validate-ai-catalog.php`
- `tools/ai/generate-ai-catalog.php`
- `tools/ai/ai_catalog_lib.php`
- `docs/ai/catalog.md`
- `llms.txt`

Verify:

- validators require the key live docs to exist
- validators check that runtime entrypoints reference canonical docs
- validators check that live agents are documented in `docs/ai/agents.md`
- validators check that hook targets exist when hook configs are present
- the generated catalog exposes the main live workflow docs, not only capabilities and agents

Accept when:

- `php tools/ai/validate-ai-config.php` passes
- `php tools/ai/validate-ai-catalog.php` passes
- `php tools/ai/generate-ai-catalog.php --check` passes

## Phase 5: Coverage Review

Goal: verify that the repo covers the major concepts it claims to support.

Use `docs/ai/integration-matrix.md` and review whether each concept is `covered`, `partial`, or `missing`.

Focus areas:

- AgentOps core model
- code risk intelligence and shift-left posture
- IAM maturity for agents
- common agent-security risks
- ADK versus RAG architecture choices
- multi-agent role design
- multimodal caveats and fallbacks
- domain grounding before action

Accept when:

- every focus area has a mapped canonical file
- any `partial` item has a concrete follow-up note
- no important concept relies only on tribal memory

## Phase 6: Evidence Run

Goal: produce a repeatable read-only verification run after workflow changes.

Run:

```powershell
php tools/ai/validate-ai-config.php
php tools/ai/validate-ai-catalog.php
php tools/ai/generate-ai-catalog.php --check
```

Then review:

- `docs/ai/catalog.md`
- `docs/ai/integration-matrix.md`
- `.copilot-logs/README.md` for the committed runtime-log contract and local telemetry expectations

Accept when:

- validators pass
- generated artifacts are up to date
- the coverage matrix still matches repository truth

## Audit Notes

- This checklist is intentionally repo-focused. It verifies that the workflow layer exists, is discoverable, and is internally coherent.
- It does not prove that every runtime surface has identical enforcement. When support differs by surface, document the fallback instead of implying parity.
