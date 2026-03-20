---
applyTo: 'app/Fieldtypes/**,app/Filters/**,app/Scopes/**,app/Searchables/**,app/Tags/**,app/Modifiers/**,content/**,resources/views/**,config/statamic/**'
description: 'Statamic 5 rules'
---

# Statamic 5 Rules

- Follow Statamic conventions: define content structure via blueprints and fieldsets, not custom DB schemas.
- Use Statamic Eloquent Driver for database-backed entries (configured via `statamic/eloquent-driver`).
- Use Runway for Eloquent model entries when non-Statamic models need CMS integration.
- Use Statamic's built-in Algolia search integration rather than custom implementations.
- Publish and override Statamic views in `resources/views/vendor/statamic` only when necessary.
- Do not bypass Statamic's content pipeline for routine content operations.
- Keep custom tags, modifiers, and fieldtypes in `app/Tags`, `app/Modifiers`, `app/Fieldtypes`.
- Access entries via `Entry::query()->where()->get()` or `Collection::findByHandle()` — never raw DB queries.
- Use Statamic's `{{ }}` Antlers templating only in `resources/views/`; prefer Blade for CP/admin views.
- Eloquent Driver entries are backed by the `entries` table — do not manually truncate or seed it.
