# Defaults and Guards Template

Generic Bruno (OpenCollection) template showing three reusable patterns. Every value is invented and every host is a reserved placeholder.

1. **Layered defaults.** Environment values win. The collection `before-request` script fills only missing or invalid values, such as a date three days ahead and a locale-to-currency mapping. See `default-values.md`.
2. **Placeholder guard.** Health checks refuse to run against `*.invalid` hosts and require an `/api` suffix.
3. **Mutation gate.** Write requests run only when `environment_kind` is `local`, `test` or `staging` and `allow_mutations` is exactly `"true"`.

## Setup

1. Copy this directory outside the repo, for example `~/api-collections/defaults-and-guards`.
2. Copy `environments/local.yml.example` to `environments/local.yml`.
3. Set `baseUrl` and enter `api_key` in Bruno secret storage.
4. Run `meta/01-health-check` first.

## Security

- No real hosts, keys, customer data or identifiers are included.
- Keep `environments/local.yml` out of Git. The `.gitignore` covers it.
- Keep `allow_mutations` as `"false"` unless you deliberately run against a disposable environment.
