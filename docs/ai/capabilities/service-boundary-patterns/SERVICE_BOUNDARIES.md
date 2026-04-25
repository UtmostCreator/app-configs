# Service Boundaries

Use this model for vendor-neutral boundary design:

`external user surface -> authenticated boundary -> application/API surface -> authorized internal boundary -> tool surface`

## Rules

- expose only intended user-facing surfaces publicly
- keep internal services on internal-only paths or networks
- require explicit authentication and authorization at each entrypoint
- define audit expectations for cross-boundary actions
