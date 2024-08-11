# https://wiki.hyprland.org/Configuring/Configuring-Hyprland/
# https://github.com/nix-community/home-manager/blob/master/modules/services/window-managers/hyprland.nix
{ config
, pkgs
, lib
, ...
}:
with pkgs.unstable;
let
  ln = config.lib.file.mkOutOfStoreSymlink;
  cursorPackage = pkgs.bibata-hyprcursor;
  cursorSize = toString config.home.pointerCursor.size;
  cursor = "Bibata-Modern-Classic-Hyprcursor";
  conf = "${config.home.homeDirectory}/src/dotfiles/home/programs/hyprland/config";
in
{

  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";

    # programs
    # See https://wiki.hyprland.org/Configuring/Keywords/
    "$terminal" = "${lib.getExe kitty}";
    "$file-manager" = "nautilus";
    "$menu" = "${lib.getExe rofi-wayland} -show drun";
    "$screenshot" = "grim -t png -l0 -g \"$(slurp)\" - | swappy -f -";
    "$1password-quick" = "${lib.getExe _1password} --quick-access";
    "$1password-toggle" = "${lib.getExe _1password} --toggle";

    env = [
      "HYPRCURSOR_THEME,${cursor}"
      "HYPRCURSOR_SIZE,${cursorSize}"
      "XCURSOR_SIZE,${cursorSize}"
      "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
      "QT_QPA_PLATFORM,wayland"
      "QT_QPA_PLATFORMTHEME,gnome"
      "QT_AUTO_SCREEN_SCALE_FACTOR,1"
      "QT_STYLE_OVERRIDE,Adwaita-Dark"
    ];

    exec-once = [
      "hyprctl setcursor ${cursor} ${cursorSize}"
      "swww-daemon -q && swww img -o DP-1 ~/Pictures/yoda-dagobah.webp && swww img -o DP-2 ~/Pictures/yoda-dagoba-render.jpg"
      "1password --silent"
      "dunst"
      "gBar bar DP-2"
    ];

    source = [
      "./monitors.conf"
      "./look-and-feel.conf"
      "./input.conf"
      "./binds.conf"
      "./windowrulev2.conf"
    ];
  };

  xdg = {
    # live symlink for config files, makes live reload for config faster
    # running home manager switch (hms) can take up to 40 seconds
    configFile = {
      "hypr/binds.conf".source = ln "${conf}/binds.conf";
      "hypr/input.conf".source = ln "${conf}/input.conf";
      "hypr/monitors.conf".source = ln "${conf}/monitors.conf";
      "hypr/look-and-feel.conf".source = ln "${conf}/look-and-feel.conf";
      "hypr/windowrulev2.conf".source = ln "${conf}/windowrulev2.conf";
    };
    dataFile."icons/${cursor}".source = "${cursorPackage}/share/icons/${cursor}";
  };
}
