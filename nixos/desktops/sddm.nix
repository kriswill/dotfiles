{
  inputs,
  pkgs,
  packages,
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
      # custom themes need this package to work with qt5 sddm greeter
      package = pkgs.kdePackages.sddm;
      # theme = "eucalyptus-drop";
      theme = "astronaut";
    };
  };

  environment.systemPackages = with pkgs.unstable; [
    sddm-astronaut
  ];
  #   [ packages.sddm-eucalyptus-drop ]
  #   ++ [ pkgs.qt6.qt5compat ]
  #   ++ [
  #     pkgs.libsForQt5.qt5.qtgraphicaleffects
  #     pkgs.libsForQt5.qt5.qtsvg
  #   ];
}
