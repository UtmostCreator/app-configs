# ADR 0001: Improve diagnostic evidence through existing tools and runbooks

- Status: Proposed
- Scope: Review and architectural proposal only; implementation requires separate work.
- Reviewed repository: the app-configs project before the bounded implementation work.

## Context and review evidence

The supplied recommendations favour reliable health results, historical Linux metrics,
resource pressure and easier runbook discovery. These fit the existing helpers better
than introducing another monitoring platform. The supplied 280-reference collection
was not available for this review; its completeness and numerical value scores are
not independently established.

Source inspection found:

- [The health runner](../../../ops/projects/health/run.sh) discards child exit codes
  and stderr. It counts records by status without validating their shape or confirming
  that expected results arrived. Empty input can aggregate to `ok`. Its `--json`
  branch also omits `final_exit`, contrary to the documented exit contract.
- [The process check](../../../ops/projects/health/checks.d/30-process.sh) accepts
  either a command-line regex match or an executable-name match. An unrelated process
  can therefore satisfy it; a project ID inside a command line is not reliable identity.
- [Project selection](../../../ops/projects/health/lib.sh) means HTTP and process
  scripts emit one record per enabled project, potentially zero or several. Requiring
  exactly one record per script, or failing every empty script, would be incorrect.
  [Configuration reads](../../../ops/projects/lib.sh) also suppress some parser errors;
  configuration validity must be established before deriving expected checks.
- [RB-03](../../runbooks/diagnostics/03-apache-capacity.md) already describes retained
  `sar`/`sadf` data, `pidstat`, `iostat`, and the execution review required for profiling.
  No `sysstat` declaration was found in the inspected Nix modules or mise configuration.
  This does not establish whether any deployed host has tools or retained samples.
- [The memory snapshot](../../runbooks/shared/commands/linux/memory-snapshot.sh)
  collects current memory, load and processes, but not `/proc/pressure/*`.
- `navi` is already declared in [CLI packages](../../../nix/modules/home/cli.nix)
  and the [optional mise task](../../../mise.toml). No runbook cheatsheets were found
  in the inspected managed files. Package declarations do not prove installation.

The GitHub `main` health runner was also read and matched the reviewed local runner.
Other observations refer to the pinned local snapshot, not an assertion that every
file matches the latest remote branch. No host diagnostics or health checks were run.
The existing untracked `docs/runbooks/investigation-v1.md` was excluded from the review.

## Decision

Propose the following bounded changes, in the order shown. Complexity is an engineering
estimate for the stated scope, including compatibility and focused verification.

| Order | Useful change | Complexity | Reason |
| --- | --- | --- | --- |
| 1 | Make health aggregation account for failed or missing checks | Medium | Existing results can imply success without the required evidence |
| 2 | Require project-specific process identity for a healthy process result | Medium | Executable names do not identify the intended project |
| 3 | Extend the existing Linux snapshot with PSI | Low | Adds missing contention evidence without a new dependency |
| 4 | Offer Linux-only sysstat tools and document existing historical data | Low to medium | Makes the existing RB-03 recipes usable and their limits explicit |
| 5 | Add a small navi catalogue calling canonical helpers | Low to medium | Improves discovery without duplicating diagnostic logic |
| 6 | Add an optional manual CPU profiling recipe to RB-03 | Medium | Gives CPU investigations a bounded next step when metrics are insufficient |

### 1. Account for health-check execution and results

Validate project configuration before deriving expected check identities. Capture each
script's exit status and output separately; validate records before aggregation. A
nonzero execution status, malformed output, invalid status, duplicate identity or
missing expected result must produce an actionable failure, even if other checks pass.
Preserve useful valid records and existing JSON field names. Scripts may emit multiple
records, and zero is valid when no project enables that check. An entirely empty or
unconfigured run must explicitly report that no health evidence was evaluated, rather
than `ok`. Preserve warning-only exit 0; failures return 1 in every mode, including
`--json`. Diagnostics belong on stderr and must not corrupt JSON output.

Future acceptance: fixtures cover a silent child failure, malformed/unknown-status
records, partial output followed by failure, missing/duplicate expected records,
malformed configuration, legitimate zero-project output, an empty aggregate, and
consistent exit codes across pretty, quiet and JSON modes. Use the existing Bats
test infrastructure; do not run real project services to prove these cases.

### 2. Bound process identity to the declared project

