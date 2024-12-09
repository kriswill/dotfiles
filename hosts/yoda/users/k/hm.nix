{ wallpapers, icons, ... }:
{
  imports = [ ./hyprland ];
  # wayland.windowManager.hyprland.systemd.enable = false;
  programs.discord.enable = true;
  # todo Remove this turd
  stylix.enable = true;
  services.hyprpaper =
    let
      dp1 = builtins.fetchurl wallpapers.yoda-dagoba-1;
      dp2 = builtins.fetchurl wallpapers.yoda-dagoba-2;
    in
    {
      enable = true;
      settings = {
        ipc = "on";
        splash = false;
        preload = [ dp1 dp2 ];
        wallpaper = [
          "DP-1, ${dp1}"
          "DP-2, ${dp2}"
        ];
      };
    };
  programs.fastfetch.image = builtins.fetchurl icons.yoda;
}
