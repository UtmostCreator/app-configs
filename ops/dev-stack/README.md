# Dev Stack

Docker-based local development stack for a single example PHP (Laravel) project, with MariaDB,
and Redis. It is an anonymized, trimmed reference of a larger multi-repo stack:
every setup step, smoke check, clone and test script is kept, but works against one app.

## Layout

```text
config/repositories.yml   profile -> repo manifest (one repo: example-app)
docker/                   Compose files, image Dockerfiles, nginx and MariaDB init
scripts/                  POSIX sh entry points (setup, up, down, smoke, doctor, ...)
scripts/lib/              shared helpers (env parsing, compose wrapper, repo checks)
templates/env/            application .env template copied by setup.sh
tests/                    fixture tests; run with `sh tests/run.sh`
docs/                     architecture, setup, environment, troubleshooting, images
```

The stack expects the application checkout next to this directory: `../example-app`
(created by `scripts/clone.sh`). Only POSIX `sh`/Bash scripts are included; there are no
PowerShell or Windows batch entry points.

## Quick start

```sh
cp .env.example .env            # then replace every change-me value
./scripts/doctor.sh internal    # prerequisites, ports, compose validation
./scripts/clone.sh internal     # clone example-app (git@github.com:example-org/example-app.git)
./scripts/setup.sh internal     # env, build, infra, deps, migrate, seed, start, smoke
```

Linux one-shot: `./scripts/bootstrap-linux.sh internal [--clean]`.

## Scripts

| Script | Purpose |
|---|---|
| `doctor.sh` | Check Docker, Compose v2, git, ports, `.env` grammar, compose config |
| `clone.sh` | Clone/verify repositories from `config/repositories.yml` (`--update`, `--branch`) |
| `setup.sh` | Full first-time setup (`--force-env`, `--skip-build`) |
| `up.sh` / `down.sh` / `restart.sh` | Start (`--workers`/`--all`), stop (`--volumes`), restart |
| `logs.sh` | Follow logs for all services or one service |
| `install-deps.sh` | `composer install` through the tools container |
| `migrate.sh` / `seed.sh` | Run migrations / seed data and create the local admin |
| `smoke.sh` | HTTP, TCP and worker checks (`--connectivity`, `--workers`, `--external-check`) |
| `test.sh` | Run the app test suite against an isolated MariaDB |
| `export-db.sh` / `import-db.sh` / `reset-db.sh` | Dump, restore and recreate local databases |
| `switch-branch.sh` | Switch a repo to its configured or a given branch |
| `php-settings.sh`, `snapshot.sh` | Inspect effective PHP settings; write a stack snapshot |
| `validate-compose.sh`, `validate-env.sh`, `verify-images.sh` | Safety and reproducibility checks |
| `setup-npm-auth.sh` | Create a private npm registry credential file (token never stored in the repo) |

## Secrets

No credentials are stored here. `.env` is git-ignored; `.env.example` only contains `change-me`
placeholders. Compose requires the password variables (`${VAR:?...}`), so the stack will not
start with them unset.
