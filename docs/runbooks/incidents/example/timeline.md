---
id: INC-2026-10-13-timeline
title: 2026-10-13 incident — Timeline
type: incident-evidence
domain: incident-history
status: under-review
owner: platform
updated: 2026-10-21
tags: [incident, timeline, apache, netlify, oom, cache]
symptoms: [AH00161, oom-kill, 504, cache-clear, purge-storm, token-in-url]
---

# Timeline

> [Incident archive](../README.md) · [Runbook index](../../README.md)

All times UTC. Platform logs and server logs share UTC; local-time monitors are +1 h.

| UTC         | Event                                                                                                | Step                                                                | Status      |
| ----------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | ----------- |
| 00:00–02:19 | PHP memory-limit failures already recurring                                                          | [RB-04/APP-01](../../diagnostics/04-laravel.md#app-01)              | observation |
| 01:00–02:00 | Bulk sync job on the same host writes tens of thousands of log lines                                 | [RB-03/CAP-05](../../diagnostics/03-apache-capacity.md#cap-05)      | observation |
| 03:00       | Scheduled application cache clear (Redis cache store)                                                | [RB-06/CCH-01](../../diagnostics/06-cache-invalidation.md#cch-01)   | observation |
| 03:02–03:04 | Web request log lines drop sharply while caches rebuild                                              | [RB-02/TRF-01](../../diagnostics/02-apache-traffic.md#trf-01)       | observation |
| ~03:05      | Kernel OOM kills of three Apache processes within ~35 s                                              | [RB-03/CAP-03](../../diagnostics/03-apache-capacity.md#cap-03)      | observation |
| 03:05–05:37 | No web traffic served (~2.5 h); scheduled jobs still logged                                          | [RB-03/CAP-06](../../diagnostics/03-apache-capacity.md#cap-06)      | observation |
| 05:37       | Apache started after an unclean shutdown                                                             | [RB-03/CAP-06](../../diagnostics/03-apache-capacity.md#cap-06)      | observation |
| 05:39       | Apache reaches `MaxRequestWorkers` (`AH00161`)                                                       | [RB-03/CAP-03](../../diagnostics/03-apache-capacity.md#cap-03)      | observation |
| ~08:17      | Surge in SSR function activity begins; trigger unverified                                            | [RB-05/NET-02](../../diagnostics/05-netlify-ssr-cdn.md#net-02)      | observation |
| 08:18:30    | Sampled SSR executions mostly over 5 s, longest ~30 s                                                | [RB-05/NET-02](../../diagnostics/05-netlify-ssr-cdn.md#net-02)      | observation |
| 08:28–08:38 | ~27k completed backend requests (~41/s); 98% HTTP 200, no 5xx logged                                 | [RB-02/TRF-02](../../diagnostics/02-apache-traffic.md#trf-02)       | observation |
| 08:50–09:34 | 17 whole-site CDN purges, tracking editorial saves                                                   | [RB-06/CCH-07](../../diagnostics/06-cache-invalidation.md#cch-07)   | observation |
| 09:27–09:34 | Edge block on the `node` user agent; frontend breaks; purge and clear calls time out; block reverted | [RB-08/DEP-03](../../diagnostics/08-service-dependencies.md#dep-03) | observation |

See also: [timeline](timeline.md) · [observations](observations.md) · [hypotheses](hypotheses.md) · [actions](actions.md) · [conclusions](conclusions.md)
