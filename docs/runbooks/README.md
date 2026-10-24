---
id: RB-INDEX
title: Incident runbooks index and decision router
type: index
domain: incident-response
status: active
owner: platform
updated: undated
tags: [runbooks, index, router, ubuntu, apache, netlify, access-logs, incident-response]
symptoms: [504, AH00161, oom-kill, traffic spike, high load, cache stampede]
---

# Incident runbooks

Modular, cross-linked runbooks for investigating a web server, an SSR frontend and the access/error logs between them. Start at [RB-00](00-incident-intake.md) or use the symptom router below. Before the first production command, run the [fast path](shared/fast-path.md) prior-art check. Search by `id`, `tags` or `symptoms` in each file's frontmatter (for example `grep -rl "AH00161" docs/runbooks`).

## Symptom router

| Strongest symptom                                          | Start at                                                      |
| ---------------------------------------------------------- | ------------------------------------------------------------- |
| 504 / 502 / SSR timeout / CDN errors                       | [RB-05/NET-01](diagnostics/05-netlify-ssr-cdn.md#net-01)      |
| `AH00161`, OOM kill, `Killed process`, 503 from Apache     | [RB-03/CAP-01](diagnostics/03-apache-capacity.md#cap-01)      |
| Traffic spike or unexpected request volume                 | [RB-02/TRF-01](diagnostics/02-apache-traffic.md#trf-01)       |
| PHP/Laravel exception, `Allowed memory size`               | [RB-04/APP-01](diagnostics/04-laravel.md#app-01)              |
| Load right after a cache clear, repeated upstream fetches  | [RB-06/CCH-01](diagnostics/06-cache-invalidation.md#cch-01)   |
| Exposed secret or credential                               | [RB-07/SEC-01](diagnostics/07-traffic-security.md#sec-01)     |
| Checkout or frontend journey broken                        | [RB-08/DEP-03](diagnostics/08-service-dependencies.md#dep-03) |
| Started right after a deploy or config change              | [RB-09/CFG-04](diagnostics/09-deployment-drift.md#cfg-04)     |
| No log matches, wrong client IPs, timezone confusion       | [RB-01/EVD-01](foundations/01-evidence-attribution.md#evd-01) |
| Need to change production (restart, WAF, rotate, rollback) | [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01)     |
| Verify recovery or close the incident                      | [RB-11/VAL-01](response/11-validation-review.md#val-01)       |
| Service stayed down for hours with no restart or alert     | [RB-03/CAP-06](diagnostics/03-apache-capacity.md#cap-06)      |
| Purge or cache-clear storms, `removed: []`                 | [RB-06/CCH-07](diagnostics/06-cache-invalidation.md#cch-07)   |
| Error tracker or archive already names a route or pattern  | [Fast path FP-2](shared/fast-path.md#fp-2--one-discriminator-per-symptom) |
| "Is it a DDoS?" with a load balancer in front              | [Fast path FP-2](shared/fast-path.md#fp-2--one-discriminator-per-symptom), then [RB-02/TRF-04](diagnostics/02-apache-traffic.md#trf-04) |
| Not sure where to start                                    | [RB-00/INC-01](00-incident-intake.md#inc-01)                  |

## Catalogue

For installed Ubuntu tools, pressure/cgroup measurements, bounded sampling and optional historical collection, use [Practical evidence capture on Ubuntu servers](shared/ubuntu-evidence.md).

| ID    | Runbook                                                                                       | Priority | Steps | Mode               |
| ----- | --------------------------------------------------------------------------------------------- | -------- | ----- | ------------------ |
| RB-00 | [Incident intake and decision routing](00-incident-intake.md)                                 | P0       | 5     | read-only          |
| RB-01 | [Evidence, timestamps and proxy attribution](foundations/01-evidence-attribution.md)          | P0       | 5     | read-only          |
| RB-02 | [Apache traffic and HTTP request investigation](diagnostics/02-apache-traffic.md)             | P0       | 6     | read-only          |
| RB-03 | [Apache capacity, CPU, memory and OOM](diagnostics/03-apache-capacity.md)                     | P0       | 7     | read-only          |
| RB-04 | [Laravel application failures](diagnostics/04-laravel.md)                                     | P0       | 5     | read-only          |
| RB-05 | [Netlify SSR, CDN and request-routing failures](diagnostics/05-netlify-ssr-cdn.md)            | P0       | 7     | read-only          |
| RB-06 | [Cache invalidation, stampedes and regeneration](diagnostics/06-cache-invalidation.md)        | P0       | 8     | read-only          |
| RB-07 | [Traffic abuse, WAF and security exposure](diagnostics/07-traffic-security.md)                | P1       | 6     | read-only          |
| RB-08 | [Frontend and backend service dependencies, checkout](diagnostics/08-service-dependencies.md) | P1       | 5     | read-only          |
| RB-09 | [Deployment, environment and configuration drift](diagnostics/09-deployment-drift.md)         | P1       | 5     | read-only          |
| RB-10 | [Safe mitigation, recovery and rollback](response/10-mitigation-recovery.md)                  | P0       | 6     | changes production |
| RB-11 | [Regression validation and post-incident review](response/11-validation-review.md)            | P1       | 6     | passive evidence / isolated staging tests |

P0 is required for core triage and recovery; P1 is specialised investigation or validation.

## Rules

- **RB-00 to RB-09 use passive inspection by default.** Configuration edits, cache clears, restarts, WAF changes and token rotation belong to [RB-10](response/10-mitigation-recovery.md) behind approval and rollback. Credential exposure is escalated to the incident owner immediately; authorisation must never delay notification.
- **Evidence before conclusions.** Verify host, UTC window, retention and proxy attribution ([RB-01](foundations/01-evidence-attribution.md)) first. "No log matches" is not "no event".
- **One owner per domain.** A step hands off to a specialist step and records where to return; the caller keeps its context.
- **Hypotheses stay hypotheses.** A cache clear or deploy that _precedes_ a failure is a causal hypothesis until controlled evidence shows it caused it.
- **No secrets in notes.** Record counts, locations and key names, never values.
- **Fewest round trips.** Prior art and local exports first; one paste per question set; whole interval before windows; route templates and caller classes instead of hashes ([fast path](shared/fast-path.md)). Every closed incident records response metrics in a [command review](incidents/_template/command-review.md); severe, misdiagnosed, recurring or long (> 10 rounds) investigations get the full round-by-round review.

## Navigation model

Runbooks call each other with explicit return points; they are not a linear sequence.

```text
RB-03/CAP-03 -> RB-04/APP-01 -> RB-04/APP-03 -> RB-06/CCH-03 -> RB-06/CCH-05
        return -> RB-04/APP-04 -> RB-03/CAP-05 -> RB-10/MIT-01 -> RB-11/VAL-06
```

Apply the shared [execution and evidence gates](shared/recovery-evidence.md#execution-and-evidence-gates) at every handoff. Unknown evidence can route to further diagnosis, but cannot satisfy an approval, attribution, recovery or closure gate.

Every step uses the same contract: Objective, Mode, Preconditions, Commands, Expected output, Decision table, Evidence to record, Return. Shared unknown-result handling is stated once per runbook; specialised unknown branches remain beside their step. Step headings are just the ID (`## CAP-03`), so anchors (`#cap-03`) stay stable when titles change.

## Worked routes

**A. PHP memory failure on an export route** — [fast path](shared/fast-path.md) → [RB-04/APP-01](diagnostics/04-laravel.md#app-01) → [RB-04/APP-03](diagnostics/04-laravel.md#app-03) → [RB-04/APP-04](diagnostics/04-laravel.md#app-04) → [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01). Exercise: [fictional incident](incidents/example/conclusions.md).

**B. Morning Netlify 504s** — [RB-00/INC-04](00-incident-intake.md#inc-04) → [RB-05/NET-01](diagnostics/05-netlify-ssr-cdn.md#net-01) → [RB-05/NET-02](diagnostics/05-netlify-ssr-cdn.md#net-02) → [RB-05/NET-04](diagnostics/05-netlify-ssr-cdn.md#net-04) → [RB-08/DEP-01](diagnostics/08-service-dependencies.md#dep-01) → [RB-06/CCH-03](diagnostics/06-cache-invalidation.md#cch-03) → [RB-06/CCH-05](diagnostics/06-cache-invalidation.md#cch-05) → [RB-09/CFG-01](diagnostics/09-deployment-drift.md#cfg-01) → [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01) → [RB-11/VAL-02](response/11-validation-review.md#val-02)

**C. Someone proposes blocking a user agent** — [RB-02/TRF-03](diagnostics/02-apache-traffic.md#trf-03) → [RB-07/SEC-02](diagnostics/07-traffic-security.md#sec-02) → [RB-07/SEC-03](diagnostics/07-traffic-security.md#sec-03) → [RB-08/DEP-01](diagnostics/08-service-dependencies.md#dep-01) → [RB-08/DEP-03](diagnostics/08-service-dependencies.md#dep-03) → reject a blanket block via [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01), or if abuse is independently verified: [RB-07/SEC-04](diagnostics/07-traffic-security.md#sec-04) → [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01) → complete the approval, preparation and monitored application sequence → [RB-11/VAL-03](response/11-validation-review.md#val-03)

**D. PHP `Allowed memory size` on a route** — [fast path FP-0](shared/fast-path.md#fp-0--prior-art-no-production-access) → [FP-1](shared/fast-path.md#fp-1--one-paste-context-bundle) → [RB-04/APP-01](diagnostics/04-laravel.md#app-01) (`fatal-correlate.py`) → [RB-04/APP-03](diagnostics/04-laravel.md#app-03) → [RB-04/APP-04](diagnostics/04-laravel.md#app-04) (one-request reproduction) → [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01). See the [fictional exercise](incidents/example/conclusions.md).

## Common wrong conclusions

| Tempting conclusion                                              | Correction                                                                                                                                                           |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A cache clear caused the outage                                  | Sequence may be confirmed; keep causal uncertainty until controlled evidence exists ([RB-06](diagnostics/06-cache-invalidation.md))                                  |
| A deploy started the surge                                       | Hypothesis; the trigger stays unverified until deploy and request timelines are aligned ([RB-09](diagnostics/09-deployment-drift.md))                                |
| An empty purge result (`removed: []`) proves caches are unshared | It only means no matching keys were visible to that instance                                                                                                         |
| A dominant user agent means an attack                            | A user agent alone is not attribution; check first-party SSR first ([RB-08](diagnostics/08-service-dependencies.md))                                                 |
| Many HTTP 200s mean healthy                                      | Include latency, saturation and application-level errors                                                                                                             |
| More Apache workers will fix it                                  | Needs a memory model first ([RB-03](diagnostics/03-apache-capacity.md))                                                                                              |
| No log match means no event                                      | Check rotation, retention, source and timezone ([RB-01](foundations/01-evidence-attribution.md))                                                                     |
| The local branch is production                                   | Verify the deployed revision and effective config ([RB-09](diagnostics/09-deployment-drift.md))                                                                      |
| Excluding a health-checker user agent is enough                  | Also validate peer, route and expected behaviour                                                                                                                     |
| Blocking IPs or user agents is a diagnostic step                 | Production changes go through [RB-10](response/10-mitigation-recovery.md)                                                                                            |
| A purge or deploy started the surge                              | Check onset against the first purge/deploy: purges that start after onset are amplifiers, not triggers ([RB-06/CCH-07](diagnostics/06-cache-invalidation.md#cch-07)) |
| `cache:clear` only removes prefixed keys                         | With a Redis store the framework flush runs `FLUSHDB` on the selected database ([RB-06/CCH-01](diagnostics/06-cache-invalidation.md#cch-01))                         |
| Restarting Apache fixed the memory problem                       | If the same PHP memory failure follows each restart, the cause is the workload ([RB-03/CAP-06](diagnostics/03-apache-capacity.md#cap-06))                            |
| Plenty of free RAM now means no OOM happened                     | A later snapshot does not describe the failure moment ([RB-03](diagnostics/03-apache-capacity.md))                                                                   |
| A drop in completed SSR requests means fewer visitors            | Verify timestamp semantics and pending work; completed-request volume alone cannot establish visitor demand ([RB-05/NET-02](diagnostics/05-netlify-ssr-cdn.md#net-02))                                          |
| A platform log query with no later errors means no errors        | The CLI returns a limited batch: shorten the window and recount ([RB-01/EVD-03](foundations/01-evidence-attribution.md#evd-03))                                      |
| The environment flag is true, so caching is on                   | The flag may be evaluated at build time ([RB-09/CFG-03](diagnostics/09-deployment-drift.md#cfg-03))                                                                  |
| No memory fatal in `laravel.log` means none happened             | Under `mod_php` fatals reach the Apache error log and error tracker; the application log depends on the release ([RB-04/APP-01](diagnostics/04-laravel.md#app-01)) |
| Two fatal lines with one PID are one request                     | PIDs are reused; group by PID **and** a sub-second burst, then join to access 5xx with a gap window ([fast path](shared/fast-path.md#memory-failures-correlate-fatal-bursts-with-access-failures)) |
| Hashing paths keeps the analysis anonymous and useful            | It can hide useful route classes and cost a round to reverse; template identifiers instead |
| Zero origin 5xx means the backend is fine                        | Edge 504s at ~30 s with origin 200s mean queueing; check listen backlog and worker states ([RB-03/CAP-01](diagnostics/03-apache-capacity.md#cap-01)) |
| A token in a query string is fine if the endpoint is internal    | It is written to access and application logs: treat as exposed ([RB-07/SEC-01](diagnostics/07-traffic-security.md#sec-01))                                           |

## Shared material

- [Technical review corrections and acceptance evidence](shared/technical-review-status.md) — local checks versus required deployed-service validation
- [Recovery evidence and execution gates](shared/recovery-evidence.md) · [Isolated single-flight protocol](shared/single-flight-validation.md)
- [Systematic debugging and reliable log analysis](shared/debugging-method.md) — hypotheses, parser checks, shell failures, timing and performance measurements
- [Service map](shared/service-map.md) · [Thresholds](shared/thresholds.md) · [Evidence schema](shared/evidence-schema.md)
- [Netlify log queries](shared/netlify-log-queries.md) — truncation-safe log retrieval and observability reading rules
- [Fast path](shared/fast-path.md) — fewer round trips: prior art, one-paste bundle, one discriminating command per symptom, do-not-run list
- [Command helpers](shared/commands/README.md) — read-only scripts for Apache, Linux, Netlify and Laravel logs
- [Incident archive](incidents/README.md) — historical evidence by event; never rewritten as definitive root causes

## Step index

| Step                                                          | Runbook | Title                                                                        |
| ------------------------------------------------------------- | ------- | ---------------------------------------------------------------------------- |
| [RB-00/INC-01](00-incident-intake.md#inc-01)                  | RB-00   | Identify affected service, environment and customer impact                   |
| [RB-00/INC-02](00-incident-intake.md#inc-02)                  | RB-00   | Record UTC start time, symptoms and incident window                          |
| [RB-00/INC-03](00-incident-intake.md#inc-03)                  | RB-00   | Determine whether the incident is ongoing                                    |
| [RB-00/INC-04](00-incident-intake.md#inc-04)                  | RB-00   | Route by the strongest symptom                                               |
| [RB-00/INC-05](00-incident-intake.md#inc-05)                  | RB-00   | Reassess after specialist investigation and close                            |
| [RB-01/EVD-01](foundations/01-evidence-attribution.md#evd-01) | RB-01   | Verify host, service, environment and log files                              |
| [RB-01/EVD-02](foundations/01-evidence-attribution.md#evd-02) | RB-01   | Normalise timestamps to UTC and validate the window                          |
| [RB-01/EVD-03](foundations/01-evidence-attribution.md#evd-03) | RB-01   | Check rotated logs, retention and missing records                            |
| [RB-01/EVD-04](foundations/01-evidence-attribution.md#evd-04) | RB-01   | Identify load balancers, trusted proxies and real client IP handling         |
| [RB-01/EVD-05](foundations/01-evidence-attribution.md#evd-05) | RB-01   | Produce the normalised evidence set and return                               |
| [RB-02/TRF-01](diagnostics/02-apache-traffic.md#trf-01)       | RB-02   | Calculate requests per minute and compare with baseline                      |
| [RB-02/TRF-02](diagnostics/02-apache-traffic.md#trf-02)       | RB-02   | Analyse HTTP status distribution                                             |
| [RB-02/TRF-03](diagnostics/02-apache-traffic.md#trf-03)       | RB-02   | Identify top IPs, URLs, methods and user agents                              |
| [RB-02/TRF-04](diagnostics/02-apache-traffic.md#trf-04)       | RB-02   | Isolate dynamic routes and suspicious request patterns                       |
| [RB-02/TRF-05](diagnostics/02-apache-traffic.md#trf-05)       | RB-02   | Correlate suspicious traffic with server errors and latency                  |
| [RB-02/TRF-06](diagnostics/02-apache-traffic.md#trf-06)       | RB-02   | Route to the owning runbook                                                  |
| [RB-03/CAP-01](diagnostics/03-apache-capacity.md#cap-01)      | RB-03   | Inspect live CPU, memory, process count and load                             |
| [RB-03/CAP-02](diagnostics/03-apache-capacity.md#cap-02)      | RB-03   | Inspect MaxRequestWorkers, MPM and active worker metrics                     |
| [RB-03/CAP-03](diagnostics/03-apache-capacity.md#cap-03)      | RB-03   | Examine Apache logs and kernel OOM events                                    |
| [RB-03/CAP-04](diagnostics/03-apache-capacity.md#cap-04)      | RB-03   | Distinguish worker saturation, host OOM and PHP memory exhaustion            |
| [RB-03/CAP-05](diagnostics/03-apache-capacity.md#cap-05)      | RB-03   | Correlate with requests, scheduled jobs and application operations           |
| [RB-03/CAP-06](diagnostics/03-apache-capacity.md#cap-06)      | RB-03   | Check service recovery behaviour and monitoring gaps                         |
| [RB-03/CAP-07](diagnostics/03-apache-capacity.md#cap-07)      | RB-03   | Route to the owning runbook                                                  |
| [RB-04/APP-01](diagnostics/04-laravel.md#app-01)              | RB-04   | Locate Laravel, PHP and CMS exceptions                                       |
| [RB-04/APP-02](diagnostics/04-laravel.md#app-02)              | RB-04   | Group failures by request context, stack trace and component                 |
| [RB-04/APP-03](diagnostics/04-laravel.md#app-03)              | RB-04   | Investigate GraphQL, navigation, augmentation, structures and content APIs   |
| [RB-04/APP-04](diagnostics/04-laravel.md#app-04)              | RB-04   | Identify expensive queries, synchronous dependencies and repeated work       |
| [RB-04/APP-05](diagnostics/04-laravel.md#app-05)              | RB-04   | Route caching, dependency and capacity findings                              |
| [RB-05/NET-01](diagnostics/05-netlify-ssr-cdn.md#net-01)      | RB-05   | Measure 500/502/503/504 counts, durations and affected URLs                  |
| [RB-05/NET-02](diagnostics/05-netlify-ssr-cdn.md#net-02)      | RB-05   | Sample short windows around onset to size the change                         |
| [RB-05/NET-03](diagnostics/05-netlify-ssr-cdn.md#net-03)      | RB-05   | Correlate CDN misses and function invocations                                |
| [RB-05/NET-04](diagnostics/05-netlify-ssr-cdn.md#net-04)      | RB-05   | Inspect slow functions and outgoing CMS requests                             |
| [RB-05/NET-05](diagnostics/05-netlify-ssr-cdn.md#net-05)      | RB-05   | Verify whether legacy image and static URLs reach SSR middleware             |
| [RB-05/NET-06](diagnostics/05-netlify-ssr-cdn.md#net-06)      | RB-05   | Check deployment and published configuration                                 |
| [RB-05/NET-07](diagnostics/05-netlify-ssr-cdn.md#net-07)      | RB-05   | Route upstream amplification, cache misses and widespread failure            |
| [RB-06/CCH-01](diagnostics/06-cache-invalidation.md#cch-01)   | RB-06   | Identify scheduled and event-driven cache-clearing operations                |
| [RB-06/CCH-02](diagnostics/06-cache-invalidation.md#cch-02)   | RB-06   | Map Redis, CMS, SSR storage and CDN caches independently                     |
| [RB-06/CCH-03](diagnostics/06-cache-invalidation.md#cch-03)   | RB-06   | Measure cache misses and duplicate upstream fetches                          |
| [RB-06/CCH-04](diagnostics/06-cache-invalidation.md#cch-04)   | RB-06   | Examine GraphQL, redirects and navigation cache-key correctness              |
| [RB-06/CCH-05](diagnostics/06-cache-invalidation.md#cch-05)   | RB-06   | Investigate stampedes and concurrency coordination                           |
| [RB-06/CCH-06](diagnostics/06-cache-invalidation.md#cch-06)   | RB-06   | Verify invalidation coverage, job deduplication and purge responses          |
| [RB-06/CCH-07](diagnostics/06-cache-invalidation.md#cch-07)   | RB-06   | Count purge storms and correlate with editorial activity and load            |
| [RB-06/CCH-08](diagnostics/06-cache-invalidation.md#cch-08)   | RB-06   | Route fixes and tests                                                        |
| [RB-07/SEC-01](diagnostics/07-traffic-security.md#sec-01)     | RB-07   | Investigate exposed secrets and cache-invalidation credentials               |
| [RB-07/SEC-02](diagnostics/07-traffic-security.md#sec-02)     | RB-07   | Correlate suspected bot traffic with verified IP attribution and behaviour   |
| [RB-07/SEC-03](diagnostics/07-traffic-security.md#sec-03)     | RB-07   | Identify first-party automation and critical dependencies before blocking    |
| [RB-07/SEC-04](diagnostics/07-traffic-security.md#sec-04)     | RB-07   | Evaluate protective controls, rotation and false-positive risk               |
| [RB-07/SEC-05](diagnostics/07-traffic-security.md#sec-05)     | RB-07   | Verify authentication of operational endpoints fails closed                  |
| [RB-07/SEC-06](diagnostics/07-traffic-security.md#sec-06)     | RB-07   | Require an authorised change and validate                                    |
| [RB-08/DEP-01](diagnostics/08-service-dependencies.md#dep-01) | RB-08   | Trace browser to SSR to CMS API request chains                               |
| [RB-08/DEP-02](diagnostics/08-service-dependencies.md#dep-02) | RB-08   | Verify checkout, GraphQL, redirect, localisation and navigation dependencies |
| [RB-08/DEP-03](diagnostics/08-service-dependencies.md#dep-03) | RB-08   | Determine whether a blocked or unavailable service breaks critical flows     |
| [RB-08/DEP-04](diagnostics/08-service-dependencies.md#dep-04) | RB-08   | Distinguish normal SSR-generated requests from unauthorised requests         |
| [RB-08/DEP-05](diagnostics/08-service-dependencies.md#dep-05) | RB-08   | Route to the failing layer                                                   |
| [RB-09/CFG-01](diagnostics/09-deployment-drift.md#cfg-01)     | RB-09   | Verify the affected production site and deployment                           |
| [RB-09/CFG-02](diagnostics/09-deployment-drift.md#cfg-02)     | RB-09   | Compare deployed revision with locally inspected code                        |
| [RB-09/CFG-03](diagnostics/09-deployment-drift.md#cfg-03)     | RB-09   | Confirm effective configuration flags and cache settings                     |
| [RB-09/CFG-04](diagnostics/09-deployment-drift.md#cfg-04)     | RB-09   | Correlate deployment events with the incident timeline                       |
| [RB-09/CFG-05](diagnostics/09-deployment-drift.md#cfg-05)     | RB-09   | Return confirmed differences; route rollback candidates                      |
| [RB-10/MIT-01](response/10-mitigation-recovery.md#mit-01)     | RB-10   | Define the immediate mitigation and alternatives                             |
| [RB-10/MIT-02](response/10-mitigation-recovery.md#mit-02)     | RB-10   | Check approval, production permissions and collateral damage                 |
| [RB-10/MIT-03](response/10-mitigation-recovery.md#mit-03)     | RB-10   | Prepare change, monitoring, rollback and dependency validation               |
| [RB-10/MIT-04](response/10-mitigation-recovery.md#mit-04)     | RB-10   | Apply only the authorised mitigation                                         |
| [RB-10/MIT-05](response/10-mitigation-recovery.md#mit-05)     | RB-10   | Monitor for regressions, new errors and overload                             |
| [RB-10/MIT-06](response/10-mitigation-recovery.md#mit-06)     | RB-10   | Restore the previous state if rollback conditions are met                    |
| [RB-11/VAL-01](response/11-validation-review.md#val-01)       | RB-11   | Check service health, latency, error rates and resource consumption          |
| [RB-11/VAL-02](response/11-validation-review.md#val-02)       | RB-11   | Run cache correctness, concurrency and failure-handling tests                |
| [RB-11/VAL-03](response/11-validation-review.md#val-03)       | RB-11   | Check authentication, rate limiting and legitimate-user access               |
| [RB-11/VAL-04](response/11-validation-review.md#val-04)       | RB-11   | Verify frontend, CMS and checkout end-to-end journeys                        |
| [RB-11/VAL-05](response/11-validation-review.md#val-05)       | RB-11   | Compare measured results with baseline and acceptance criteria               |
| [RB-11/VAL-06](response/11-validation-review.md#val-06)       | RB-11   | Record outcomes, unresolved hypotheses and follow-ups                        |

## Maintenance

Validate links, step anchors and frontmatter after any edit:

```bash
bash docs/runbooks/shared/commands/validate-runbook-links.sh   # frontmatter, links, anchors, step references
bash docs/runbooks/shared/commands/check-anonymized.sh          # no real IPs, hosts, emails, paths, ticket ids or tokens
```

All examples use placeholders (`<site>`, `<host>`, `<load-balancer-private-address>`), `localhost`/`127.0.0.1`, RFC 5737 documentation addresses and `example.*` domains. Never paste real hostnames, addresses, tokens or customer data into this tree.
