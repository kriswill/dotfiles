{ pkgs, ... }:

{
  imports = [
    ./xdg
    ./programs
    ./scripts
  ];

  home = {
    packages = with pkgs; [
      (nerdfonts.override {
        fonts = [
          "SourceCodePro" # `SauceCodePro Nerd Font`
          "JetBrainsMono"
        ];
      })
      bustle # freedesktop database viewer
      has # command existence checker
      ncdu # disk space explorer
      nix-output-monitor # nom: output logger for nix build
      ripgrep # fast replacement for grep
      tldr # short manual for common shell commands
      dconf2nix # convert dconf settings to nix
      # slack for gamers
      (discord.override {
        withOpenASAR = true;
        withVencord = true;
      })
      vesktop # alt discord client
      github-desktop # github for dummies
      yq-go # yaml parser
      gcolor3 # color picker
      element-desktop-wayland # matrix client
      zoom-us # video conferencing
      lutris # game manager
      devenv # development environments
      unzip
      zip
      vlc # video player
      # hydrapaper # wallpaper manager for gnome
      efitools # manipulate UEFI secure boot variables
      dolphin-emu-beta # old game ROM emulator
      sloccount # count lines of code
    ];

    sessionVariables = {
      # Needed to run Electron apps under Wayland
      # see: https://github.com/NixOS/nixpkgs/pull/147557
      NIXOS_OZONE_WL = "1";
      HOME_SESSION_VARIABLES = "1";
    };

    stateVersion = "24.05";
  };

  # Needed for Nerd Fonts to be found
  fonts.fontconfig.enable = true;
}
