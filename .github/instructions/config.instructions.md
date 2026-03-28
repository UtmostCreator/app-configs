---
applyTo: "vscode/**,shell/**,tools/**,php/**,.editorconfig,.eslintrc.json,.prettierrc.json,.stylelintrc.json"
description: "Rules for config changes in editor, shell, runtime, and tool files"
---

# Config Rules

- Preserve existing behavior unless the task explicitly changes it.
- Prefer clear, deterministic settings over clever but opaque config.
- Call out machine-specific assumptions in shared docs.
- Validate with the closest safe parser, linter, or launch command the tool supports.
- Keep comments sparse and only where behavior is not obvious.
