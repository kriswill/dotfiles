{ config, pkgs, lib, username, ... }:

let
  homeDirectory = lib.mkForce (
    if pkgs.stdenvNoCC.isDarwin 
    then "/Users/${username}" 
    else "/home/${username}"
  );
in
{
  imports = [
    ./programs
  ];

  fonts.fontconfig.enable = true;

  home = {
    inherit username homeDirectory;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
    stateVersion = "24.05"; # Please read the comment before changing.


  # The home.packages option allows you to install Nix packages into your
  # environment.
  packages = with pkgs; [
    fastfetch
    (nerdfonts.override {
      fonts = [
        "JetBrainsMono"
        "DejaVuSansMono"
        "SourceCodePro"
      ];
    })
    fd # file finding utility
    jq
    bat
    tree
    comma
    nix-index
    nixpkgs-fmt
    nixd # LSP for Nix language
    tldr
    nix-output-monitor
    ripgrep
    localsend
    figlet
    age
    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    (writeShellScriptBin "my-hello" ''
      echo "Hello, ${config.home.username}!"
    '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/k/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  sessionVariables = {
    EDITOR = "${lib.getExe pkgs.neovim}";
  };
  };
}
