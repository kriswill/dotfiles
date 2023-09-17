{ pkgs, username, ... }:

{
  users = {
    defaultUserShell = pkgs.zsh;

    users.${username} = {
      isNormalUser = true;
      uid = 1000;
      description = "${username}";
      group = "${username}";
      extraGroups = [ "networkmanager" "wheel" "libvirtd" ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy"
      ];
    };
    groups.${username}.gid = 1000;
  };
}
