Source: local

# T-0035: sys-readiness must not print ALL SET while TODO items remain (bug)

Status: done (verdict exit 3 for remaining TODOs, 2026-11-21); archive after the next WSL run confirms it
Wave: 1
Depends on: none (builds on T-0015 (landed); start from current main). T-0029 also lists ops/readiness.sh as downstream.
Order: first in the WSL2 sequence. Recommended implementation order for the WSL2 work: T-0035, T-0038, T-0037, T-0036, T-0034, T-0045 (Wave 2), T-0039 (its wsl.conf fix may land first), T-0040 last. Full test order and fix-before gates: T-0040. T-0035 must land before T-0040 step 10 (post-install readiness).

Re-verified 2026-11-15 against main ed39171: this ticket's findings were re-checked and none of the WSL2 tickets has been executed. Claims changed: line references (verdict now at lines 124-136; README wording). User decisions unchanged: Wave 1 = T-0034..T-0038; Windows-side provisioning stays manual; T-0041 is docs-only.

## Summary
`sys-readiness` prints `ALL SET` and exits 0 even when it printed `[TODO]` lines.
On WSL2 every `ops/wsl-check.sh` TODO (systemd off, interop off, Windows npm
shadowing, no Docker daemon) turns into a false green.

## Owned files (write boundary)
- ops/readiness.sh (verdict block and header comment only)
- tests/bash/readiness.bats
- docs/getting-started/install.md (verdict list near lines 25-32)
- README.md (lines near 46-56)
- docs/getting-started/install.md says "done exactly when ALL SET and exits 0" and README.md says "done when it prints ALL SET"; both are in scope (see Findings)

## Findings (review claims, unverified until reproduced: reproduce first; reject false positives with evidence)
- `ops/readiness.sh:124-136` (main ed39171; the ticket first cited 116-127 at 4ba9437): the verdict uses only `err` and
  `rebuild_needed`; `note()` increments `warn`, which never affects the verdict.
- WSL2 TODOs reach `note()` through the `hdr "WSL2"` loop (`ops/readiness.sh` WSL block).
- The header comment (`ops/readiness.sh` lines 9-12) lists only exits 0, 1, 2 and 64; add 3.
- Contract: `docs/getting-started/install.md` (around lines 25-32) says "done exactly when
  `sys-readiness` prints `ALL SET` and exits 0"; README.md (around lines 46-56) says "done when it prints ALL SET" without mentioning exit 0; make the claim match the new verdict list.
- New exit 3 drivers: T-0037's `code` check and any Docker TODO will turn WSL hosts into exit 3 until fixed.
- TASK: check every caller of readiness (`ops/install.sh`, the `sys-install` wrapper, mise tasks) for code that treats a non-zero exit as failure, and decide for each whether 3 is success. If `tests/bash/ops-script-args.bats` or another bats file asserts the exit set, add 3.

## Design
Verdict precedence:
1. `err > 0`: `NOT READY`, exit 1 (unchanged).
2. `rebuild_needed`: exit 2 (unchanged).
3. `warn > 0`: `User environment READY, N TODO item(s) left; see [TODO] lines above`, exit 3 (new).
4. otherwise `ALL SET`, exit 0.
Rejected: reusing exit 2 (it means a NixOS rebuild is pending, with a specific
fix); changing only the message and keeping exit 0 (breaks the "exit 0 = done"
contract).

## Acceptance criteria
- AC1 (failing test first): on the wsl profile, with a stub wsl-check printing
  one TODO and everything else OK, the old code prints ALL SET with exit 0; the
  new code does not print ALL SET, exits 3 and names the TODO count.
- AC2: no TODO and no MISS gives ALL SET, exit 0 (unchanged).
- AC3: any MISS still gives exit 1; a pending rebuild still gives exit 2.
- AC4: install.md and README.md list the new verdict and exit 3.
- AC4b: no caller of `ops/readiness.sh` treats exit 3 as a hard failure unless deliberately documented; any bats file asserting the exit set includes 3.
- AC5: existing `readiness.bats` and `ops-script-args.bats` pass. New tests run
  from a scratch copy of `ops/` with stubbed doctor, validate-config and
  wsl-check (pattern: `tests/bash/ops-script-args.bats`).
- Fix applied; the regression test fails on the old code and passes on the new.
- Independent review PASS; one conventional commit per logical change; no AI
  attribution trailers.

## Verification
- `bats tests/bash/readiness.bats tests/bash/ops-script-args.bats`
- `bash ops/lint-shell.sh`

## Out of scope / notes
- Reclassifying which checks are TODO vs MISS; doctor `--preflight`; the NixOS block.
- Intended effect: a WSL host with no Docker daemon or no VS Code now ends with
  exit 3 until the TODO is fixed.
- Only the files listed above. Unrelated findings are reported, not fixed.

- 2026-11-21: Implemented test first. New readiness.bats verdict tests (AC1 failed on the old code: ALL SET, exit 0). Callers checked: the fish and ~/.local/bin wrappers pass the exit through, bootstrap.ps1 only records it, install.sh prints a hint, the mise task reports non-zero as failure (documented as intended). Boundary extension: `is_nixos` in ops/readiness.sh now honours READINESS_ASSUME_NIXOS=0 (test seam only; unset still probes the host), needed to run the verdict tests on a NixOS host. Independent review PASS WITH NOTES; full bats suite run. Handed to T-0039: docs/platforms/wsl/setup.md:59 records an old run as "exit 0, ALL SET (... 1 TODO ...)", which now exits 3.
