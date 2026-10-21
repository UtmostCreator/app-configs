# Default Values

Layered defaults keep requests runnable while staying editable in Bruno.

## Precedence (highest first)

1. Values edited directly on a request (query params, body).
2. The selected environment file (`environments/local.yml`).
3. Collection `before-request` fallback in `opencollection.yml`.
4. Request-specific fallback logic.

A valid, non-empty environment value always wins over the fallback. Clear a dynamic value to regenerate it on the next run.

## Variables

| Variable | Default | Allowed values | Set in |
|---|---|---|---|
| `baseUrl` | `https://api.example.invalid/api` (placeholder) | Host ending in `/api` | Environment |
| `api_key` | Empty (secret) | Environment-specific key | Bruno secret storage |
| `environment_kind` | `unset` | `local`, `test`, `staging` | Environment |
| `allow_mutations` | `"false"` | `"true"` or `"false"` | Environment |
| `item_id` | `ITEM-001` | Item identifiers | Environment |
| `item_date` | Today + 3 days when empty or invalid | `YYYY-MM-DD` | Collection script |
| `currency_code` | `region-a` | `region-a`, `region-b`, `region-c` | Environment |
| `item_currency` | Derived: `region-a`→`CUR-A`, `region-b`→`CUR-B`, `region-c`→`CUR-C` | Currency codes | Collection script |
| `quantity` | `"1"` when empty or invalid | Positive integer string | Collection script |
| `customer_email` | `user@example.com` | Valid email (placeholder only) | Environment |

## Guidance

- Derived values such as `item_currency` are regenerated. Change the source value instead.
- Keep fixtures generic. Never commit real customer data or production identifiers.
