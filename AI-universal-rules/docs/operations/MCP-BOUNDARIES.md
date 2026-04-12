# MCP Boundaries

MCP extends capability, but also risk.

## Rules

- keep an allowlist of approved MCP servers
- document what systems each server can touch
- separate read-only and mutating servers when possible
- require stronger approval for production-facing or billing-sensitive systems
- do not imply MCP availability if the runtime is not configured for it

## Recommended Documentation

For each MCP integration, record:

- server name
- purpose
- environments reachable
- read-only or mutating posture
- approval requirements
- fallback behavior if unavailable
