# Generated Artifacts Policy

Do not manually edit generated artifacts.

Each generated artifact should map to:

- artifact path
- source inputs
- generator command
- check command
- committed status

Use validator: `php tools/ai/validate-generated-artifacts.php`.

If generated outputs drift, regenerate using documented commands and include the output in the same change.

## Runtime Session Logs

AI session handoff logs under `docs/ai/generated/sessions/SESSION_ID/` are runtime-generated artifacts. Create and validate them with:

- generator commands: `php tools/ai/session-start.php`, `php tools/ai/agent-log.php`, `php tools/ai/session-end.php`
- check command: `php tools/ai/validate-session-log.php <session-id-or-path>`

Do not manually add secrets or raw private prompts to session logs.
