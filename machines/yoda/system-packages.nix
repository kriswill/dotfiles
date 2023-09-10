{ pkgs, environment, username, ... }:

{
  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    bat
    eza
    fzf
    git
    hstr
    htop
    neofetch
    nix-info
    ripgrep
    sysz
    wget
  ];

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ username ];
  };

  # Set zsh to be the default shell for the system
  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
    shellAliases = {
      ls = "eza";
      ld = "ls -D";
      ll = "ls -lhF";
      la = "ls -lahF";
      l  = "la";
      cat = "bat";
    };
    autosuggestions.enable = true;
  };
  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [ zsh ];
  # Needed to run Electron apps under Wayland
  # see: https://github.com/NixOS/nixpkgs/pull/147557
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
