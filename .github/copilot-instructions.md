# Repository Instructions For app-configs

Use these instructions as the repository-wide baseline for GitHub Copilot.

They should remain valid even if advanced agent features or prompt files are unavailable on the active surface.

## Project Context

- Project: `app-configs`
- Type: `php project`
- Summary: `AI workflow starter for app-configs`
- Active paths: `.ai-install-manifest.json,.ai-logs,.editorconfig,.eslintrc.json,.gitattributes,.github,.gitignore,.gitleaks.toml,.gitleaksignore,.husky,.lefthook.yml,.markdownlint-cli2.yaml,.opencode,.prettierrc.json,.repomixignore,.schemas,.shellcheckrc,.stylelintrc.json,AGENTS.md,CLAUDE.md,CONTRIBUTING.md,README.md,SECURITY.md,SUPPORT.md,composer.json,composer.lock,configs,docs,justfile,llms.txt,packages,phpunit.xml.dist,policies,reference,scripts,tests,tools`
- Avoid by default: `unknown`
- Primary entrypoints: `README.md, docs/ai/project-context.md`
- Project context file: `docs/ai/project-context.md`
- Capability folders available: `project-context, verify-change, review-diff`

## Working Style

- Prefer the smallest safe change.
- For non-trivial work, classify risk as `low`, `medium`, or `high` to set review and verification depth.
- Read existing code before proposing structural changes.
- When the repository includes a tool map or command wrappers, load that routing first and prefer `rg`, `fd`, `ast-grep`/`sg`, and structured queries over raw `grep`, `find`, or broad file dumps.
- Follow established repository patterns before inventing new abstractions.
- Keep this file policy-focused and use prompt files, skills, or agents for deeper procedures.
- Treat the selected custom agent `.agent.md` tools list as the hard upper bound for tool use.
- Do not let prompt files widen the selected agent tool surface; prompt-file `tools:` must be equal or narrower than the agent.
- For repository shell work, prefer approved wrappers from `docs/ai/script-registry.md`, `docs/ai/script-registry.json`, and `docs/ai/scripts-reference.md` over ad hoc terminal commands.
- Treat `scripts/ai/pre-tool-use.sh` as the canonical pre-execution policy gate and `scripts/ai/post-tool-use.sh` as the canonical post-execution evidence writer; when the runtime supports repository hooks, keep them wired through `.github/hooks/tool-policy.json`, and when it does not, preserve the same boundary without claiming automatic enforcement.
- Approval-free read-only commands should stay read-only: searches, file reads, diagnostics, diff/history inspection, and approved registry scripts.
- Ask for approval before making: `secrets, destructive changes, auth or billing changes`
- A human approver must be able to explain each changed section well enough to own the merge.
- Distinguish current implementation from planned or hypothetical systems.
- Say `unknown` instead of guessing when repository evidence is missing.
- If a slice grows beyond roughly 6 files or 300-500 changed lines, pause and confirm it is still one bounded outcome.
- Prefer reusable capability folders for workflow-specific guidance when the repository provides them.

## Quality Bar

- Keep logic close to its existing owner.
- Add focused tests when behavior changes.
- Prioritize review around: `correctness, regressions, configuration drift`
- Use `unknown` as the main verification command unless the task needs a narrower command first.
- Start with the smallest relevant verification and escalate only when needed.
- Use the verification ladder: focused proof first -> affected layer tests second -> broader repository verification third -> build as a smoke check when relevant -> release-safety review only when risk warrants it.
- For `medium` and `high` risk changes, define rollback or disable path and post-deploy confirmation signal.
- For migrations that drop, rename, or restructure existing data, use expand-contract.
- Treat prototype paths as exploratory only; promoted prototype code must pass the normal workflow before merge.

## Common Gotchas

- `stale paths, broad edits without evidence, guessed behavior`
- When a workflow asset has its own `gotchas` section, follow the narrower guidance there.

## Limits

- Copilot surface: `VS Code, CLI, GitHub.com`
- Stable supported features: `repo instructions, path instructions`
- Optional or preview features: `prompt files, custom agents, hooks, MCP`
- Instruction precedence notes: `Nearest AGENTS.md wins for agent instructions.`
- Conflict avoidance notes: `Keep repo-wide and path-specific guidance complementary.`
- Global or shared rule sources: `organization instructions, user-level instructions`
- Stronger VS Code posture: combine fine-grained custom-agent tools, terminal auto-approval allowlists, repo hook policy, and sandbox/network restrictions instead of relying on prompts alone.
- Local evidence artifacts default to `.ai-logs/` as documented in `.ai-logs/README.md`.
- Do not assume prompt file support on every Copilot surface.
- Do not assume custom-agent properties, handoffs, or advanced workflows behave the same on every Copilot surface.
- Do not imply tool features that are not clearly supported in the current environment.
- Treat hooks, skills, and MCP as surface-aware features with explicit fallbacks.
