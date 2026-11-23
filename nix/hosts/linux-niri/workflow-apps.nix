# Packages for the laptop's daily-use acceptance tests. Build these before
# migration; enable the selected apps in Home Manager after baseline recovery.
# Declaring the clients here does not configure accounts or start services.
pkgs: with pkgs; [
  android-studio
  bruno
  czkawka
  doublecmd
  firefox
  flameshot
  localsend
  obs-studio
  obsidian
  pavucontrol
  qdirstat
  syncthing
  telegram-desktop
  vesktop
  wl-clipboard
]
