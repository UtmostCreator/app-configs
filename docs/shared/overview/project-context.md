<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0021
  kind: template
  status: template
  summary: Project Context
  review:
    approval_ref: unknown
    summary_by: agent
---
# Project Context

What an agent, automation workflow, or new engineer needs before touching this repository.

Use this file as the durable, canonical project context for repository instructions, agents, prompts, reviews, and operational decisions.

## 1) Project Identity

| Field | Value |
|---|---|
| Project | `[OWNER_TO_FILL]` |
| Purpose | `[OWNER_TO_FILL]` |
| Project type | `[OWNER_TO_FILL]` |
| Primary language | `[OWNER_TO_FILL]` |
| Primary runtime or framework | `[OWNER_TO_FILL]` |
| Primary stack | `[OWNER_TO_FILL]` |
| Package manager | `[OWNER_TO_FILL]` |
| Supported targets | `[OWNER_TO_FILL: server, browser, CLI, CI, worker, mobile, admin UI, etc.]` |
| Main test command | `[OWNER_TO_FILL]` |
| Main build command | `[OWNER_TO_FILL]` |
| Main verification command | `[OWNER_TO_FILL]` |
| Last verified | `[OWNER_TO_FILL: YYYY-MM-DD]` |

## 2) Repository Purpose

`[OWNER_TO_FILL: one short paragraph explaining what this repository owns, why it exists, and what kind of changes normally belong here.]`

This repository owns:

- `[OWNER_TO_FILL]`
- `[OWNER_TO_FILL]`
- `[OWNER_TO_FILL]`

This repository does not own:

- `[OWNER_TO_FILL]`
- `[OWNER_TO_FILL]`
- `[OWNER_TO_FILL]`

## 3) Where Things Live

Fill in the 5 to 10 paths that matter most. Prefer ownership and intent over exhaustive directory listings.

| Path | Owns / Purpose | Notes |
|---|---|---|
| `[PATH]` | `[OWNER_TO_FILL]` | `[OWNER_TO_FILL]` |
| `[PATH]` | `[OWNER_TO_FILL]` | `[OWNER_TO_FILL]` |
| `[PATH]` | `[OWNER_TO_FILL]` | `[OWNER_TO_FILL]` |
| `[PATH]` | `[OWNER_TO_FILL]` | `[OWNER_TO_FILL]` |
| `[PATH]` | `[OWNER_TO_FILL]` | `[OWNER_TO_FILL]` |

## 4) Main Entrypoints

Use these first when trying to understand the repository.

- Primary documentation: `[OWNER_TO_FILL]`
- Application entrypoint: `[OWNER_TO_FILL]`
- API or route entrypoint: `[OWNER_TO_FILL]`
- Configuration entrypoint: `[OWNER_TO_FILL]`
- Test entrypoint: `[OWNER_TO_FILL]`
- Build entrypoint: `[OWNER_TO_FILL]`
- Deployment or CI entrypoint: `[OWNER_TO_FILL]`

## 5) Source Of Truth

When files disagree, use this precedence order:

1. Current git diff and working tree
2. Source code
3. Tests
4. Schemas, contracts, migrations, types, or public interfaces
5. Runtime, build, deployment, and environment configuration
6. This file
7. Other project documentation
8. Agent, CI, or tool adapter files
9. Generated files

Stale documentation must not override current code evidence.

## 6) Task-Context Gate

Before planning or editing, load the most relevant repository context.

Use one or more of:

- `[OWNER_TO_FILL: latest task-context file]`
- `[OWNER_TO_FILL: context compilation command]`
- `[OWNER_TO_FILL: impact analysis command]`
- `[OWNER_TO_FILL: architecture or ownership document]`

If these are missing, perform read-only discovery first and produce a brief plan before making edits.

## 7) Placement, Naming, And Reuse Rules

File placement rules:

- `[OWNER_TO_FILL]`
- `[OWNER_TO_FILL]`
- `[OWNER_TO_FILL]`

Naming rules:

- `[OWNER_TO_FILL]`
- `[OWNER_TO_FILL]`
- `[OWNER_TO_FILL]`

Golden examples to copy:

- `[OWNER_TO_FILL: path or file]`
- `[OWNER_TO_FILL: path or file]`
- `[OWNER_TO_FILL: path or file]`

Before adding non-trivial logic:

1. Search for existing overlap.
2. Identify the nearest reusable pattern.
3. Compare behavior and responsibility; report numeric similarity only when a tool measured it, naming the method and scope.
4. When overlap is substantial, extend or adapt the existing pattern instead of adding a duplicate.

## 8) System Integration Map

Replace, remove, or extend nodes as needed.

```mermaid
flowchart LR
    USER["[USER_OR_CALLER]"]
    FE["[FRONTEND_OR_CLIENT]"]
    APP["[THIS_REPOSITORY]"]
    SYS["[INTERNAL_SYSTEM_OR_SERVICE]"]
    DB["[DATABASE_OR_STORAGE]"]
    SEARCH["[SEARCH_SERVICE]"]
    CACHE["[CACHE_OR_QUEUE]"]
    PAY["[PAYMENT_OR_EXTERNAL_PROVIDER]"]

    USER --> FE
    FE -->|"[API_OR_PROTOCOL]"| APP
    APP -->|"[API_OR_PROTOCOL]"| SYS
    APP --> DB
    APP --> SEARCH
    APP --> CACHE
    APP --> PAY
