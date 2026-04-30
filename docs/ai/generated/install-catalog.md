# Install Catalog

Deterministic catalog generated from installer registries.

## Profiles

- `minimal`: `base, setup-docs, capabilities-core`
- `copilot`: `minimal, adapter-copilot`
- `opencode`: `minimal, adapter-opencode`
- `dual`: `minimal, adapter-copilot, adapter-opencode, capabilities-extended-lite`
- `guarded`: `dual, policy-pack, hooks-pack, evidence-pack`
- `accelerated`: `dual, scripts-pack, policy-pack, evidence-pack`
- `full-governance`: `accelerated, capabilities-extended-full, hooks-pack, ci-pack`
- `docs-reference`: `docs-reference-pack`
- `custom`: ``

## Packs

- `setup-docs` (0 items)
- `capabilities-core` (0 items)
- `base` (6 items)
- `adapter-copilot` (4 items)
- `adapter-opencode` (3 items)
- `capabilities-extended-lite` (2 items)
- `capabilities-extended-full` (1 items)
- `policy-pack` (3 items)
- `scripts-pack` (23 items)
- `hooks-pack` (3 items)
- `ci-pack` (2 items)
- `evidence-pack` (2 items)
- `docs-reference-pack` (8 items)
- `delivery-pack` (2 items)
- `optional-agents-pack` (1 items)
- `optional-prompts-pack` (1 items)
- `preview-environments-pack` (1 items)
- `evaluation-pack` (1 items)
- `service-boundary-pack` (1 items)
- `mcp-boundaries-pack` (1 items)
- `advisor-pack` (4 items)

## Script IDs

- `repomix-context` -> `scripts/ai/run-repomix-context.sh`
- `repomix-tree` -> `scripts/ai/repomix-context-tree.sh`
- `repomix-scc-router` -> `scripts/ai/repomix-scc-router.sh`
- `pack-context` -> `scripts/ai/pack-context.sh`
- `repo-tool-inventory` -> `scripts/ai/repo-tool-inventory.sh`
- `install-mandatory-tools` -> `scripts/ai/install-mandatory-tools.sh`

## Toolchain

- `bash`
- `git`
- `jq`
- `rg`
- `node`
- `npm`
- `repomix` (safe auto-install)
- `scc`
