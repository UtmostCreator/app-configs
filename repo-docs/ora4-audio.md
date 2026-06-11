# Kanto ORA4 USB audio

Tools shipped for this device (Linux desktop profile, see `gui.nix`):
`alsa-utils`, `wireplumber` (`wpctl`), `pulseaudio` (`pactl`), `pavucontrol`,
`usbutils`.

## Select ORA4 and set volume

Find the ORA4 sink ID in `wpctl status`, then:

```bash
wpctl set-default ID_HERE
wpctl set-mute ID_HERE 0
wpctl set-volume ID_HERE 55%
```

Profile must be `output:analog-stereo` (set in pavucontrol → Configuration).

## High-quality setup (shipped declaratively)

The ORA4 enumerates as a USB Audio device on a **full-speed (12 Mbit/s)** link
supporting 16/24-bit at 44.1/48/96 kHz, 2ch. On a full-speed link, 24-bit/96kHz
sits at the edge of the bus and risks dropouts for no audible gain on this DAC,
so the safe high-quality target is **24-bit / 48 kHz**.

This repo ships that as a WirePlumber drop-in in `gui.nix` (file
`~/.config/wireplumber/wireplumber.conf.d/51-kanto-ora4.conf`), matched to the
ORA4 by name so other devices/PCs are unaffected. It locks `audio.format =
S24_3LE`, `audio.rate = 48000`, `audio.allowed-rates = [48000]`, and
`node.pause-on-idle = false`. Every Linux-desktop PC built from this repo gets it.

Verify after rebuild + relog (or `systemctl --user restart wireplumber`):

```bash
pactl list sinks | grep -A6 -i kanto   # Sample Spec should read s24le 48000Hz
```

## No sound? Pick the Analog sink, not Digital

The ORA4 exposes two sinks: **`ORA4 by Kanto Analog Stereo`** and a
**Digital (IEC958)** one. After a wireplumber/pipewire restart the default can
flip to the **Digital** sink, which produces **no sound** on the speaker. If
audio goes silent, select **`ORA4 by Kanto Analog Stereo`** again (GNOME Sound
output, pavucontrol, or `wpctl set-default <analog-sink-id>`).

## Volume cuts out below ~50%? (gain-only hardware mixer)

The ORA4's hardware `PCM Playback Volume` (see `/proc/asound/card<N>/usbmixer`)
is **gain-only, range 0..+16 dB**, and its Base Volume (0 dB) lands at ~54% on
the PipeWire slider. Below that, the device has no attenuation headroom, so the
control collapses toward its minimum and output drops to silence — the "stops
working below 50%" symptom.

Fix (shipped in `gui.nix`, verified working): the ORA4 wireplumber drop-in
forces **software volume** so the full 0–100% range is smooth, linear, and
granular with no dead zone. Two rules are needed and BOTH matter:

- a **device** rule sets `api.alsa.use-acp = false` — with ACP on (the
  default), the ALSA Card Profile owns the mixer and re-exposes the gain-only
  hardware volume, which **overrides** node-level soft-mixer (confirmed via
  `pw-dump`). Disabling ACP lets soft-mixer win.
- a **node** rule sets `api.alsa.soft-mixer = true` (plus the format lock).

On a 24-bit stream the low-level headroom tradeoff is inaudible.

Apply on this host (flake setup — bare `home-manager switch` will NOT work):

```bash
home-manager switch --flake ~/Projects/app-configs/nix#linux-desktop
systemctl --user restart wireplumber pipewire pipewire-pulse
```

Verify the cliff is gone — the sink `Flags` must NOT contain `HW_VOLUME_CTRL`,
and Base Volume should read `100% / 0.00 dB`:

```bash
pactl list sinks | sed -n '/Kanto/,/^Sink #/p' | grep -iE "Flags|Base Volume"
```

Then set any low level on the ORA4 **sink** node (find its id in `wpctl status`
under Sinks — note the device id and sink id differ) and it stays proportional:

```bash
wpctl set-volume SINK_ID 0.15   # quiet but audible, no longer silent
```

## NixOS PipeWire system layer

If `lsusb` sees ORA4 but `wpctl status` does not, ensure
`/etc/nixos/configuration.nix` has:

```nix
{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  hardware.pulseaudio.enable = false;
}
```

Then `sudo nixos-rebuild switch` and
`systemctl --user restart pipewire pipewire-pulse wireplumber`.
