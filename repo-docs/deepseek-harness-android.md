# DeepSeek Harness from Android

This host exposes DeepSeek Harness privately as:

```text
Android Chrome/PWA -> Tailscale HTTPS -> Tailscale Serve
                   -> 127.0.0.1:3080 -> DeepSeek Harness -> advanced-gym
```

The Harness never binds a LAN or public interface. Do not replace Serve with
Funnel: Funnel is public Internet ingress, while Serve is tailnet-only.

## PC setup

The repo manages:

- the NixOS `tailscaled` service and user lingering via the scoped setup script;
- a Tailscale-only nixpkgs pin, so security releases can be applied without a
  full operating-system package update;
- `dsh-remote.service`, which starts at boot even when the user is logged out;
- the loopback-only launcher, including DSH's required Tailscale trusted host;
- automatic loading of `.dsh/yuc-agent-presets.cordis.patch.yml` when YUC has
  installed repository-local DSH agents into the selected workspace;
- setup/status helpers that print the Android URL.

Apply the dotfiles, enable Tailscale, and configure Serve:

```bash
chezmoi apply
sudo bash ops/tailscale-setup.sh --apply
dsh-remote-setup
```

`dsh-remote-setup` deliberately does not replace anything already listening on
port 3080. If an interactively launched Harness has active agents, let them
finish, stop that process normally, then run:

```bash
systemctl --user enable --now dsh-remote.service
dsh-remote-status
```

The status command prints both the clean HTTPS URL and DSH's tokenized first-use
URL. The token exchange creates an authority-bound browser cookie; do not post
the tokenized URL publicly. DSH cookies currently expire after 30 days, so use
the latest tokenized URL from `dsh-remote-status` if Android later receives 401.

Override the workspace or port without editing the unit by adding variables to
`~/.config/environment.d/dsh-remote.conf`, then restarting the service:

```ini
DSH_REMOTE_WORKSPACE=/home/utmostcreator/Projects/advanced-gym
DSH_REMOTE_PORT=3080
```

## Android-only steps

1. Install the official Tailscale Android app and sign in to the same tailnet.
2. Enable Tailscale.
3. Open the **First-use URL** printed by `dsh-remote-status` in Chrome.
4. After DSH redirects to its clean URL, use Chrome's **Install app** or
   **Add to Home screen** action.

No Termux, SSH client, router port-forward, or public DNS record is needed.
