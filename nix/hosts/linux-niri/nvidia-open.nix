{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = false;
  };
  nixpkgs.config.allowUnfreePackages = [ "nvidia-x11" ];
}
