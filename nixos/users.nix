{ pkgs, ... }:

{
  users = {
    defaultUserShell = pkgs.zsh;
    # mutableUsers = false;

    users = {
      k = {
        isNormalUser = true;
        extraGroups = [ "wheel" "video" "networkmanager" ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy"
        ];
      };
    };
  };

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "Kris Williams";
        email = "115474+kriswill@users.noreply.github.com";
      };
      # signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy";
      # gpg.format = "ssh";
    };
  };
}
