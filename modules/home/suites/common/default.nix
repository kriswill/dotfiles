{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.internal) mkBoolOpt enabled;
  inherit (pkgs.stdenv) isLinux;

  cfg = config.k.suites.common;
in
{
  options.k.suites.common = {
    enable =
      mkBoolOpt false
        "Whether or not to enable common configuration.";
  };

  config = mkIf cfg.enable {
    xdg.configFile.wgetrc.text = "";

    k = {
    #   apps = {
    #     firefox = enabled;
    #   };

      cli-apps = {
        # bottom = enabled;
        # btop = enabled;
        fastfetch = enabled;
        # ranger = enabled;
        # tmux = enabled;
        # yazi = enabled;
      };

      desktop = {
        addons = {
          # alacritty = enabled;
          # gtk.enable = isLinux;
          # qt.enable = isLinux;
          # wezterm = enabled;
        };

        # theme = enabled;
      };

      #services = {
        # TODO: reenable after fixed
        # udiskie.enable = pkgs.stdenv.isLinux;
      #};

      #security = {
        # gpg = enabled;
      #};

      system = {
        shell = {
          #bash = enabled;
          #fish = enabled;
          zsh = enabled;
        };
      };

      # tools = {
      #   bat = enabled;
      #   direnv = enabled;
      #   fzf = enabled;
      #   git = enabled;
      #   lsd = enabled;
      #   oh-my-posh = enabled;
      #   topgrade = enabled;
      # };
    };

    programs.readline = {
      enable = true;

      extraConfig = ''
        set completion-ignore-case on
      '';
    };
  };
}