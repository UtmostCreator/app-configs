# Install Safety

Installer flow must be safe by default:

1. resolve config/profile
2. stage outputs first
3. validate staged outputs
4. create backup manifest
5. apply writes
6. print rollback path

Dry-run must avoid direct writes.

Use:

```bash
php tools/ai/ai.php install --dry-run
php tools/ai/verify-full-install.php
```
