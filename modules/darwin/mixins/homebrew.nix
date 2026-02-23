{ lib, config, ... }:
{
  options.kriswill.homebrew.enable = lib.mkEnableOption "Kris' Homebrew stuff";
  config = lib.mkIf config.kriswill.homebrew.enable {
    homebrew = {
      enable = true;
      global.brewfile = true;
      onActivation = {
        upgrade = true;
        cleanup = "zap";
        autoUpdate = true;
      };
      taps = [
        "steipete/tap"
        "marcus/tap"
      ];
      casks = [
        "rwts-pdfwriter"
        "zerotier-one"
        "1password-cli"
        "karabiner-elements"
        {
          name = "chromium";
          args = {
            no_quarantine = true;
          };
        }
        {
          name = "launchcontrol";
          greedy = true;
        }
      ];
      brews = [
        "marcus/tap/td"
        "marcus/tap/sidecar"
      ];
      # SLOW!
      # masApps = {
      #   "Xcode" = 497799835;
      # };
    };
  };
}
