# Capabilities

These folders are the canonical reusable workflow layer for the root repository.

Related canonical references:

- `docs/ai/agents.md` - live agent reference and package agent index
- `docs/ai/failure-handling.md` - command failure taxonomy, retry rules, and logging contract
- `docs/ai/agent-ops-checklist.md` - phased verification checklist for workflow integration
- `docs/ai/integration-matrix.md` - coverage map for live AI workflow concepts

- `project-context` - load durable repo facts first
- `verify-change` - choose the smallest valid proof
- `review-diff` - review slices for drift and missing evidence
- `bug-regression` - reproduce, fix, and prove config or workflow defects
- `docs-sync` - keep setup guidance aligned with repo truth
- `config-change-safety` - manage blast radius for editor, shell, runtime, and machine-facing config edits
- `authorization-and-tool-governance` - define actor identity, tool scope, approval gates, and audit requirements before tool execution
- `agent-observability-and-evidence` - standardize trace identifiers, tool-call evidence, and failure categorization for agent runs
- `evaluation-and-regression` - define golden tasks, replay rules, and human-review triggers for behavior-changing agent work
- `preview-environments` - define lifecycle, TTL, data isolation, and cleanup rules for temporary integration environments
- `service-boundary-patterns` - define public, internal, tool, and data boundaries with explicit authz, audit, and isolation expectations

Keep runtime-specific adapters thin and point them back here.
