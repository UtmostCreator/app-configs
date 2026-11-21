Source: local

# T-0036: WSL open/BROWSER in zsh and the bash fallback (bug)

Status: not started (zsh and bash still lack the WSL BROWSER=wsl-open block)
Wave: 1
Depends on: none. The former T-0021 dependency is gone: T-0021 was closed on 2026-11-14 and archived at docs/work/archive/2026/T-0021-ssh-agent-installer. `home/dot_bashrc.tmpl` lines 30-32 and `home/dot_zshrc.tmpl` lines 419-421 source the ssh-agent loader; do not touch those lines.
Order: fourth. Recommended implementation order for the WSL2 work: T-0035, T-0038, T-0037, T-0036, T-0034, T-0045 (Wave 2), T-0039 (its wsl.conf fix may land first), T-0040 last. Full test order and fix-before gates: T-0040. T-0036 must land before T-0040 step 11 (behaviour checks).

Re-verified 2026-11-15 against main ed39171: this ticket's findings were re-checked and none of the WSL2 tickets has been executed. Claims changed: the T-0021 dependency is gone; wsl-open.bats exists. User decisions unchanged: Wave 1 = T-0034..T-0038; Windows-side provisioning stays manual; T-0041 is docs-only.

## Summary
fish sets `BROWSER=wsl-open` and an `open` function on WSL2; zsh and the bash
fallback do not, so `gh auth login`, `gh browse` and `open .` fail or misbehave
there.

## Owned files (write boundary)
- home/dot_zshrc.tmpl (one new block)
- home/dot_bashrc.tmpl (one new block in the fallback section, away from the
  ssh-agent lines; the file has no non-darwin block yet, only a darwin one around line 34, so the `ne .chezmoi.os "darwin"` block must be created)
- tests/bash/wsl-open.bats (extend: the file already exists with 6 tests; do not create it)

## Findings (review claims, unverified until reproduced: reproduce first; reject false positives with evidence)
- VERIFIED: `home/dot_config/fish/config.fish.tmpl:134-144` has the WSL2 block;
  `grep` of `dot_zshrc.tmpl` and `dot_bashrc.tmpl` finds no `BROWSER` or `wsl-open`.
- INFERRED: on Ubuntu `open` resolves to `openvt` (Debian `kbd`), so zsh
  `open .` does the wrong thing.
- Interactive bash execs fish on WSL (`dot_bashrc.tmpl:16-21`), so the bash block is cosmetic parity (it matters only with `NO_FISH=1` or when fish is missing); zsh is the real gap.

## Design
Inside `{{ if ne .chezmoi.os "darwin" }}`:

    if [ -n "${WSL_DISTRO_NAME:-}${WSL_INTEROP:-}" ]; then
      export BROWSER=wsl-open
      open() { wsl-open "$@"; }
    fi

## Acceptance criteria
- AC1: Rendered for linux with `WSL_DISTRO_NAME` set, zsh and bash both have
  `BROWSER=wsl-open`, and `open https://example.com` / `open .` call a stub
  `wsl-open` with those arguments.
- AC2: Without the WSL variables, `BROWSER` is not set by the block and `open`
  is not a function.
- AC3: The darwin render contains no `wsl-open`.
- AC4: zsh tests use the `BATS_ZSH` lookup from `tests/bash/shell-os-parity.bats`
  and skip only when zsh is unavailable, as that file does.
- AC5: `chezmoi diff` on the dev host shows only the new blocks.
- Each finding reproduced by a failing test first; independent review PASS; one
  conventional commit per logical change; no AI attribution trailers.

## Verification
- `bats tests/bash/wsl-open.bats tests/bash/shell-os-parity.bats`
- `bash ops/lint-shell.sh` (renders templates with `bash -n`); `chezmoi diff`

## Out of scope / notes
- `wsl-open` itself; fish; ssh-agent lines.
- Only the files listed above. Unrelated findings are reported, not fixed.
