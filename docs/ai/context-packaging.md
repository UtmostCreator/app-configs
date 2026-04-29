# Context Packaging Safety

Canonical context routing details live in `docs/ai/context-packing.md`.

Safety requirements before sharing context packs:

1. choose narrow scope first
2. exclude secrets/env/log/generated output
3. run secret scan (`php tools/ai/secret-scan.php`)
4. write context-pack manifest (`php tools/ai/build-context-pack.php --dry-run --scope <path>`)
5. only then generate/share bundles
