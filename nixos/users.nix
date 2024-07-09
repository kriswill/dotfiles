# TODO: maybe some of this should be in home-manager?
{ pkgs, lib, ... }:

let
  signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy";
  inherit (lib) getExe;
in
{
  users = {
    defaultUserShell = pkgs.zsh;
    # mutableUsers = false;

    users = {
      k = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
          "networkmanager"
          "libvirtd"
        ];
        openssh.authorizedKeys.keys = [ signingkey ];
        packages = [ pkgs.home-manager ];
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
          inherit signingkey;
        };
        init.defaultBranch = "main";
      }
      { credential."https://github.com".helper = "!${getExe pkgs.gh} auth git-credential"; }
      { credential."https://gist.github.com".helper = "!${getExe pkgs.gh} auth git-credential"; }
      { gpg.format = "ssh"; }
      { gpg."ssh".program = "${pkgs._1password-gui}/bin/op-ssh-sign"; }
      { commit.gpgsign = true; }
    ];
  };
}
