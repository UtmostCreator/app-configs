# Internal Tool Surfaces

Treat internal tool endpoints (including MCP-style surfaces) as authorization boundaries.

## Rules

- define explicit allow and deny scope for each tool surface
- enforce on-behalf-of delegation when tools act for a user
- require audit records for mutating tool actions
- apply rate and failure controls for high-impact tools

Tool availability does not imply permission.
