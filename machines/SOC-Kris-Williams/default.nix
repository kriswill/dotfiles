# SOC-Kris-Williams - my work Apple M2 Pro, 32GB RAM
# hostname enforced by IT
#
{
  self,
  pkgs,
  inputs,
  ...
}:
{

  system = {
    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 5;
    # Set Git commit hash for darwin-version.
    configurationRevision = self.rev or self.dirtyRev or null;
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };

  environment = {
    # $ nix-env -qaP | grep wget
    systemPackages = with pkgs; [
      iproute2mac
      home-manager
    ];
    shellAliases = {
      drs = "${
        inputs.darwin.packages.${pkgs.stdenv.hostPlatform.system}.darwin-rebuild
      }/bin/darwin-rebuild switch --flake ~/src/dotfiles |& ${pkgs.nix-output-monitor}/bin/nom";
    };
  };
  security.pam.services.sudo_local.touchIdAuth = true;

  # nix repl -f '<nixpkgs>'
  # > nerd-fonts.<tab>
  fonts.packages = with pkgs.nerd-fonts; [
    victor-mono
    sauce-code-pro
    jetbrains-mono
  ];

  programs.zsh.enable = true;

  # Prevent nix-darwin from managing nix - conflicts with Determinate installer
  nix.enable = false;

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
    brews = [ ];
    masApps = {
      "Xcode" = 497799835;
    };
  };
}
