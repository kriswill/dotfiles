{ pkgs, ... }:

let
  signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy";
in
{
  users = {
    defaultUserShell = pkgs.zsh;

    users = {
      k = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
          "networkmanager"
          "libvirtd"
          "input"
        ];
        openssh.authorizedKeys.keys = [ signingkey ];
      };
    };
  };
}
