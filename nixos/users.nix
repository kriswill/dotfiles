{ pkgs, ... }:

let
  ssh-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy";
in
{
  users = {
    defaultUserShell = pkgs.zsh;
    # mutableUsers = false;

    users = {
      k = {
        isNormalUser = true;
        extraGroups = [ "wheel" "video" "networkmanager" "libvirtd" ];
        openssh.authorizedKeys.keys = [ ssh-key ];
      };
    };
  };

  # allow my user to sign git commits with 1password
  programs._1password-gui.polkitPolicyOwners = [ "k" ];

  programs.git = {
    enable = true;
    config = [
      {
        user = {
          name = "Kris Williams";
          email = "115474+kriswill@users.noreply.github.com";
          signingkey = ssh-key;
        };
        init.defaultBranch = "main";
      }
      { credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential"; }
      { credential."https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential"; }
      { gpg.format = "ssh"; }
      { gpg."ssh".program = "${pkgs._1password-gui}/bin/op-ssh-sign"; }
      { commit.gpgsign = true; }
    ];
  };
}
