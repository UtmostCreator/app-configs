# Environment

## Stack `.env`

Copy `.env.example` to `.env`. Lookup order for every variable: process environment, `.env`,
`.env.example`, script fallback. Grammar is constrained: `KEY=value`, optional quotes, no
`export`, no `$` interpolation, no unquoted inline comments (`doctor.sh` validates this).

| Variable | Meaning |
|---|---|
| `COMPOSE_PROJECT_NAME` | Compose project (default `devstack`) |
| `EXAMPLE_APP_PORT` | Host port binding (127.0.0.1) |
| `DEVSTACK_PUBLISH_DATA_PORTS` | `true` publishes MariaDB/Redis (`MARIADB_HOST_PORT`, `REDIS_HOST_PORT`) |
| `DEVSTACK_*_MEMORY_LIMIT` | Per-class container memory limits |
| `MARIADB_ROOT_PASSWORD`, `EXAMPLE_APP_DB_PASSWORD`, `EXAMPLE_APP_TEST_DB_PASSWORD` | Database credentials (required) |
| `EXAMPLE_APP_ADMIN_PASSWORD` | Password for the local admin created by `seed.sh` |
| `DEVSTACK_REQUIRE_NPM_AUTH` | Make `setup.sh` verify private npm credentials |
| `DEVSTACK_NPM_REGISTRY` | Private npm registry base URL (only with `DEVSTACK_REQUIRE_NPM_AUTH=true`) |

## Application `.env`

`setup.sh` copies `templates/env/example-app.env` to `example-app/.env` if missing (never over
a Git-tracked `.env`). `validate-env.sh example-app <file>` enforces local-only hosts
(`mariadb`, `redis`, `localhost`), the `log`/`array` mailer, no object-storage settings, and empty
third-party credentials (any key ending in `_DSN`, `_API_KEY`, `_SECRET`, `_TOKEN` or `_WEBHOOK_URL`).
