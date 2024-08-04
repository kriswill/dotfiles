{ pkgs, ... }: {
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
    };
    gamescope.enable = true;
  };
  environment = {
    systemPackages = with pkgs.unstable; [ mangohud protonup ];
    sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "~/.steam/root/compatibilitytools.d";
    };
  };
}
