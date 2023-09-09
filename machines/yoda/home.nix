{ pkgs, inputs, ...}: 

{
  imports = with inputs.self.homeManagerModules; [
    home
    linux
    gnome
  ];

  # # Force Wayland on apps like VSCode and Firefox
  home.sessionVariables."NIXOS_OZONE_WL" = 1;

  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    discord
    # duf
    # element-desktop
    # goverlay
    # lutris
    # newsflash
    # nil
    # prismlauncher
    # qbittorrent
    # satisfactory-mod-manager
    # spotify
    # vkBasalt
    vlc
  ];

  # Needed for Nerd Fonts to be found
  fonts.fontconfig.enable = true;

  services.syncthing.enable = true;

  programs.obs-studio.enable = true;
  programs.obs-studio.plugins = with pkgs.obs-studio-plugins; [
    obs-gstreamer
  ];

  # programs.mangohud.enable = true;
  programs.nix-index.enable = true;

  home.stateVersion = "23.05";
}