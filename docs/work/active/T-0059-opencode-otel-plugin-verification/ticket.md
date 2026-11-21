Source: local

# T-0059: OpenCode OTel plugin: verify against a live session, redact at the source (bug)

Status: open (verified 2026-11-21 from an external audit; owner to decide keep or remove)
Relates to: ADR-0032

Written 2026-11-21 against main 0b09964.

## Findings (verified by reading the code; nothing executed)
- `home/dot_config/opencode/plugins/otel-tracing.ts` is deployed live (`~/.config/opencode/plugins/`, auto-loaded by opencode) and its header (line 12) says NOT YET VERIFIED.
- OTEL-01: a missing error field is recorded as success (`:292-296`); concurrent calls to one tool pair through a per-tool-name stack fallback (`:153-158`).
- OTEL-02: `tool.error` is always captured and raw arguments optionally (`:33-40`); redaction relies on the collector config.

## Acceptance criteria
- AC0: owner decision recorded: keep the plugin, or stop deploying it.
- AC1: event payload schemas checked against the installed opencode version; unknown outcomes recorded as `unknown`, never `success`.
- AC2: concurrent calls to the same tool keep correct start/end pairing (fixture test).
- AC3: credential patterns are redacted in the plugin before export; cloud exporters get an attribute allowlist.
- AC4: tests with synthetic keys, bearer tokens, paths and error messages; a live-session report; tracing stays non-blocking.
- Independent review PASS; no AI attribution trailers.
