---
name: config-change-safety
description: Applies scoped editor, shell, runtime, tool, build or CI configuration changes; verifies their effects and preserves behaviour outside the change.
---

## What I Do

I change editor, shell, runtime, or tool configuration with the smallest safe edit and prove it with the closest available verification: the intended effect takes hold and behavior outside the change stays as it was. Config changes fail quietly: a mis-parsed key or a dropped default breaks a runtime with no obvious error.

## When To Use Me

- when editing JSON, YAML, TOML, INI, or shell/runtime configuration
- when changing tool, editor, or runtime settings that affect behavior
- when a schema, default, or compatibility posture could shift silently
- before claiming a config change is safe

## Read Alongside

- `verify-change` — the proof ladder for a config change
- `docs-sync` — when docs reference the changed config


## Build, Packaging, And CI

- Before adding build, packaging, CI, or verification config structure, search for an existing pattern and reuse or adapt it when behavioral or responsibility overlap is substantial. State numeric similarity only when a tool measured it, naming the method and scope.
- If a dependency manifest change requires a lockfile update, do not edit the lockfile directly; route regeneration through the owning install command or tool.

## Steps

A calling agent may perform only the steps permitted by its own authority.
Read-only agents may inspect configuration risks and verification criteria but
must not execute mutation steps. CI definitions, agent definitions, dependency
manifests and other protected files remain subject to the calling agent's
specific scope restrictions.

1. Scope narrowly: identify the exact keys or files that must change and the behavior that must stay identical; leave everything else untouched.
2. Capture current behavior first — the existing value, default, or output — so you can show the intended effect and prove nothing outside it regressed.
3. Make the smallest edit that achieves the change; prefer in-place edits over rewriting whole config files.
4. Verify with the closest check: the format's own parser or schema validator, then the tool's own lint or dry-run, then a focused behavior check — narrowest first, escalating only if needed.
5. If a runtime cannot support a verification or a workflow step, document the fallback explicitly instead of claiming parity.

## Output

- the scoped list of keys/files changed, their intended effect, and the behavior held constant outside them
- the verification command run and its result (parser, linter, or tool check)
- confirmation that the intended effect was observed and behavior outside the change is preserved, or the regression found
- any documented fallback where a runtime could not support a step

## Gotchas

- a file that parses is not proof of correct behavior — validate the tool actually accepts it
- do not silently widen compatibility or drop a default while making an unrelated change
- never read or change secrets or credentials; request a sanitised example or owner handoff instead
- ask before changing broad compatibility posture
- never claim a verification you did not run; separate executed checks from recommended ones
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
