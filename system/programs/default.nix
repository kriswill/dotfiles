{
  imports = [
    ./fonts.nix
    ./home-manager.nix
    # ./qt.nix
    # ./school.nix
    ./xdg.nix
  ];

  programs = {
    # make HM-managed GTK stuff work
    dconf.enable = true;

    kdeconnect.enable = true;

    seahorse.enable = true;

    # pretty much always use this - needed for git signing
    _1password.enable = true;
    _1password-gui.enable = true;
    # allow my user to sign git commits with 1password
    _1password-gui.polkitPolicyOwners = [ "k" ];
  };
}
