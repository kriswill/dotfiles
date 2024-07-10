{
  inputs,
  pkgs,
  packages,
  config,
  lib,
  ...
}:
{
  options.gnome = {
    enable = lib.mkEnableOption "Gnome";
  };

  options.hyprland = {
    enable = lib.mkEnableOption "Hyprland";
  };

  imports = [
    ./gnome
    ./hyprland
  ];

  config = {
    services.displayManager = {
      defaultSession = "gnome";
      sddm = {
        enable = true;
        wayland.enable = true;
        # theme = "where_is_my_sddm_theme";
        theme = "eucalyptus-drop";
        package = lib.mkDefault pkgs.kdePackages.sddm;
      };
    };

    environment.systemPackages = with packages; [
      sddm-eucalyptus-drop
    ] ++ (with pkgs.libsForQt5.qt5; [
      qtgraphicaleffects
      qtsvg
    ]) ++ (with pkgs;[
      qt6.qt5compat
      #
      # (where-is-my-sddm-theme.override {
      #   variants = [ "qt6" ];
      #   themeConfig.General = {
      #     background = pkgs.wallpapers.yoda-dhagoba;
      #     backgroundMode = "fill";
      #     passwordInputRadius = 10;
      #     blurRadius = 0;
      #     usersFontSize = 16;
      #     basicTextColor = "#ffffff";
      #     passwordInputBackground = "#60ffffff";
      #     passwordInputWidth = 0.2;
      #     passwordFontSize = 48;
      #     sessionsFontSize = 36;
      #     showUsersByDefault = false;
      #     showSessionsByDefault = true;
      #   };
      # })
    ]);

  };
}
