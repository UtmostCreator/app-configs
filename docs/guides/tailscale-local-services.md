# Reaching local services over Tailscale (NixOS desktop)

Scope: the NixOS desktop. Tailscale is personal-only
([ADR-0029](../architecture/decisions/0029-networking-and-remote-access.md),
T-0057): sys-setup (`ops/system-setup.sh`) enables the `tailscaled` daemon by
default only when `HOST_PROFILE=linux-desktop`. Work hosts (linux-cli, WSL,
macOS) get none; the employer VPN applies. To opt in on another NixOS host, run
`sudo ENABLE_TAILSCALE=1 bash ops/system-setup.sh --apply`. Re-running with
`ENABLE_TAILSCALE=0` drops the `services.tailscale.enable` entry from the
managed module (not a module written by `ops/tailscale-setup.sh`). Under sudo
the host profile comes from the invoking user's host file; with no host file
(`bash ops/detect-host.sh --source` prints `default`) sys-setup leaves Tailscale as
the managed module has it; record the host with `sys-install --host <profile>`.
`ops/tailscale-setup.sh` (`mise run tailscale:setup`)
is a manual opt-in that no other script runs; it installs the repo's Tailscale
module (operator rights, pinned package). On Windows and WSL, Tailscale runs on
the Windows host instead
([ADR-0004](../architecture/decisions/0004-tailscale-on-windows-only.md));
nothing here changes that. Host names, tailnet names, emails and IPs below are
placeholders.

## Rules

- Keep every service on `127.0.0.1`. Do not rebind to `0.0.0.0` to be reachable.
- Share only through `tailscale serve` (tailnet-only). Never use
  `tailscale funnel` (public internet).
- Never set `networking.firewall.trustedInterfaces = [ "tailscale0" ]`. It would
  keep tailnet traffic unfiltered even if `tailscaled`'s netfilter mode changes
  (see below).
- Do not open firewall ports to reach Serve. Serve is proxied by `tailscaled`.

(iptables-based NixOS firewall, as here) `tailscaled`'s own netfilter chain normally accepts inbound traffic on
`tailscale0` (documented Tailscale behaviour). So the tailnet policy is
effectively the only filter for tailnet-origin traffic to any non-loopback
listener. On this host that is Syncthing (22000 tcp/udp, device-authenticated; 21027/udp
discovery) and mDNS.
This is why the allow-all rule must go (checklist below).

## Read-only audit

None of these change state.

```bash
tailscale version
tailscale status
tailscale serve status --json
tailscale funnel status --json
tailscale status --json | jq '(.Self.CapMap // {}) | keys'
tailscale debug prefs
ss -lntu
docker ps --format '{{.Names}}\t{{.Ports}}'
```

Good looks like:

- `serve status` shows only rules you created on purpose (`{}` when none). `funnel status` shows no
  `AllowFunnel: true` entries. `tailscale status --json | jq '(.Self.CapMap // {}) | keys'`
  shows no `https://tailscale.com/cap/funnel` key.
- Prefs: `ShieldsUp` false is fine; no unexpected `AdvertiseRoutes` or exit node.
  `RunSSH` true means Tailscale SSH is on (see the checklist).
- `ss`: dev services listen on `127.0.0.1` only. Every non-loopback listener should be
  expected: `tailscaled`, Syncthing sync (22000) and discovery (21027/udp), mDNS.
  Without `-p`, `ss -lntu` cannot attribute `tailscaled`'s UDP 41641 or peerapi ports.
- `docker ps`: published ports read `127.0.0.1:<port>->`, not `0.0.0.0:`.

## Owner checklist before sharing anything sensitive

These live in the Tailscale admin console and cannot be checked from the host.

1. Turn on MFA or a passkey at the login (identity) provider.
2. Review the device list; remove devices you do not recognise. Also review
   device approval, key expiry and Tailnet Lock. Device approval and Tailnet Lock
   are mutually exclusive; for a small personal tailnet use device approval.
   Tailnet Lock was off for this tailnet when audited (check: `tailscale lock status`).
3. Replace the default allow-all policy with least-privilege grants. A narrow
   grant does not override an allow-all one: delete the allow-all rule, either an
   `acls` accept from `*` to `*:*` or a grant `*` to `*` with `ip: ["*"]`. Grants
   to a user cover all of that user's devices.
