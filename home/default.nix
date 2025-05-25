{
  config,
  pkgs,
  lib,
  username,
  ...
}:

let
  homeDirectory = lib.mkForce (
    if pkgs.stdenvNoCC.isDarwin then "/Users/${username}" else "/home/${username}"
  );
in
{
  imports = [ ./programs ];

  home = {
    inherit username homeDirectory;
    enableNixpkgsReleaseCheck = false;
    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    stateVersion = "24.11"; # Please read the comment before changing.

    # The home.packages option allows you to install Nix packages into your
    # environment.
    packages = with pkgs; [
      age # encryption tool
      claude-code # anthropic-ai
      comma # https://github.com/nix-community/comma
      fd # file finding
      figlet # text to big fancy letters in ASCII
      go # an awesome language
      jq # json querying
      keycastr # keystroke visualizer
      localsend # share files with other devices on the local network
      ncdu # analyze disk usage
      # nh # https://github.com/viperML/nh
      nix-index # local database of nixpkgs
      nix-output-monitor # better visual output for nix builds
      nix-tree # analyze disk usage by nix packages
      ripgrep # fast grep replacement
      tldr # simplified man pages
      tree # print directory trees
      yamlfmt # format yaml
      # You can also create simple shell scripts directly inside your
      # configuration. For example, this adds a command 'my-hello' to your
      # environment:
      (writeShellScriptBin "my-hello" ''
        echo "Hello, ${config.home.username}!"
      '')
    ];

    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    file = {
      # Building this configuration will create a copy of 'dotfiles/screenrc' in
      # the Nix store. Activating the configuration will then make '~/.screenrc' a
      # symlink to the Nix store copy.
      # ".screenrc".source = dotfiles/screenrc;

      # You can also set the file content immediately.
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
