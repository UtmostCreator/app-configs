# Bug Regression Capability

## Purpose

Reproduce a config or workflow defect with the smallest reliable check, apply a bounded fix, and prove the issue is closed.

## Trigger When

- a setup step is broken
- an instruction points to the wrong file or command
- a tool-specific adapter behaves inconsistently with canonical docs

## Workflow

1. identify the failing path, command, or surface
2. capture the smallest reproduction or direct mismatch
3. apply the smallest safe fix
4. verify the corrected path, command, or behavior
5. sync any stale documentation in the same slice

## Output Contract

- reproduction
- root cause
- minimal fix
- evidence
