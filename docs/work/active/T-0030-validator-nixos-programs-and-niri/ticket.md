Source: local

# T-0030: Validate ownership on the integrated Niri host

Status: in progress (scoped host and validator checks)

**Niri delivery · 23 November 2026 · 100% (3/3) · P0 build · medium complexity.** Positive and negative fixture suites passed. Six evaluated user profiles passed. Disposable chezmoi render checked the KDL exclusion. Repeat these checks if the deployment revision changes the relevant modules. [T-0032](../T-0032-niri-trial-session/ticket.md) · [ADR-0047](../../../architecture/decisions/0047-gnome-dependency-retirement-and-wayland-components.md) · [ADR-0049](../../../architecture/decisions/0049-niri-safest-staged-installation-order.md)
Evidence: [Niri component register](../../../architecture/decisions/0046-niri-desktop-installation-decision-register.md)

NixOS owns native `programs.niri`, portals and its session package. Home Manager writes `~/.config/niri/config.kdl` and runs the selected user services on `linux-niri`. The older GNOME pilot still uses its chezmoi KDL. The validator must model the target on which each writer runs.

- Allow Niri on the NixOS surface. Continue rejecting unrelated unapproved declarations and Home Manager program violations.
- Scope the KDL and swayidle allowances to this integrated user. Check evaluated `nixosConfigurations.linux-niri.config.home-manager.users` as well as the standalone home outputs.
- Render the actual chezmoi ignore rules for the Niri host and prove it excludes the KDL even if an old desktop profile is selected. Retain collision checks for other paths and hosts.
- Verify both acceptance and rejection with `bats tests/bash/validate-config.bats tests/bash/niri-config.bats`, then run `bash ops/validate-config.sh` and its `--eval` mode. A generated path or an allowed option alone does not prove session behaviour.

**Verification, 2026-11-22.** The focused validator and Niri suites passed all 86 cases. The evaluated validator passed for the integrated user and all five standalone profiles.
