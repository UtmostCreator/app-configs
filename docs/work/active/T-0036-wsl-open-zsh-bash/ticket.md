Source: local

# T-0036: WSL open/BROWSER in zsh and the bash fallback (bug)

Status: open
Wave: 1
Depends on: none (coordinate with T-0021: home/dot_bashrc.tmpl:30-32 sources the
ssh-agent loader; do not touch those lines)

## Summary
fish sets `BROWSER=wsl-open` and an `open` function on WSL2; zsh and the bash
fallback do not, so `gh auth login`, `gh browse` and `open .` fail or misbehave
there.

## Owned files (write boundary)
- home/dot_zshrc.tmpl (one new block)
- home/dot_bashrc.tmpl (one new block in the fallback section, away from the
  ssh-agent lines)
- tests/bash/wsl-open.bats

## Findings (review claims, unverified until reproduced: reproduce first; reject false positives with evidence)
- VERIFIED: `home/dot_config/fish/config.fish.tmpl:134-144` has the WSL2 block;
  `grep` of `dot_zshrc.tmpl` and `dot_bashrc.tmpl` finds no `BROWSER` or `wsl-open`.
- INFERRED: on Ubuntu `open` resolves to `openvt` (Debian `kbd`), so zsh
  `open .` does the wrong thing.
- Interactive bash execs fish (`dot_bashrc.tmpl:16-21`); the bash block only
  matters with `NO_FISH=1` or when fish is missing. It is added for parity.

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
