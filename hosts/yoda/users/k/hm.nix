{ icons, ... }:
{
  imports = [ ./hyprland ];
  # wayland.windowManager.hyprland.systemd.enable = false;
  programs.discord.enable = true;
  # todo Remove this turd
  stylix.enable = true;
  programs.fastfetch.image = builtins.fetchurl icons.yoda;
}
