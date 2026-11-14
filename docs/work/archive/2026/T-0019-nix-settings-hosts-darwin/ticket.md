Source: local

# T-0019: nix settings, hosts and darwin modules

Status: closed (2026-11-14)
Wave: 2
Depends on: T-0022 (policy research)

## Summary
Settings, host and macOS modules contain comment/behaviour mismatches and platform gaps. Follow the strategy from the policy research.

## Owned files (write boundary)
- nix/modules/common/nix-settings.nix
- nix/hosts/*/home.nix
- nix/hosts/macos/darwin.nix
- nix/modules/darwin/homebrew.nix
- nix/modules/darwin/system-defaults.nix
- nix/modules/home/cli.nix

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- HM nix.gc comment claims system-wide GC (only user profiles).
- macOS launchd passes "--delete-older-than 7d" as one argv (verify upstream).
- nix.package = mkDefault pkgs.nix may shadow Determinate Nix.
- nixClientAutoOptimise default true on untrusted users (linux-cli, linux-desktop).
- experimental-features replaces vs extra-.
- Determinate vs nix-darwin nix.enable conflict on macOS.
- linux-cli lacks targets.genericLinux.enable for non-NixOS.
- Finder FXPreferredViewStyle "Nlsv" is list, not column (check intent comment).
- Homebrew flameshot cask disabled.
- mysql-client keg-only not on PATH.
- docker-compose plugin discovery.
- duti comment.
- users.users home duplicated in flake.nix.
- cli.nix navi/glow installed by Nix while mise.toml has them optional.
- tealdeer vs matrix decision tlrc.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 2728abe test(nix): assert Nix, GC and CLI tool ownership from eval
  - 5f02e14 fix(cli): let Nix own tlrc, navi and glow
  - 41316a1 docs(darwin): fix Homebrew and Finder comments
  - d5949da fix(homebrew): put keg-only mysql-client on the system PATH
  - 2e52667 fix(homebrew): drop the disabled flameshot cask
  - 07e2f67 fix(darwin): use Determinate Nix mode (nix.enable = false)
  - 92c7cc6 fix(hosts): make macOS own Nix via Determinate, genericLinux for cli
  - 02b488a fix(nix): default HM auto-optimise off, add extra features, 14d Linux GC
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
