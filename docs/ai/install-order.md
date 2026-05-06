# AI Install Order

Use this order for reliable install-and-verify flow in target repositories.

1. `php tools/ai/install-ai-kit.php --target /path/to/repo --profile minimal --runtime github-copilot`
2. `php tools/ai/install-ai-kit.php --target /path/to/repo --profile minimal --runtime opencode`
3. Optional packs with `--with` (for example `scripts-pack`, `hooks-pack`, `advisor-pack`).
4. `php tools/ai/validate-ai-config.php`
5. `php tools/ai/validate-install-surface.php`
6. `php tools/ai/validate-ai-catalog.php`
7. `php tools/ai/generate-ai-catalog.php --check`
8. `php tools/ai/verify-full-install.php`

For selective profile and pack details, see `docs/ai/installer-architecture.md` and `docs/ai/external-repo-install.md`.
