---
applyTo: "tests/**"
description: "Testing rules for Laravel and PHPUnit"
---

# Testing Rules

- Use PHPUnit.
- Prefer the lowest test level that fully proves behavior.
- Unit: pure PHP logic, helpers, value objects.
- Feature: routes, controllers, middleware, validation, auth, DB-backed flows.
- Database: Eloquent scopes, relationships, casts, query behavior.
- Console: Artisan commands.
- Fake queues, events, notifications, and mail unless side effects are under test.
- For bug fixes, add the regression test first.
- Extend `Tests\TestCase` which uses `CreatesApplication`.
- Use `RefreshDatabase` for any test touching the DB.
- Use `WithFaker` (via `$this->faker`) for generated data; avoid hardcoded magic strings.
- Mock Statamic collections/entries using `Statamic::fake()` or repository fakes where supported.
- Test GraphQL queries via `$this->graphQL(...)` (rebing helper) or HTTP POST to `/graphql`.
- Feature tests for checkout/pricing flows live in `tests/Feature/`; mock external payment APIs.
