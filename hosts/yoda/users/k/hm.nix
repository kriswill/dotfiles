{ pkgs, icons, wallpapers, ... }:
{
  imports = [ ./hyprland ];
  # wayland.windowManager.hyprland.systemd.enable = false;
  # todo Remove this turd
  stylix.enable = true;
  home.packages = with pkgs; [
    wowup-cf
    tldr
    # xwaylandvideobridge
  ];
  programs = {
    discord.enable = true;
    fastfetch.image = builtins.fetchurl icons.yoda;
    # lutris.enable = true;
    bottles.enable = true;
    obs-studio.enable = true;
  };

  services.swww.monitors = {
    DP-1.image = builtins.fetchurl wallpapers.yoda-dagoba-1;
    DP-2.image = builtins.fetchurl wallpapers.yoda-dagoba-2;
  };

  services.kanshi = {
    enable = true;
    settings = [
      {
        profile = {
          name = "yoda";
          outputs = [
            {
              criteria = "Ancor Communications Inc ROG PG348Q #ASNtlPMnEjHd";
              position = "-1440,-1240";
              mode = "3440x1440@59.97Hz";
              transform = "270";
            }
            {
              criteria = "ASUSTek COMPUTER INC PG34WCDM";
              position = "0,0";
              mode = "3440x1440@239.98399Hz";
            }
          ];
        };
      }
    ];
  };
}
