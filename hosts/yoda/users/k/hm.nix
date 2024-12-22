{ icons, wallpapers, ... }:
{
  imports = [ ./hyprland ];
  # wayland.windowManager.hyprland.systemd.enable = false;
  programs.discord.enable = true;
  # todo Remove this turd
  stylix.enable = true;
  programs.fastfetch.image = builtins.fetchurl icons.yoda;
  services.swww.monitors = {
    DP-1.image = builtins.fetchurl wallpapers.yoda-dagoba-1;
    DP-2.image = builtins.fetchurl wallpapers.yoda-dagoba-2;
  };
}
