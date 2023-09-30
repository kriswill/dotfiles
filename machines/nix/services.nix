{ config, pkgs, ... }:

{
  systemd = {
    services = {
      # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;
      # disable Parallels tools printer sharing
      prlshprint.enable = false;

      # prlcc.enable = true;
    };
  };
}
