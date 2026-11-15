# ADR-0004: Tailscale runs on the Windows host only
Status: decided (not yet verified) · Date: 2026-11-15 · Sources: T-0047 ticket and plan, docs/platforms/wsl/windows-and-wsl.md

## Decision
Tailscale is installed on Windows only. sys-setup runs with `ENABLE_TAILSCALE=0` on wsl, and WSL reaches the tailnet through Windows.

## Why
- One VPN node on the machine (session decision 2026-11-15).
- Fewer routing and DNS conflicts between Windows and WSL (session decision 2026-11-15).
- WSL only needs outbound tailnet access today.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| Tailscale inside NixOS-WSL | Gives WSL its own tailnet IP and Tailscale SSH, but is a second device with its own auth and routing. Only needed for inbound access to WSL; stays the option if that need appears. |
| Both | Most complex; both sets of problems. |

## Discarded
None recorded.

## Consequences
- With Tailscale off, sys-setup does not enable linger: user timers (update timers, the CBM units) run only while a WSL session is open.
- Acceptance checks outbound tailnet access from WSL (T-0047 Slice 4); unverified until then.
- Revisit if inbound access to WSL (its own IP, Tailscale SSH) is needed.
