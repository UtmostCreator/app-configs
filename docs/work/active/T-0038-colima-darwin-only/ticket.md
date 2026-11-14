Source: local

# T-0038: Colima darwin-only; confirm the Docker Compose plugin (bug)

Status: open
Wave: 1
Depends on: none (builds on T-0018 (landed); start from current main)

## Summary
Colima is in the shared package list but only macOS uses it. A review also
claims Docker Compose is not declared for WSL. Move Colima behind `isDarwin` and
prove whether compose ships with the Nix `docker` package.

## Owned files (write boundary)
- nix/modules/home/dev.nix (the colima line and the docker comment only)
- home/.chezmoiignore (non-darwin block: `.colima`, `.colima/**`)
- tests/bash/chezmoiignore-colima.bats (new)
- docs/reference/app-catalog.md (line 64)

## Findings (review claims, unverified until reproduced: reproduce first; reject false positives with evidence)
- VERIFIED: `dev.nix:83` lists `colima` for every host;
  `ops/projects/workspace/config.sh:76-90` uses the running daemon on non-Darwin;
  `docs/platforms/wsl/setup.md:109` says not to run Colima in WSL.
- VERIFIED: `home/dot_colima/default/colima.yaml` deploys on all hosts;
  `.chezmoiignore` has no `.colima` entry.
- LIKELY FALSE POSITIVE (compose): dev.nix declares `docker` and `docker-buildx`.
  nixpkgs `docker` has `composeSupport ? true` and adds `docker-compose` as a CLI
  plugin (code-inspected in a local nixpkgs source; the pinned revision is
  UNVERIFIED). If the pinned build lacks it, add `docker-compose` to the Linux
  optionals and record why.

## Acceptance criteria
- AC1: `nix eval --json "path:$PWD/nix#homeConfigurations.<p>.config.home.packages" --apply 'ps: builtins.any (p: (p.pname or "") == "colima") ps'`
  prints `false` for wsl, linux-desktop and linux-cli, and `true` for macos.
- AC2: `"$(nix build --no-link --print-out-paths "path:$PWD/nix#homeConfigurations.wsl.pkgs.docker")/bin/docker" compose version`
  exits 0 (no daemon needed); otherwise compose is added explicitly and AC2 passes.
- AC3: `.chezmoiignore` rendered for linux contains `.colima`; for darwin it does not.
- AC4: `nix flake check ./nix` passes; the activationPackage builds for wsl and
  linux-desktop; `bats tests/bash` passes (colima stubs in projects-workspace-herd,
  arg-contract and projects-no-args tests are unaffected); `chezmoi diff` is clean.
- AC5: app-catalog says Colima is macOS-only.
- Independent review PASS; one conventional commit per logical change; no AI
  attribution trailers.

## Verification
- The AC1 and AC2 commands; `bats tests/bash/chezmoiignore-colima.bats`
- `nix flake check ./nix`
- `nix build --no-link "path:$PWD/nix#homeConfigurations.wsl.activationPackage"`
- `nix build --no-link "path:$PWD/nix#homeConfigurations.linux-desktop.activationPackage"`
- `bats tests/bash`; `chezmoi diff`

## Out of scope / notes
- An existing `~/.colima` on Linux stays (chezmoi does not delete ignored
  targets); remove it by hand if wanted.
- No Docker engine choice is made here.
- Build-affecting: validate per AGENTS.md before any commit.
- Only the files listed above. Unrelated findings are reported, not fixed.
