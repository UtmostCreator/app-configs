# Service Boundary Patterns Capability

## Purpose

Define public, internal, tool, and data boundaries so agent-enabled workflows do not blur trust and risk surfaces.

## Trigger When

- workflows span multiple services or internal tool surfaces
- a task exposes new user-facing or internal entrypoints
- shared data stores or internal APIs increase blast radius

## Workflow

1. identify public, internal, tool, and data surfaces
2. define authentication and authorization boundaries per surface
3. define audit and failure-handling expectations at boundary crossings
4. call out shared-state blast radius and isolation posture
5. record fallback behavior when runtime surfaces differ

## Read Next

- `SERVICE_BOUNDARIES.md` for public and internal service boundaries
- `INTERNAL_TOOL_SURFACES.md` for internal tool controls
- `DATA_BOUNDARIES.md` for shared data and isolation risks

## Output Contract

- boundary map by surface type
- authz and audit expectations per boundary
- data isolation and blast-radius notes
- internal tool surface controls

## Acceptance Criteria

- boundaries are explicit and reviewable
- internal tools are not treated as implicitly trusted
- data boundary risks are documented
- cross-boundary actions include traceable evidence expectations
