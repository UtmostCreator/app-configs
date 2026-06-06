{ ... }:
{
  # macOS system defaults expressed declaratively. Applied by
  # `darwin-rebuild switch --flake ./nix#macos`. Only declares preferences
  # that the user actively maintains by hand today — grow this from real
  # friction, not aspiration.
  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 48;
    };

    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      FXPreferredViewStyle = "Nlsv"; # column view list
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };

    screencapture = {
      location = "~/Pictures/Screenshots";
      type = "png";
    };
  };
}