Prefer an explicitly configured service identity or a launcher-owned PID whose live
process identity can be validated against the project. Account for stale/reused PIDs
and inaccessible process metadata. A generic `pgrep` match may provide a warning or
diagnostic hint, but cannot prove project health. Unknown identity remains a warning
with a limitation; a validated missing target is a failure. An HTTP endpoint may
provide separate application evidence, but must not be relabelled as process identity.

Future acceptance: an unrelated process sharing the executable or project-name text,
a stale PID, and unavailable identity data never produce a healthy process result;
the declared live target does. Keep the initial implementation to a supported explicit
identity mechanism; a portable process supervisor is outside this proposal.

### 3. Add current PSI observations to the canonical snapshot

Read CPU, memory and I/O pressure through the existing Linux helper. Keep its UTC
timestamp and resource labels. Report unsupported or unreadable PSI files as
unavailable; distinguish a read failure after an availability check from valid data.
Retain the existing failure behaviour for mandatory snapshot tools.

Explain recent average windows and the cumulative stall counter. System-level CPU
`full` is undefined and must not be used as evidence of CPU saturation. A snapshot
does not establish a past incident's pressure; interval claims need retained samples
or appropriately timed counter deltas. Do not add pressure triggers or a sampler.

Future acceptance: extend the existing offline helper fixtures for supported PSI,
missing/denied files and read errors, and verify that CPU `full` is not interpreted as
a meaningful system-level signal. No production `/proc` access is needed for fixtures.

### 4. Separate sysstat availability from collection

Offer sysstat behind an explicit Linux-only package opt-in using the established
[Nix/Home Manager package ownership](../tool-ownership.md). Extend RB-03 rather than
creating a parallel incident workflow. Read existing archives using an explicit file,
host, date, timezone and incident interval; a day-of-month filename alone does not
establish which incident it covers. Report absent or incomplete history as unavailable.

Document collector interval, retention, permissions, storage path, disk budget and how
an operator would verify collection. Installation must not silently enable collection.
Actual service/timer setup needs a separate host-specific operational decision; the
current Home Manager role is package provisioning, not production service management.

Future acceptance: evaluate the opt-in and opt-out on applicable Linux profiles and
keep macOS unaffected; demonstrate archive selection using an offline sample and a
missing-data case. WSL support depends on the actual kernel and collection environment.

### 5. Link navi entries to canonical runbooks and helpers

Start with the existing memory, OOM, Apache traffic/capacity and Laravel helpers.
Each description identifies a runbook step, prerequisites, required input and side
effects. Entries invoke the canonical helper from an explicit checkout location,
with quoted arguments; they contain no copied parsers or general command generator.
Missing helpers fail with a useful message. Manage cheatsheet files through chezmoi
in accordance with the ownership document. Reuse an existing navi installation;
resolving the existing Nix/mise ownership overlap is separate work.

Future acceptance: parse the cheatsheets and exercise selections against fixture
helpers from a checkout path containing spaces. Verify the referenced runbook steps
and arguments. Keep active HTTP probes, collectors, profiling and production changes
out of the default passive catalogue, following the existing
[execution boundaries](../../runbooks/shared/recovery-evidence.md).

### 6. Document manual profiling only after the earlier improvements

Add a short RB-03 recipe for explicitly invoked Linux `perf` capture and offline
FlameGraph processing. Require an execution review, a verified target, bounded duration
and sampling rate, permissions, explicit restricted artifact directory, and cleanup.
Document kernel/tool compatibility and symbol/unwinding prerequisites; incomplete
stacks limit conclusions. No automatic capture, privilege changes, new profiling
framework or default package expansion is proposed.

Future acceptance: review the recipe against a non-production sample and verify that
missing permissions/symbols and incomplete captures are reported as limitations.

## Consequences and limits

These changes would improve evidence quality and discoverability while retaining the
existing health JSON envelope, helper implementations and runbook approval boundaries.
Some formerly healthy process results would become warnings or failures; document that
compatibility change. Package provisioning cannot create historical evidence, and
current snapshots cannot reconstruct it.

No additional observability platform, eBPF stack, benchmarking suite, log parser or
log viewer is selected. Reconsider advanced tooling only for a demonstrated diagnostic
gap after the bounded work above. This ADR proposes future acceptance criteria; it
does not claim that implementation or runtime verification has occurred.

## Primary references

- [Linux kernel PSI interface and semantics](https://docs.kernel.org/accounting/psi.html)
- [sysstat project and collection documentation](https://github.com/sysstat/sysstat)
- [navi project and cheatsheet documentation](https://github.com/denisidoro/navi)
- [Linux perf documentation](https://perf.wiki.kernel.org/)
- [FlameGraph upstream documentation](https://github.com/brendangregg/FlameGraph)
