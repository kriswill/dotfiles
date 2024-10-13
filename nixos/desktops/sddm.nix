{
  pkgs,
  config,
  lib,
  ...
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

  sddm-astronaut = pkgs.sddm-astronaut.override {
    themeConfig = {
      Background = pkgs.wallpapers.yoda-dagoba-2;
      AccentColor = "#6E815B";
      FormPosition = "left";
      ForceHideCompletePassword = true;
    };
  };
in
{
  services.displayManager = {
    sddm = {
      enable = true;
      wayland = {
        enable = true;
        compositor = lib.mkForce "weston";
        compositorCommand = weston-command;
      };
      package = pkgs.kdePackages.sddm;
      extraPackages = [ sddm-astronaut ];
      theme = "sddm-astronaut-theme";
    };
  };
  environment.systemPackages = [ sddm-astronaut ];
}