4. Keep Funnel unused: remove the `funnel` node attribute from the policy if present.
5. Check the Tailscale SSH policy, because `RunSSH` is on. Turn Tailscale SSH off
   (`tailscale set --ssh=false`) only if you do not use the SSH tunnel below.

Minimal policy sketch for a single owner (placeholders; adjust before use). It
allows HTTPS on 8443 and the SSH tunnel from the owner's devices to the desktop
only.

```json
{
  "hosts": { "desktop": "<desktop-ip>" },
  "grants": [
    {
      "src": ["<owner-login>"],
      "dst": ["desktop"],
      "ip":  ["tcp:8443", "tcp:22"]
    }
    // Optional, only if the phone syncs over the tailnet (check the connection
    // type in the Syncthing GUI). To enable it, uncomment the last line and add
    // a comma after the grant above.
    // { "src": ["<owner-login>"], "dst": ["desktop"], "ip": ["tcp:22000", "udp:22000"] }
  ],
  "ssh": [
    {
      "action": "check",
      "src":    ["<owner-login>"],
      "dst":    ["autogroup:self"],
      "users":  ["<local-user>"]
    }
  ],
  "tests": [
    {
      "src": "<owner-login>",
      "accept": ["desktop:8443", "desktop:22"],
      "deny":   ["desktop:6006", "desktop:9749", "desktop:8384", "desktop:5433"]
    }
  ],
  "sshTests": [
    { "src": "<owner-login>", "dst": ["desktop"], "check": ["<local-user>"], "deny": ["root"] }
  ]
}
```

Why `desktop` and not `autogroup:self`: `autogroup:self` lets any of the owner's
devices reach any other owner device, which is broader than needed. A tag on the
desktop is the alternative, with consequences: the tag replaces node ownership,
`autogroup:self`/user rules stop applying to it, and key expiry is off by default
for tagged nodes. Syncthing sync (22000) is blocked unless the optional grant is
added. Remove `tcp:22` and the `ssh` block to block SSH and the tunnel.

SSH is authorised in two layers, and both must allow: the `tcp:22` grant carries
the connection, and the `ssh` rule authorises the login. SSH rules can't target
a `hosts` alias. The `tcp:22` grant to `desktop` limits Tailscale SSH to the
desktop.

Run the `tests` and `sshTests` in the admin console before saving; they block a
bad save. Rollback: keep a private copy of the current policy before saving and paste it
back; configuration audit logs show past changes.

## Per service

| Service | Guidance |
|---------|----------|
| Phoenix (6006, 9090) | Do not share until Phoenix auth is on: `PHOENIX_ENABLE_AUTH=true` with a persistent secret. It is currently off (no login). That change belongs to the separate ai-monitoring project, not this repo. |
| Codebase Memory UI (9749), Syncthing GUI (8384) | SSH tunnel only (below). |
| Other dev servers | Temporary `tailscale serve` per port; stop it when done. |

## Share and unshare

Only after the checklist passes and the service has its own auth.

```bash
# foreground: stops when you press Ctrl-C
tailscale serve --https=8443 http://127.0.0.1:3000
# background
tailscale serve --bg --https=8443 http://127.0.0.1:3000
# reachable at https://<host>.<tailnet>.ts.net:8443 (tailnet devices only)

tailscale serve status
tailscale serve --https=8443 off     # stop one port
tailscale serve reset                # clear every rule
```

`serve --https=8443 off` is documented by Tailscale and printed when a `--bg`
serve starts; it is not in this version's (1.102.3) `serve --help`, which lists
`reset`.

`--https` needs MagicDNS and HTTPS certificates. Enabling certificates publishes
`<host>.<tailnet>.ts.net` in public Certificate Transparency logs. `--http=PORT`
avoids certificates (tailnet traffic is already encrypted).

SSH tunnel alternative (nothing is shared). sshd is off on this host. The tunnel
uses Tailscale SSH, which is on (`RunSSH`, set by hand: the repo's tailscale module
only sets `--operator`, and `ops/tailscale-setup.sh` sets up no Tailscale SSH), so
keeping it on is the owner's decision. It needs an `ssh` rule in the tailnet policy
and a grant to tcp:22 from the owner to the desktop: it needs both layers in the sketch above. If
sshd is ever wanted, that needs its own repo change (`openFirewall = false`, no
password login), not a manual enable.

```bash
ssh -L 9749:127.0.0.1:9749 <user>@<host>.<tailnet>.ts.net
# then open http://127.0.0.1:9749 on the other device
```
