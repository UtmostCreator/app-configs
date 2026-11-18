# Troubleshooting

| Symptom | Fix |
|---|---|
| `Port N (...) is already in use` from doctor | Change the port in `.env` or stop the other process |
| `set MARIADB_ROOT_PASSWORD in .env` from compose | Copy `.env.example` to `.env` and fill the password variables |
| `Unsafe application environment` | Fix the settings `validate-env.sh` lists in `example-app/.env` |
| `Pending migrations detected` | Run `./scripts/migrate.sh internal` before starting workers |
| App cannot connect to MariaDB | `DB_PASSWORD` in `example-app/.env` must match `EXAMPLE_APP_DB_PASSWORD`; run `setup.sh` again to reconcile users |
| Composer cache permission errors | Re-run `setup.sh` (reconciles `/tmp/composer` ownership) or set `LOCAL_UID`/`LOCAL_GID` |
| `origin ... does not match manifest` | The checkout's `origin` differs from `config/repositories.yml` |
| Reset everything | `./scripts/down.sh --volumes` then `./scripts/setup.sh internal` |
