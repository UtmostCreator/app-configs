{ inputs }:
final: prev: {
  # TEMPORARY pin (2026-10-26): semgrep-core 1.180.0 in nixpkgs-unstable 674a202
  # aborts in fixupPhase (patchelf 0.19.2 assertion `splitIndex == -1`), and
  # Hydra has no cached build. Take semgrep from the `nixpkgs-last-good` input.
  # Remove this attr once `nix build --inputs-from ./nix nixpkgs#semgrep`
  # succeeds again.
  semgrep = inputs.nixpkgs-last-good.legacyPackages.${prev.stdenv.hostPlatform.system}.semgrep;
}
