{
  config,
  lib,
  pkgs,
  ...
}:
{
  # CLI tools — used on every host (macOS / linux-desktop / linux-cli / wsl).
  # Per repo-docs/migration-package-ownership.md Phase 3 matrix.
  #
  # IMPORTANT: every nixpkgs attribute name below was decided based on the
  # matrix notes. Confirm with `nix search nixpkgs <name>` if you hit a
  # missing package on `nix flake check`.
  home.packages =
    (with pkgs; [
      atuin
      bat
      btop
      eza
      fd
      fish
      # interactive shell (native autosuggestions + syntax
      # highlighting; config in ~/.config/fish/config.fish).
      # Added as a plain package, not programs.fish.enable,
      # to satisfy the validate-config.sh invariant.
      # Fish plugin: autopair (auto-close brackets/quotes). Auto-loads via
      # vendor_conf.d from the profile share dir; no config needed.
      # NOTE: fzf-fish was intentionally NOT added — it would double-bind
      # Ctrl-T/Alt-C, which are already owned by `fzf --fish` + Atuin in
      # config.fish. Keeping one fzf integration avoids the conflict.
      fishPlugins.autopair
      fzf
      jq
      lsof # list open files/sockets (debugging, port owners)
      yq-go # yq formula -> yq-go in nixpkgs
      ripgrep
      ripgrep-all # binary: rga
      starship
      tlrc # tldr client (binary: tldr); matrix owner for tldr
      tmux
      tree # directory tree view (eza --tree also works)
      yazi
      zoxide
    ])
    # ── Media (borrowed from nix-config review) ── group `media`
    # (myConfig.groups.media, nix/modules/home/profile.nix). Spliced in place:
    # list order feeds the Home Manager generation derivation.
    ++ lib.optionals config.myConfig.groups.media (
      with pkgs;
      [
        ffmpeg # multimedia framework (transcode/convert)
        yt-dlp # audio/video downloader
        imagemagick # image manipulation (convert/mogrify)
        viu # terminal image viewer
      ]
    )
    ++ (with pkgs; [
      # ── Files / disk ──
      entr # run a command when files change
      # `du` replacement (du-dust; chosen over ncdu — larger, more active
      # community; binary: dust)
      dust
      # Interactive cheatsheet launcher (Ctrl-G); complements tldr/tlrc
      # (quick examples) — different tool, no overlap.
      navi
      # ── Productivity / text (from macOS tools audit) ──
      sd # sed-style find/replace (binary: sd)
      parallel # GNU parallel for shell job fan-out
      glow # render Markdown in the terminal
    ]);
}
