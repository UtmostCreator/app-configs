---
id: RB-SHARED-SERVICE-MAP
title: Service map (template)
type: reference
domain: architecture
status: template
owner: platform
updated: 2026-10-21
tags: [service-map, architecture, ubuntu, apache, netlify, redis, cms]
symptoms: [unknown environment, which host, which site]
---

# Service map

> [Runbook index](../README.md) · Used by [RB-00/INC-01](../00-incident-intake.md#inc-01) and [RB-09/CFG-01](../diagnostics/09-deployment-drift.md#cfg-01)

Fill this in per deployment. Use placeholders in the repository; keep real hostnames and account ids in your private inventory.

## Request path

```text
Browser -> CDN / Netlify edge -> Netlify SSR function -> CMS/API (Apache + PHP) -> Redis / database
                                                              ^
                                                   load balancer / trusted proxy
```

## Components

| Component | Where it runs | Logs | Cache layer | Owner |
| --- | --- | --- | --- | --- |
| Web frontend (SSR) | Netlify site `<site-name>` | Netlify function logs / log drain | CDN + SSR storage | `<team>` |
| CMS / API | Ubuntu `<host-role>` with Apache (prefork) + PHP | `/var/log/apache2/*.log`, `storage/logs/laravel.log` | Application cache + Redis | `<team>` |
| Redis | `<host-role>` | `journalctl -u redis-server` | n/a | `<team>` |
| Database | `<host-role>` | slow-query log | query cache n/a | `<team>` |
| Load balancer / proxy | `<provider>` | provider access logs | none | `<team>` |

## Environments

| Environment | URL | Host / site id | Deploys from |
| --- | --- | --- | --- |
| Production | `https://<site>` | `<host>` / `<site-id>` | `<branch>` |
| Staging | `https://<staging-site>` | `<host>` / `<site-id>` | `<branch>` |

## Related

[Thresholds](thresholds.md) · [Evidence schema](evidence-schema.md) · [RB-01 evidence](../foundations/01-evidence-attribution.md)
