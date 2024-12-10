{ pkgs
, config
, lib
, wallpapers
, ...
}:

let
  xcfg = config.services.xserver;

  weston-ini = pkgs.writeText "weston.ini" ''
    [core]
    xwayland=false
    shell=fullscreen-shell.so

    [keyboard]
    keymap_model=${builtins.toString xcfg.xkb.model}
    keymap_layout=${builtins.toString xcfg.xkb.layout}
    keymap_options=${builtins.toString xcfg.xkb.options}
    keymapvariant=

    [libinput]
    enable-tap=true
    left-handed=false

    [output]
    name=DP-2
    mode=3440x1440@240

    [output]
    name=DP-1
    mode=off
  '';

  weston-command = lib.concatStringsSep " " [
    "${lib.getExe pkgs.weston}"
    "--shell=kiosk"
    "-c ${weston-ini}"
  ];
in
{
  services.displayManager = {
    sddm = {
      wayland = {
        compositor = lib.mkForce "weston";
        compositorCommand = weston-command;
      };
      themeConfig = {
        Background = builtins.fetchurl wallpapers.yoda-dagoba-2;
        AccentColor = "#6E815B";
        FormPosition = "left";
        FullBlur = "false";
        PartialBlur = "false";
        ForceHideCompletePassword = "true";
      };
    };
  };
}
