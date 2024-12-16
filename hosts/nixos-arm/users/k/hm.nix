{ wallpapers, icons, lib, pkgs, ... }:
{
  imports = [ ./hyprland ];
  # wayland.windowManager.hyprland.systemd.enable = false;
  programs.discord.enable = true;
  # todo Remove this turd
  stylix = {
    enable = true;
    image = builtins.fetchurl wallpapers.blue-marble-2;
  };

  programs.fastfetch.image = builtins.fetchurl icons.yoda;
  xsession.windowManager.i3.config = {
    keybindings = {
      "Mod4+space" = "exec /nix/store/3n37yan2fz8np2as6xszjhyqwqajl4zs-rofi-1.7.5/bin/rofi -show";
      "Mod4+Mod1+space" = "exec ${lib.getExe pkgs.rofi} -show";
    };
  };
}
