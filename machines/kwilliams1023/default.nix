#
# kwilliams1023 - my work Apple M2 Pro, 32GB RAM
# hostname enforced by IT
#
{ self, pkgs, ... }: {

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  environment = {
    # $ nix-env -qaP | grep wget
    systemPackages = with pkgs; [
      iproute2mac
      home-manager
    ];
    shellAliases = {
      drs = "darwin-rebuild switch --flake ~/src/dotfiles";
    };
  };
  security.pam.enableSudoTouchIdAuth = true;

  # nix repl -f '<nixpkgs>'
  # > nerd-fonts.<tab>
  fonts.packages = with pkgs.nerd-fonts; [
    victor-mono
    sauce-code-pro
    jetbrains-mono
  ];

  programs.zsh.enable = true;

  nix = {
    enable = false;
    # linux-builder = {
    #   enable = true;
    #   ephemeral = true;
    #   systems = [ "aarch64-linux" ];
    #   config.nixpkgs.hostPlatform = "aarch64-linux";
    # };
    #
    # # This line is a prerequisite
    # settings.trusted-users = [ "@admin" ];
  };

  home-manager.backupFileExtension = "bak";

  homebrew = {
    enable = true;
    global.brewfile = true;
    onActivation = {
      upgrade = true;
      cleanup = "zap";
      autoUpdate = true;
    };
    casks = [
      "rwts-pdfwriter"
      "zerotier-one"
      "1password-cli"
      "ghostty"
      # {
      #   name = "launchcontrol";
      #   greedy = true;
      # }
    ];
    brews = [];
    masApps = {
      "Xcode" = 497799835;
    };
  };
}
