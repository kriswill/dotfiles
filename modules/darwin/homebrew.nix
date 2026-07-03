{
  flake.modules.darwin.homebrew =
    { lib, ... }:
    {
      homebrew = {
        enable = lib.mkDefault true;
        global.brewfile = lib.mkDefault true;
        onActivation = {
          upgrade = lib.mkDefault true;
          cleanup = lib.mkDefault "zap";
          autoUpdate = lib.mkDefault true;
          # Homebrew >= 5.1 refuses `brew bundle --cleanup` non-interactively
          # without a force flag; authorize the (zap) cleanup so activation
          # doesn't prompt/abort. See `brew bundle install --help`.
          extraFlags = [ "--force-cleanup" ];
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
