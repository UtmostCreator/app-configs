{
  lib,
  config,
  inputs,
  ...
}:
let
  # Install groups: declared once here, defaulted from the committed profile
  # file nix/profiles/<profile>.toml of the effective myConfig.profile, then
  # overridden by the local selection (nix/selection/selection.toml, or the
  # directory a script passes with --override-input selection). An empty
  # selection file means no selection: every default stays as committed.
  # Each description names the packages the group gates. Core tools are never in
  # a group.
  groupDescriptions = {
    media = "Media tools: ffmpeg, yt-dlp, imagemagick, viu (nix/modules/home/cli.nix).";
    security = "Vulnerability scanners: trivy, osv-scanner (nix/modules/home/dev.nix).";
    go = "Go toolchain and tooling: the Go block in nix/modules/home/dev.nix.";
  };
  groupNames = builtins.attrNames groupDescriptions;
  profileNames = [
    "work"
    "personal"
  ];

  readToml = path: builtins.fromTOML (builtins.readFile path);

  raw = readToml (inputs.selection + "/selection.toml");
  rawGroups = raw.groups or { };
  unknownGroups = lib.filter (g: !(lib.elem g groupNames)) (builtins.attrNames rawGroups);

  # Validated selection. Every failure is a throw so that evaluating any
  # option that depends on the selection fails, and the message names the key.
  selection =
    if raw ? profile && !(lib.elem raw.profile profileNames) then
      throw "selection.toml: unknown profile '${toString raw.profile}'; known profiles: ${lib.concatStringsSep ", " profileNames}"
    else if unknownGroups != [ ] then
      throw "selection.toml: unknown group '${lib.head unknownGroups}'; known groups: ${lib.concatStringsSep ", " groupNames}"
    else if rawGroups != { } && !(raw ? profile) then
      throw "selection.toml: [groups] is set but 'profile' is missing; set profile to one of: ${lib.concatStringsSep ", " profileNames}"
    else
      raw;

  profileGroups = (readToml (../../profiles + "/${config.myConfig.profile}.toml")).groups;
  committedDefault =
    g:
    profileGroups.${g}
      or (throw "nix/profiles/${config.myConfig.profile}.toml: group '${g}' is not listed");
in
{
  # Host "profile" selector for opt-in app sets.
  #
  # Set `myConfig.profile = "personal";` in a host's home.nix (e.g.
  # nix/hosts/linux-desktop/home.nix) to pull in personal-only GUI apps
  # (see nix/modules/home/gui.nix: vesktop + telegram-desktop).
  #
  # Default is "work", which ships nothing personal. This keeps personal chat
  # apps off shared/work machines unless explicitly opted in. A local
  # selection that names a profile overrides the host's choice.
  options.myConfig.profile = lib.mkOption {
    type = lib.types.enum profileNames;
    default = "work";
    example = "personal";
    description = ''
      Machine profile. "personal" enables personal-only applications such as
      Vesktop (Discord + Vencord) and Telegram in the Linux GUI module.
      "work" (default) installs none of them.
    '';
  };

  options.myConfig.groups = lib.mapAttrs (
    g: description:
    lib.mkOption {
      type = lib.types.bool;
      default = selection.groups.${g} or (committedDefault g);
      defaultText = lib.literalMD "the local selection's value, else the profile file's value";
      inherit description;
    }
  ) groupDescriptions;

  config.myConfig.profile = lib.mkIf (selection ? profile) (lib.mkForce selection.profile);
}
