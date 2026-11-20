# Docker images

> **Reference only, not runnable.** These pages describe a Docker Compose dev stack whose
> Compose files, `scripts/` and `tests/` are not in this repository. Commands and paths below
> refer to that stack, not to app-configs. Kept as written for reference (2026-11-20).

Third-party images are pinned to `tag@sha256:digest`; `validate-compose.sh` and
`tests/image-refs` fail on floating references (local `example-dev/*` builds are exempt).

- `example-dev/php-cli:8.3` - Ubuntu 22.04 base, PHP 8.3 from a third-party package archive
  (signing key downloaded and verified against a pinned fingerprint, `PHP_PPA_KEY_FINGERPRINT`
  build arg), Node and Composer copied from digest-pinned stages. Build: `docker compose build`.

Verify a built image with `./scripts/verify-images.sh` (PHP version, required extensions, Node).
To bump a digest: pull the new tag, copy the `sha256` from `docker buildx imagetools inspect`,
update the Compose/Dockerfile reference and re-run `./scripts/validate-compose.sh all`.
