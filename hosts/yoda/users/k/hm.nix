{ icons, wallpapers, ... }:
{
  imports = [ ./hyprland ];
  # wayland.windowManager.hyprland.systemd.enable = false;
  # todo Remove this turd
  stylix.enable = true;
  programs = {
    discord.enable = true;
    fastfetch.image = builtins.fetchurl icons.yoda;
    # lutris.enable = true;
    bottles.enable = true;
  };
  services.swww.monitors = {
    DP-1.image = builtins.fetchurl wallpapers.yoda-dagoba-1;
    DP-2.image = builtins.fetchurl wallpapers.yoda-dagoba-2;
  };
}
