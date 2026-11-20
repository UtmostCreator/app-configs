# Setup

> **Reference only, not runnable.** These pages describe a Docker Compose dev stack whose
> Compose files, `scripts/` and `tests/` are not in this repository. Commands and paths below
> refer to that stack, not to app-configs. Kept as written for reference (2026-11-20).

## Prerequisites

Docker Engine with Compose v2, `git`, `curl`, `awk`; `nc` is optional (port checks). Run
`./scripts/doctor.sh internal` to verify.

## First-time setup

```sh
cp .env.example .env              # replace every change-me value
./scripts/clone.sh internal
./scripts/setup.sh internal
```

`setup.sh` runs: doctor -> `.env` -> repo verification -> app `.env` from
`templates/env/example-app.env` -> env safety validation -> image build -> Composer cache
ownership -> infrastructure (+ MariaDB user reconciliation) -> Laravel runtime dirs ->
`install-deps.sh` -> `APP_KEY` -> `migrate.sh` -> `seed.sh` -> `up.sh --all` -> `smoke.sh --workers`.

The `DB_PASSWORD` in `example-app/.env` must equal `EXAMPLE_APP_DB_PASSWORD` in the stack `.env`.

## Daily commands

```sh
./scripts/up.sh internal --all     # start incl. queue worker
./scripts/logs.sh internal app
./scripts/smoke.sh internal --workers
./scripts/test.sh internal
./scripts/down.sh                  # add --volumes to drop data
```

## Databases

```sh
./scripts/export-db.sh example-app /absolute/path/dump.sql.gz
./scripts/import-db.sh example-app /absolute/path/dump.sql.gz
./scripts/reset-db.sh internal
```

Dumps can contain sensitive data; only import sanitized dumps.

## Private npm registry (optional)

Set `DEVSTACK_REQUIRE_NPM_AUTH=true` and `DEVSTACK_NPM_REGISTRY`, run `./scripts/setup-npm-auth.sh`
(token from `DEVSTACK_NPM_TOKEN` or a prompt), then re-run setup. The credential file lives in
`~/.config/devstack/npmrc`, outside the repo.
