# Reaching local services over Tailscale (NixOS desktop)

Scope: the NixOS desktop. sys-setup (`ops/system-setup.sh`) enables the
`tailscaled` daemon, and `ops/tailscale-setup.sh` installs the repo's Tailscale
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
  expose every non-loopback listener to every tailnet device.
- Do not open firewall ports to reach Serve. Serve is proxied by `tailscaled`.

## Read-only audit

None of these change state.

```bash
tailscale version
tailscale status
tailscale serve status --json
tailscale funnel status --json
tailscale debug prefs
ss -lntu
docker ps --format '{{.Names}}\t{{.Ports}}'
```

Good looks like:

- `serve status` shows only rules you created on purpose (`{}` when none). `funnel status` shows no
  `AllowFunnel: true` entries.
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
   device approval, key expiry and Tailnet Lock.
3. Replace the default allow-all policy with least-privilege grants. A narrow
   grant does not override an allow-all one: delete the allow-all rule, either an
   `acls` accept from `*` to `*:*` or a grant `*` to `*` with `ip: ["*"]`. Grants
   to a user cover all of that user's devices.
4. Keep Funnel unused: remove the `funnel` node attribute from the policy if present.
5. Check the Tailscale SSH policy, because `RunSSH` is on. Turn Tailscale SSH off
   (`tailscale set --ssh=false`) only if you do not use the SSH tunnel below.

Minimal policy sketch for a single owner (placeholders; adjust before use). It
allows HTTPS on 8443 and the SSH tunnel (tcp:22 plus an `ssh` rule) from the
owner's devices to the owner's own devices. Remove `tcp:22` and the `ssh` block
to block SSH and the tunnel.

```json
{
  "grants": [
    {
      "src": ["owner@example.com"],
      "dst": ["autogroup:self"],
      "ip":  ["tcp:8443", "tcp:22"]
    }
  ],
  "ssh": [
    {
      "action": "check",
      "src":    ["owner@example.com"],
      "dst":    ["autogroup:self"],
      "users":  ["<your-login>"]
    }
  ],
  "tests": [
    { "src": "owner@example.com", "accept": ["<desktop-ip>:8443", "<desktop-ip>:22"], "deny": ["<desktop-ip>:5432"] }
  ]
}
```

Run the `tests` in the admin console before saving; they fail the save if a rule
does not do what you expect.

## Per service

| Service | Guidance |
|---------|----------|
| Phoenix (6006, 9090) | Do not share until Phoenix auth is on: `PHOENIX_ENABLE_AUTH=true` with a persistent secret. It is currently off (no login). That change belongs to the separate ai-monitoring project, not this repo. |
| Codebase Memory UI (9749), Syncthing GUI (8384) | SSH tunnel only (below). |
| DeepSeek Harness | Login autostart is opt-in (653ccfe). Running `dsh-remote-setup` (with or without `--autostart`) adds a persistent `tailscale serve --bg 3080` rule, which takes https 443, so the examples here use 8443. `tailscale serve reset` also removes it. See [`software-and-cli-tools.md`](../../repo-docs/software-and-cli-tools.md). |
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
tailscale serve --https=8443 off     # stop one port (the CLI prints this line when you start a --bg serve)
tailscale serve reset                # clear every rule
```

`--https` needs MagicDNS and HTTPS certificates. Enabling certificates publishes
`<host>.<tailnet>.ts.net` in public Certificate Transparency logs. `--http=PORT`
avoids certificates (tailnet traffic is already encrypted).

SSH tunnel alternative (nothing is shared). sshd is off on this host. The tunnel
uses Tailscale SSH, which is on (`RunSSH`, set by hand: the repo's tailscale module
only sets `--operator`, and `ops/tailscale-setup.sh` sets up no Tailscale SSH), so
keeping it on is the owner's decision. It needs an `ssh` rule in the tailnet policy
and a grant to tcp:22 from the owner to the desktop (both in the sketch above). If
sshd is ever wanted, that needs its own repo change (`openFirewall = false`, no
password login), not a manual enable.

```bash
ssh -L 9749:127.0.0.1:9749 <user>@<host>.<tailnet>.ts.net
# then open http://127.0.0.1:9749 on the other device
```
