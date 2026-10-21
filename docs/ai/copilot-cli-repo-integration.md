# Copilot CLI Repo Integration

Use this guide when you want to copy the `app-configs` Copilot workflow into another repository and make the wrapper scripts, hook policy, and tree-context tooling available during AI use.

## Goal

The reusable shape is:

1. repo instructions tell Copilot which tools to prefer
2. wrapper scripts in `scripts/ai/` provide deterministic entrypoints
3. `.github/hooks/tool-policy.json` wires pre/post hook enforcement
4. `COPILOT_STRICT_ALLOWLIST=1` forces Copilot CLI to use the approved read-only wrappers instead of raw `grep`, `find`, or `cat`
5. `repomix-context-tree.sh` generates a root index plus child bundles so agents load the smallest relevant context first

## Minimum Files To Copy

Copy these into the target repository first:

- `.github/copilot-instructions.md`
- `.github/hooks/tool-policy.json`
- `docs/ai/project-context.md`
- `docs/ai/workflow.md`
- `docs/ai/agents.md`
- `docs/ai/failure-handling.md`
- `docs/ai/copilot-tooling.md`
- `docs/ai/context-packing.md`
- `docs/ai/hooks.md`
- `docs/ai/capabilities/project-context/`
- `docs/ai/capabilities/verify-change/`
- `docs/ai/capabilities/review-diff/`
- `scripts/ai/`

Add `.github/instructions/`, `.github/agents/`, `.github/prompts/`, and `.github/skills/` after the baseline works.

## Required Repo Wiring

Keep these relative paths unchanged unless you intentionally retarget the whole stack:

- `.github/hooks/tool-policy.json` should point at `./scripts/ai/pre-tool-use.sh` and `./scripts/ai/post-tool-use.sh`
- `policies/copilot/policy.yaml` remains the source policy file consumed by the hook scripts
- `.github/copilot-instructions.md` should mention the wrapper order and point to the `docs/ai/` files you copied

If the target repo has different project facts or workflow rules, update `docs/ai/project-context.md` and `.github/copilot-instructions.md` first. Do not copy this repo's facts into an unrelated codebase unchanged.

## Shell Setup For Copilot CLI

Copilot CLI hook enforcement depends on the shell environment that launches `gh copilot`.

Add this to the shell profile you use for Copilot CLI, such as `~/.zshrc`:

```bash
export COPILOT_STRICT_ALLOWLIST=1
```

Reload the shell before launching Copilot CLI:

```bash
source ~/.zshrc
```

Strict mode means:

- raw `grep`, `find`, and `cat`-style commands are denied during CLI tool use
- repo wrappers like `scripts/ai/rg-code.sh`, `scripts/ai/fd-files.sh`, and `scripts/ai/preview-file.sh` are allowed
- destructive cleanup commands such as `repomix-context-tree.sh purge` still require confirmation through the hook policy

## Runtime Support Caveat

Hook enforcement is runtime-dependent.

- Copilot CLI and cloud-agent surfaces can load repository hooks
- VS Code IDE agent mode does not load repository hooks
- VS Code still benefits from the repo instructions and wrapper scripts, but the hook itself is not the enforcement layer there

This means the strict allowlist behavior in this guide is primarily a Copilot CLI setup, not a VS Code IDE agent setup.

## Dependencies

Install the base CLI dependencies in the target environment:

```bash
brew install jq yq ripgrep fd bat scc
npm install -g repomix
```

Additional tools like `ast-grep`, `semgrep`, `delta`, `watchexec`, or `entr` are optional but useful.

## Default Search And Preview Flow

Teach the target repository to route search and previews through the wrappers:

- `scripts/ai/ai-search.sh` for a stable unified search entrypoint
- `scripts/ai/rg-code.sh` for code and text search
- `scripts/ai/fd-files.sh` for file discovery
- `scripts/ai/preview-file.sh` for file previews
- `scripts/ai/git-forensics.sh` for history tracing

When strict mode is on, Copilot CLI should use these wrappers instead of raw shell commands.

## Default Context Workflow

Use the tree planner as the default Repomix workflow in new repos:

```bash
scripts/ai/repomix-context-tree.sh all . --compress --style xml
```

The generated entrypoints are:

- `.repomix-context/tree-context/index.md`
- `.repomix-context/tree-context/tree-manifest.json`
- `.repomix-context/tree-context/indexes/`
- `.repomix-context/tree-context/bundles/`

Tell agents to start from `index.md`, then follow the smallest relevant child index or bundle.

Keep `repomix-scc-router.sh` only as a compatibility or ranking-specific workflow, not the default starting point.

## Recommended `just` Defaults

If the target repo uses `just`, make the tree workflow the default surface:

- `context-analyze` -> `repomix-context-tree.sh analyze`
- `context-stats` -> alias for tree analyze
- `context-plan` -> `repomix-context-tree.sh plan`
- `context-pack` -> `repomix-context-tree.sh pack`
- `context-pack-all` -> `repomix-context-tree.sh all`
- `context-clean` -> `repomix-context-tree.sh clean`
- `context-purge` -> `repomix-context-tree.sh purge`

Keep router-prefixed tasks such as `context-router-plan` only when you still need the legacy ranked-folder bundle flow.

## Quick Verification In A New Repo

Run these checks after copying the files:

```bash
bash -n scripts/ai/pre-tool-use.sh
bash -n scripts/ai/repomix-context-tree.sh
printf '%s' '{"toolName":"bash","toolArgs":{"command":"grep -r test ."}}' | COPILOT_STRICT_ALLOWLIST=1 bash scripts/ai/pre-tool-use.sh
printf '%s' '{"toolName":"bash","toolArgs":{"command":"scripts/ai/rg-code.sh test"}}' | COPILOT_STRICT_ALLOWLIST=1 bash scripts/ai/pre-tool-use.sh
scripts/ai/repomix-context-tree.sh all . --compress --style xml
```

Expected outcomes:

- syntax checks succeed
- raw `grep` is denied
- `scripts/ai/rg-code.sh` is allowed
- the tree build writes `.repomix-context/tree-context/index.md`

## Recommended Copilot Prompt Pattern

When using Copilot CLI or a compatible agent, instruct it to load the generated tree entrypoint first:

```text
Start from .repomix-context/tree-context/index.md, follow the smallest relevant child artifact, and use scripts/ai/rg-code.sh for search.
```

That one sentence is usually enough to keep the agent on the intended search and context path.
