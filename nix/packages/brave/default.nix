{ stdenv, callPackage }:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
  archive = release.archives.${stdenv.hostPlatform.system};
in
callPackage ./make-brave.nix { } (
  archive
  // {
    pname = "brave";
    inherit (release) version;
  }
)
