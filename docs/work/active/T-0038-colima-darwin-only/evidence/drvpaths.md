# T-0038 evidence (2026-11-21, base main b89c510)

Home Manager activation drvPaths, same flake.lock, before and after moving colima behind isDarwin:

| profile | before | after |
|---|---|---|
| linux-cli | `/nix/store/jzsfj0m6mfd262xhfnlbaqpkdhg8m9gi-home-manager-generation.drv` | `/nix/store/9b3v5q3gq0qv560ndb0ak6ypchx386d3-home-manager-generation.drv` |
| linux-desktop | `/nix/store/vrhccili7pi3258wbvbnapi2bpipn15j-home-manager-generation.drv` | `/nix/store/9amr9fnv9d5kwnpn22vxqxqsb4zykg4s-home-manager-generation.drv` |
| wsl | `/nix/store/jzsfj0m6mfd262xhfnlbaqpkdhg8m9gi-home-manager-generation.drv` | `/nix/store/9b3v5q3gq0qv560ndb0ak6ypchx386d3-home-manager-generation.drv` |

linux-cli and wsl share one derivation before and after.

- AC1: colima in home.packages: linux-desktop false, linux-cli false, wsl false, macos true.
- AC2: `docker compose version` from the wsl docker package (docker-29.9.3) prints "Docker Compose version 5.7.0", exit 0; no explicit docker-compose needed.
- AC3: tests/bash/chezmoiignore-colima.bats (2 tests) pass; the Linux test failed before the change.
- AC4: `nix flake check ./nix --no-update-lock-file` passes; the wsl and linux-desktop activation packages build; the full `bats tests/bash` suite ran with these changes. `chezmoi diff` on this desktop is not clean, but only from earlier unapplied repo changes; it shows no colima entry.
