Source: local

# T-0035: sys-readiness must not print ALL SET while TODO items remain (bug)

Status: open
Wave: 1
Depends on: none (builds on T-0015 (landed); start from current main). T-0029 also lists ops/readiness.sh as downstream.

## Summary
`sys-readiness` prints `ALL SET` and exits 0 even when it printed `[TODO]` lines.
On WSL2 every `ops/wsl-check.sh` TODO (systemd off, interop off, Windows npm
shadowing, no Docker daemon) turns into a false green.

## Owned files (write boundary)
- ops/readiness.sh (verdict block and header comment only)
- tests/bash/readiness.bats
- docs/getting-started/install.md (verdict list near lines 25-32)
- README.md (lines near 50-53)

## Findings (review claims, unverified until reproduced: reproduce first; reject false positives with evidence)
- `ops/readiness.sh:116-127` (main 4ba9437): the verdict uses only `err` and
  `rebuild_needed`; `note()` increments `warn`, which never affects the verdict.
- WSL2 TODOs reach `note()` through the `hdr "WSL2"` loop (`ops/readiness.sh` WSL block).
- Contract: `docs/getting-started/install.md:32` says "done exactly when
  `sys-readiness` prints `ALL SET` and exits 0"; README.md:50-53 says the same.

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
