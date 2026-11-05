{ inputs }:
final: prev: {
  # TEMPORARY pin (2026-10-26): semgrep-core 1.180.0 in nixpkgs-unstable 674a202
  # aborts in fixupPhase (patchelf 0.19.2 assertion `splitIndex == -1`), and
  # Hydra has no cached build. Take semgrep from the `nixpkgs-last-good` input.
  # Remove this attr once `nix build --inputs-from ./nix nixpkgs#semgrep`
  # succeeds again.
  semgrep = inputs.nixpkgs-last-good.legacyPackages.${prev.stdenv.hostPlatform.system}.semgrep;

  # TEMPORARY (2026-11-05): nixpkgs-unstable ships opencode 2.2.5 with a stale
  # Linux node_modules fixed-output hash, so the build fails with a hash
  # mismatch. nixpkgs master fixed it in c399e1b7fb90 ("opencode: fix hash",
  # 2026-11-04) using the hash below. The version guard makes this a no-op for
  # any other opencode version; remove it once nixpkgs-unstable has that commit.
  opencode =
    if prev.opencode.version == "2.2.5" && prev.stdenv.hostPlatform.isLinux then
      prev.opencode.overrideAttrs (old: {
        node_modules = old.node_modules.overrideAttrs {
          outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
        };
      })
    else
      prev.opencode;
}
