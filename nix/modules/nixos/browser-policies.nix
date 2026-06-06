# nix/modules/nixos/browser-policies.nix
#
# Declarative managed policies for Brave (and Chromium, if used). Brave reads
# enterprise-style policy JSON from /etc/brave/policies/managed/*.json at startup
# and ENFORCES it (settings show as "managed by your organization"). This turns
# "click ~20 Brave toggles on every new machine" into one reproducible,
# git-tracked, opt-in module — matching the rest of this repo's philosophy.
#
# Brave is this repo's default browser + PDF handler (nix/modules/home/gui.nix +
# default-apps.nix), so this hardens the exact browser we ship.
#
# SYSTEM layer (writes /etc/...), so it only applies when imported by /etc/nixos
# and activated with nixos-rebuild (wire via sys-setup, like timezone/
# substituters). Inert until `myConfig.browserPolicies.enable = true;`.
#
# Adapted from nix-config-pavlo modules/nixos/browser-policies.nix. Note:
# BrowserSignin is intentionally NOT set here — sign-in drives Brave Sync, which
# the owner wants left to the user.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig.browserPolicies;

  # Cross-Chromium privacy + search hardening.
  sharedPolicy = {
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "Brave Search";
    DefaultSearchProviderSearchURL = "https://search.brave.com/search?q={searchTerms}";
    DefaultSearchProviderSuggestURL = "https://search.brave.com/api/suggest?q={searchTerms}";

    RestoreOnStartup = 1; # reopen last session's tabs

    PromptForDownloadLocation = false;

    PasswordManagerEnabled = false; # use a dedicated password manager
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
    PaymentMethodQueryEnabled = false;

    MetricsReportingEnabled = false;
    UrlKeyedAnonymizedDataCollectionEnabled = false;
    SpellCheckServiceEnabled = false;

    DefaultNotificationsSetting = 2; # 2 = block by default
    DefaultGeolocationSetting = 2; # 2 = block by default

    # BrowserSignin intentionally omitted (drives Brave Sync; left to the user).
  };

  # Strip Brave's crypto/AI/extras.
  bravePolicy = {
    BraveRewardsDisabled = true;
    BraveWalletDisabled = true;
    BraveVPNDisabled = true;
    BraveAIChatEnabled = false;
    BraveTalkDisabled = true;
    BraveNewsDisabled = true;
  };

  sharedPolicyFile = pkgs.writeText "browser-policy-shared.json" (builtins.toJSON sharedPolicy);
  bravePolicyFile = pkgs.writeText "browser-policy-brave.json" (builtins.toJSON bravePolicy);
in
{
  options.myConfig.browserPolicies.enable = lib.mkEnableOption "managed privacy/search policies for Brave (and Chromium)";

  config = lib.mkIf cfg.enable {
    environment.etc = {
      "brave/policies/managed/00-shared.json".source = sharedPolicyFile;
      "brave/policies/managed/10-brave.json".source = bravePolicyFile;
      "chromium/policies/managed/00-shared.json".source = sharedPolicyFile;
    };
  };
}
