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
