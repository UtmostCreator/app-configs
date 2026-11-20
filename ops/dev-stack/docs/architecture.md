# Architecture

> **Reference only, not runnable.** These pages describe a Docker Compose dev stack whose
> Compose files, `scripts/` and `tests/` are not in this repository. Commands and paths below
> refer to that stack, not to app-configs. Kept as written for reference (2026-11-20).

One application (`example-app`, PHP 8.3 Laravel) plus shared infrastructure, run with Docker Compose.

| Service | Image | Role | Host port (default) |
|---|---|---|---|
| `app` | `example-dev/php-cli:8.3` | `php artisan serve` | none (behind nginx) |
| `app-nginx` | `nginx-unprivileged` | reverse proxy + `/healthz` | `EXAMPLE_APP_PORT` (8080) |
| `app-queue` | `example-dev/php-cli:8.3` | queue worker (`workers` profile) | none |
| `mariadb` | `mariadb:10.11` | database `example_app` | optional (`MARIADB_HOST_PORT`) |
| `redis` | `redis:7.4-alpine` | cache/queue/session | optional (`REDIS_HOST_PORT`) |

Compose files: `compose.base.yml` (infra), `compose.common.yml` (hardened `extends` bases),
`compose.internal.yml` (app), `compose.host-ports.yml` (optional data ports),
`compose.test.yml` (isolated test DB + test runner), `compose.tools.yml` (composer/node).

## Profiles

`internal` is the only lifecycle profile. Compose profiles `workers`, `test` and `tools` are
layered on top by the scripts. `restart` is not a Compose restart policy; no service sets one.

## Networks

`devstack-apps` and `devstack-data` are `internal` (no
egress). Only `devstack-ingress` publishes ports, bound to `127.0.0.1`.

## Safety model

All containers run with `no-new-privileges`, memory limits and log rotation. `validate-env.sh`
refuses application `.env` files that point at non-local hosts or contain third-party
credentials; `validate-compose.sh` rejects unpinned third-party images.
