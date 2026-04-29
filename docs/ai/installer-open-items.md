# Installer Open Items

This file tracks installer-adjacent gaps found during implementation and verification.

## Current Gaps

- Official runtime docs were verified for path conventions and naming, but not auto-fetched by installer at runtime.

## Evidence

- command: `bash scripts/copilot/repomix-context-tree.sh analyze .`
- result: context outputs generated successfully under `.repomix-context/tree-context/`

## Fix Direction

- keep installer deterministic and offline-safe by default.
- add optional runtime-doc audit mode later (`--audit-runtime-docs`) so install does not depend on network.
- keep the winget-path fallback in dependency-checking scripts so Git Bash can find executables installed via winget.
