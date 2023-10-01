{ pkgs, ... }:

{
  # file listing
  ls = "${pkgs.eza}/bin/eza --icons";
  ld = "l -D";
  ll = "l -lhF";
  la = "l -a";
  t = "l -T -L3";
  l = "ls -lhF --git -I '.git|.DS_'";
  cat = "${pkgs.bat}/bin/bat";

  # system related
  sudo = "sudo "; # allow for using aliases with sudo
  nrs = "sudo -s nixos-rebuild switch --upgrade";

  # git related
  g = "${pkgs.git}/bin/git";
  gco = "g checkout";
  gba = "g branch -a";
}
