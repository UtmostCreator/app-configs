{ stdenvNoCC, fetchurl }:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
  archive = release.archives.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "codebase-memory-mcp-ui";
  inherit (release) version;
  src = fetchurl {
    inherit (archive) url;
    sha256 = archive.hash;
  };
  sourceRoot = ".";
  dontStrip = true; # Preserve embedded browser assets.
  installPhase = ''
    runHook preInstall
    install -Dm755 codebase-memory-mcp "$out/bin/codebase-memory-mcp"
    runHook postInstall
  '';
}
