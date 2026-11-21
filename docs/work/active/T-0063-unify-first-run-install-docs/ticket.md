Source: local

# T-0063: Install and bootstrap docs disagree on the first-run command (docs)

Status: open (verified 2026-11-21; not started)
Relates to: T-0009, T-0044

Written 2026-11-21 against main cf53949 from a documentation audit.

## Finding (verified)
- `docs/index.md:36` says setup docs assume `bash ops/bootstrap.sh --yes`, while `docs/getting-started/bootstrap.md` names `ops/install.sh` as the NixOS-aware path.
- `docs/platforms/nixos/install.md:14` says bootstrap step 1 runs the Determinate installer; the script skips it when `nix` exists. The same guide (lines 22-31) warns against a profile `home-manager`, which bootstrap still installs (see T-0009 BOOT-01).

## Acceptance criteria
- AC1: `ops/install.sh` is the first-run entry point everywhere it is supported.
- AC2: `ops/bootstrap.sh` is documented as the lower-level alternative, with its NixOS caveats.
- AC3: the docs say when the Determinate installer runs (only without an existing `nix`).
- AC4: the NixOS guide matches what the installer does with the Home Manager package.
- AC5: dry-run, apply and recovery instructions match across docs/index.md, bootstrap.md and the NixOS guide.
