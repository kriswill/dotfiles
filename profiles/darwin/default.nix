{
  self,
  inputs,
  outputs,
  pkgs,
  lib,
  ...
}:
{
  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;
  #
  system.primaryUser = "k";

  environment = with pkgs; {
    # $ nix-env -qaP | grep wget
    systemPackages = [
      iproute2mac
      home-manager
    ];
    # ++ [
    #   inputs.fh.packages.${pkgs.stdenv.hostPlatform.system}.default
    # inputs.ghostty.packages.aarch64-darwin.default
    # ];
    shellAliases = {
      # drs = "sudo ${
      #   inputs.darwin.packages.${pkgs.stdenv.hostPlatform.system}.darwin-rebuild
      # }/bin/darwin-rebuild switch --flake ~/src/dotfiles |& ${lib.getExe pkgs.nix-output-monitor}";
      nds = "NH_NO_CHECKS=1 ${lib.getExe nh} darwin switch ~/src/dotfiles";
    };
    etc."pam.d/sudo_local".text = ''
      # Allow for touch ID to work for sudo, inside of tmux
      auth       optional       ${pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
      auth       sufficient     pam_tid.so
    '';
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  # nix repl -f '<nixpkgs>'
  # > nerd-fonts.<tab>
  fonts.packages = with pkgs.nerd-fonts; [
    victor-mono
    sauce-code-pro
    jetbrains-mono
  ];

  programs.fish.enable = true;
  programs.zsh.enable = true;
  programs.nh.enable = true;

  # Cannot let nix-darwin control nix when using determinate
  nix.enable = lib.mkForce false;
  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"
      ];
  };
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
      "karabiner-elements"
      {
        name = "launchcontrol";
        greedy = true;
      }
      "ghostty"
    ];
    brews = [ ];
    # SLOW!
    # masApps = {
    #   "Xcode" = 497799835;
    # };
  };
}
