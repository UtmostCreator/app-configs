# Compatibility

This package is intentionally asymmetric.

OpenCode and GitHub Copilot overlap in concepts, but they do not expose the same control model. This kit preserves shared intent where possible and splits delivery when the tool surfaces diverge.

Use these capability tiers when adapting the kit:

- `OpenCode`
- `GitHub Copilot in VS Code or CLI`
- `GitHub Copilot on GitHub.com`

## Portable Concepts

These ideas transfer well across tools:

- one repository-level policy source
- path-scoped rules
- review-oriented role prompts
- refactor-oriented role prompts
- reusable project context
- repeatable workflows for review, bug fixing, and verification

## Parity Matrix

`High` means the feature is explicit, repo-local, and broadly configurable in the target surface. `Medium` means the feature exists but is more runtime-mediated or surface-limited. `Low` means support is partial, gated, or not a close equivalent.

| Capability | OpenCode | Copilot VS Code / CLI | Copilot GitHub.com | Notes |
| --- | --- | --- | --- | --- |
| Repo-wide instructions | High | High | High | OpenCode centers `AGENTS.md`; Copilot uses `.github/copilot-instructions.md`. |
| Path-specific instructions | Medium | High | Medium | Copilot path instructions are explicit; support differs by surface. |
| Nearest `AGENTS.md` behavior | Medium | Medium | Medium | Copilot supports nearest `AGENTS.md`, but lookup and enablement vary by environment. |
| Custom agents | High | High | Medium | Copilot custom agents exist, but environment-specific properties can differ. |
| Handoffs / subagent routing | High | Medium | Low | OpenCode exposes agent workflows more directly; Copilot support is surface-dependent. |
| Prompt-style workflow assets | Low | High | Low | Copilot prompt files are preview-only and not universal. |
| Skills / reusable capabilities | High | Medium | Low | Copilot has related capability models, but they are not uniform across surfaces. |
| Commands as first-class repo assets | High | Low | Low | OpenCode commands are native; Copilot prompts are the closest workflow asset but not a command system. |
| MCP integration | High | High | Medium | Both support MCP-style integration, but enablement varies by runtime. |
| Config layering | High | Medium | Low | OpenCode documents explicit config precedence; Copilot behavior is spread across settings and surfaces. |
| Global or org-shared rules | Medium | Medium | Medium | Available in both ecosystems, but not through one identical control path. |

## OpenCode Focus

OpenCode is modeled here around:

- `AGENTS.md`
- `.opencode/agents/`
- `.opencode/commands/`
- `.opencode/skills/`
- `opencode.json`
- `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR`

Use the OpenCode templates when you want a repo-native workflow with custom roles and repeatable commands.

## GitHub Copilot Focus

GitHub Copilot is modeled here around:

- `.github/copilot-instructions.md`
- `.github/instructions/**/*.instructions.md`
- `.github/agents/`
- `.github/prompts/`
- nearest `AGENTS.md`

Repository instructions and path-specific instructions are the most stable starting point. Prompt file support can vary by IDE and feature surface, so treat prompts as optional workflow assets rather than guaranteed building blocks.

For this kit, Copilot keeps a compact core workflow set rather than mirroring every optional OpenCode specialist role. Use the same core intent across tools, but keep the Copilot adapter lighter.

## Important Differences

- Do not assume every OpenCode role should have a Copilot twin beyond the compact core workflow set.
- Do not assume every Copilot surface supports prompt files.
- Do not assume Copilot VS Code or CLI behavior matches Copilot on GitHub.com.
- Do not assume handoffs or advanced custom-agent properties behave the same in every Copilot runtime.
- Do not assume OpenCode commands map 1:1 to Copilot prompt files.
- Do not assume one tool will consume the same amount of policy text as the other.
- Do not duplicate the full policy across every file. Keep the core policy central and adapter files lighter.

## Safe Default

If portability matters more than maximum customization:

1. Start with core policy templates.
2. Add OpenCode agents, commands, and skills only if the repository uses OpenCode.
3. For Copilot, start with `.github/copilot-instructions.md` and `.github/instructions/`.
4. Add only the compact Copilot agent core next: architect, reviewer, refactorer.
5. Add Copilot prompts only on surfaces that support them and only after documenting a fallback.

## Recommendation

If you are unsure:

1. Start with core policy templates.
2. Add only the adapter for the tool you actively use.
3. Add optional packs after the base flow feels stable.
