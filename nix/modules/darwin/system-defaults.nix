{ lib, ... }:
{
  time.timeZone = lib.mkDefault "Europe/London";

  # macOS system defaults expressed declaratively. Applied by
  # `darwin-rebuild switch --flake ./nix#macos`. Only declares preferences
  # that the user actively maintains by hand today — grow this from real
  # friction, not aspiration.
  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 48;
      wvous-tl-corner = 2;
    };

    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      FXPreferredViewStyle = "Nlsv"; # list view ("clmv" = column)
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    NSGlobalDomain = {
      AppleICUForce24HourTime = true;
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 30;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      "com.apple.swipescrolldirection" = false;
      "com.apple.keyboard.fnState" = true;
    };

    menuExtraClock.Show24Hour = true;

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
