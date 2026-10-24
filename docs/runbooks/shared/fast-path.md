---
id: RB-SHARED-FASTPATH
title: Fast path — fewer round trips, more signal per command
type: reference
domain: evidence
status: active
owner: platform
updated: undated
tags: [fast-path, triage, round-trips, correlation, prior-art, command-review, anonymisation]
symptoms: [slow investigation, many pastes, memory limit, traffic surge, service outage]
---

# Fast path — fewer round trips, more signal per command

> [Runbook index](../README.md) · Use before [RB-00/INC-04](../00-incident-intake.md#inc-04) routing and inside specialist runbooks. Evidence rules still come from [RB-01](../foundations/01-evidence-attribution.md) and [systematic debugging](debugging-method.md); this page changes the order and shape of collection.

Use prior evidence first, collect a bounded context bundle once, then run the command that separates the leading explanations. The [fictional high-memory route example](../incidents/example/conclusions.md) illustrates this method with synthetic data only.

## Rules for every round trip

1. **Search prior art before production.** Search the incident archive and supplied error reports using a symptom or route class. A known signature can select the next measurement without repeating broad sampling.
2. **Copy the evidence context once.** Record route class, first/last seen, event count, deployed revision, runtime SAPI, source identity and relevant trace fields. Redact identifiers while preserving evidence needed for correlation.
3. **Keep the action ledger current.** Record every restart, reload, block, cache operation or configuration edit with a relative sequence and actor role.
4. **Start with bounded context.** Use `incident-bundle.sh` to collect clock state, load, service model, worker state, backlog, OOM evidence, journal coverage, log coverage and runtime configuration. Every section is bounded and reports failure.
5. **Choose one discriminator.** For memory failures, correlate fatal bursts with nearby access failures. For traffic surges, compare endpoint classes and a reviewed first-party client signature. For upstream timeouts, count records in short slices and check for a cap.
6. **Preserve uncertainty.** A time-window join is a candidate relationship, user agents are self-declared, and current state does not establish historical state. Record what the command cannot prove.
7. **Stop when the next step needs authority.** Move to the execution gate before any production change or active probe.

## FP-0 — Prior art, no production access

```bash
grep -rniE '<symptom or route class>' docs/runbooks/incidents --include='*.md' | cut -c1-160
```

Read any matching evidence and its limitations. Treat generic examples as illustrative; do not infer that a current event has the same cause.

## FP-1 — One-paste context bundle

```bash
RB=docs/runbooks/shared/commands
sudo LOG_DIR=/var/log/apache2 APP_ROOT=/var/www/<app>/current \
  bash "$RB"/linux/incident-bundle.sh '<start>' '<end>'
```

The command collects host, service, worker, backlog, journal, log-coverage and runtime context. `ALLOW_ARTISAN=1` adds framework commands that boot the application and therefore need the [execution gate](recovery-evidence.md#execution-and-evidence-gates).

## FP-2 — One discriminator per symptom

| Symptom | Command | Reading rule |
| --- | --- | --- |
| Memory fatal on a route | `fatal-correlate.py` with explicit error-log offset and complete access/error inputs | A close 5xx/fatal pairing supports a candidate relationship; it does not identify one request without a shared ID |
| Traffic surge | `route-mix.sh` with reviewed endpoint classes and optional first-party user-agent pattern | Endpoint-class and client-pattern counts describe the observed logs; corroborate origin with an independent source |
| Edge timeout | Short platform-log slices with a record count | A count at the verified platform cap may mean truncated results; shorten the interval |
| Load follows configuration or cache activity | Compare change/action times with request and resource measurements | An event after onset is an amplifier, not a trigger |

### Memory failures: correlate fatal bursts with access failures

```bash
RB=docs/runbooks/shared/commands
sudo python3 -I "$RB"/apache/fatal-correlate.py --error-offset '<verified-offset>' \
  --error-log /var/log/apache2/error.log \
  --access-log /var/log/apache2/access.log
```

The helper groups fatal lines by process ID and a short burst, templates route identifiers, classifies callers and joins each fatal to an earlier access failure within a bounded interval. Use a fictional route such as `/example/export` in documentation and fixtures. Production output must be reviewed and redacted before sharing.

| Result | Interpretation |
| --- | --- |
| Fatal bursts repeatedly pair with failures on one route class | Supports investigating that route's work; source coverage and request identity remain limitations |
| Multiple first-allocation sites but one route class dominates | Allocation sites show where the limit was reached, not necessarily which component owns the memory |
| No matching application-log event | Check the runtime error sink and source coverage before concluding no failure occurred |
| Peer addresses identify a proxy | Do not label them as clients; use a verified forwarding chain or another source |

### Traffic surges: endpoint-class mix per minute

```bash
RB=docs/runbooks/shared/commands
sudo START_UTC='<start-utc>' END_UTC='<end-utc>' UA_MATCH='<reviewed-pattern>' \
  ROUTE_CLASSES='api=^/api/;export=^/example/export$;other-route=^/example/other$' \
  bash "$RB"/apache/route-mix.sh /var/log/apache2/access.log
```

`route-mix.sh` reports per-minute counts by configured class, an `other` class and an optional user-agent match. Class names and paths above are synthetic examples. A user agent is self-declared; corroborate first-party origin independently before treating a traffic pattern as internal.

## FP-3 — Reproduce one request, then stop

Only after the evidence identifies a route class and the execution gate approves the isolated target. Use a disposable working copy and data source, verify installed dependency versions, capture one cold request with errors on stderr, and record bounded phase checkpoints. Compare one warm request. Add concurrency only after single-request behavior is understood; do not use a single-process development server to infer production concurrency.

## Do not run

| Habit | Why it misleads | Run instead |
| --- | --- | --- |
| Repeated narrow samples before checking the full interval | Misses recurring patterns and wastes rounds | Verify source coverage, then aggregate the complete interval |
| Hashing request paths to anonymise them | Hides useful route classes and may require local reversal | Template identifiers while retaining reviewed static segments |
| Searching only the application log for runtime fatals | The runtime may write them to a server error log or tracker | Verify the actual error sink for the deployed SAPI |
| Matching a fatal to an access record at the exact second | Request receipt and fatal emission happen at different times | Use a bounded gap and label the relationship as a candidate |
| Treating proxy addresses or user agents as verified identity | Both can misrepresent the originating client | Use independent, trusted attribution evidence |
| Blocking a suspected client before dependency review | Can disable a first-party caller | Complete the blast-radius gate in [RB-10](../response/10-mitigation-recovery.md#mit-02) |
| Treating an empty result as proof of absence | It says nothing about missing, rotated or rejected inputs | Record input coverage and rejected-record counts |

## Keep the fast path honest

The sequence is a hypothesis about efficient investigation, not a measured speed-up. Validate it through blind replays using synthetic or approved redacted evidence. Record the time to the first discriminating observation, to a supported explanation and to a validated mitigation, along with redundant rounds and false hypotheses acted on. Update this page only when a review provides evidence for a better order.

## Stop conditions

Stop collecting when a supported explanation has its correlation evidence, the next distinction needs execution or change approval, or the next command would reread a source already summarised. Record the sequence in the incident's command review.
