# Design Principles

## 1. One Core Policy

The package should have one neutral policy model. Tool-specific files adapt that policy instead of competing with it.

## 2. Progressive Adoption

A small starter set should work for most repositories. Specialist roles should be optional.

## 3. Honest Compatibility

Do not imply feature parity where none exists. Document platform differences directly.

## 4. Placeholder-First

The starter kit should be safe to share across projects because it contains reusable placeholders rather than hidden assumptions.

## 5. Concern-Based Organization

Organize by policy, role, workflow, and scoped instruction rather than by one project's architecture.

## 6. Low Maintenance

Avoid template symmetry that creates duplicate maintenance with little practical benefit.

## 7. Cross-Project Neutrality

Do not assume:

- a frontend exists
- a backend exists
- the repo is a monorepo
- one language or framework dominates
- one CI or build tool is in use

## 8. Capability Tiers, Not Single Labels

Treat OpenCode, Copilot VS Code or CLI, and Copilot GitHub.com as different control surfaces with different guarantees.

## 9. Graceful Degradation

The base kit should still work if prompts, handoffs, advanced agent properties, or optional adapters are removed.

## 10. Orthogonal Instruction Scopes

Keep repo-wide, path-specific, nearest-owner, and workflow-specific instructions complementary rather than overlapping or contradictory.

## 11. Prefer The Nearest Valid Owner

When multiple instruction sources exist, place narrow guidance near the code or workflow it governs instead of bloating global policy files.

## 12. Separate Workflow Assets From Command Guarantees

Do not describe reusable prompts or workflow assets as if they were equivalent to a native command system unless the target tool explicitly supports that model.

## 13. Prefer Stable Primitives Before Preview Features

Use stable repo-wide and path-specific instructions first. Add preview or surface-limited features only when their limitations are clearly documented.

## 14. Transparent Control Boundaries

Explain which parts of the system are explicit file-based controls and which parts depend on runtime behavior, settings, or feature enablement.
