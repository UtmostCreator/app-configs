---
name: "Codebase Memory Availability"
description: "Use when calling Codebase Memory MCP tools, graph tools, list projects, indexing, structural code discovery, or diagnosing a stalled MCP tool."
---
# Codebase Memory Availability

Use Codebase Memory graph tools when they are available and the task benefits from
structural evidence. A graph call must not block ordinary investigation.

- If an MCP graph tool reports an error or does not respond promptly, report the
  dependency unavailable and continue with targeted local source search.
- Do not wait indefinitely or repeatedly retry the same unavailable MCP call.
- Use `list_projects` and `index_status` only when graph evidence is needed for
  the current task; they are not session-start prerequisites.
